package msr.plasma;

import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileWriter;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LauncherActivity extends Activity {

    private WebView mWebView;
    private ExecutorService mIconPool;
    private final Handler mMainHandler = new Handler(Looper.getMainLooper());

    @Override
    @SuppressWarnings("deprecation")
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);

        // FLAG_LAYOUT_NO_LIMITS extends the window beyond nav/status bar boundaries.
        // Required on Samsung One UI 7 HOME activities where IMMERSIVE_STICKY alone
        // leaves a black gap at the bottom equal to the nav bar height.
        getWindow().addFlags(
            WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS |
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS);
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);
        getWindow().getDecorView().setBackgroundColor(Color.BLACK);

        // Re-hide bars unconditionally on any visibility change — Samsung's shell
        // re-shows them on every activity transition, focus change, and rotation.
        getWindow().getDecorView().setOnSystemUiVisibilityChangeListener(
            new View.OnSystemUiVisibilityChangeListener() {
                @Override
                public void onSystemUiVisibilityChange(int visibility) {
                    applyImmersive();
                }
            }
        );

        mIconPool = Executors.newFixedThreadPool(3);

        mWebView = new WebView(this);
        mWebView.setBackgroundColor(Color.BLACK);
        mWebView.setFitsSystemWindows(false);
        mWebView.setLayoutParams(new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT));
        // Force WebView to real display dimensions — Samsung WM pre-subtracts the nav bar
        // from window bounds (1080x2546 instead of 1080x2640) before immersive applies.
        // getRealSize() returns the physical panel size and ignores WM allocation.
        getWindow().getDecorView().post(new Runnable() {
            @SuppressWarnings("deprecation")
            public void run() {
                android.view.Display display = getWindowManager().getDefaultDisplay();
                android.graphics.Point size = new android.graphics.Point();
                display.getRealSize(size);
                mWebView.getLayoutParams().height = size.y;
                mWebView.getLayoutParams().width = size.x;
                mWebView.requestLayout();
            }
        });
        setContentView(mWebView);

        WebSettings ws = mWebView.getSettings();
        ws.setJavaScriptEnabled(true);
        ws.setDomStorageEnabled(true);

        mWebView.setWebViewClient(new WebViewClient());
        mWebView.setWebChromeClient(new WebChromeClient());
        mWebView.addJavascriptInterface(new PlasmaJS(), "Android");
        mWebView.loadUrl("file:///android_asset/plasma/index.html");

        applyImmersive();

        // Root layer — persistent su shell drives all nav-hide commands in one session.
        // Only runs once per install; subsequent launches skip via SharedPreferences guard.
        // Log file is opened FIRST so every failure path is captured.
        final SharedPreferences prefs = getSharedPreferences("plasma", MODE_PRIVATE);
        if (!prefs.getBoolean("nav_root_applied", false)) {
            new Thread(new Runnable() {
                public void run() {
                    PrintWriter log = null;
                    try {
                        new File("/data/local/tmp").mkdirs();
                        log = new PrintWriter(
                            new FileWriter("/data/local/tmp/plasma-nav.log", true));
                        log.println("[" + System.currentTimeMillis() + "] plasma-mobile nav-hide start");
                        log.flush();

                        String suPath = findSu();
                        log.println("su=" + (suPath != null ? suPath : "NOT FOUND"));
                        log.flush();

                        if (suPath == null) {
                            log.println("aborting: su not found in any candidate path");
                            return;
                        }

                        // One persistent su shell — avoids repeated su grant prompts and
                        // eliminates the overhead of separate exec() calls per command.
                        Process suProc = Runtime.getRuntime().exec(suPath);
                        final DataOutputStream os =
                            new DataOutputStream(suProc.getOutputStream());
                        final BufferedReader outReader =
                            new BufferedReader(new InputStreamReader(suProc.getInputStream()));
                        final BufferedReader errReader =
                            new BufferedReader(new InputStreamReader(suProc.getErrorStream()));

                        os.writeBytes("cmd overlay enable-exclusive --category com.android.internal.systemui.navbar.gestural\n");
                        os.writeBytes("echo DONE_1\n");
                        os.writeBytes("settings put secure navigation_mode 2\n");
                        os.writeBytes("echo DONE_2\n");
                        os.writeBytes("settings put global policy_control immersive.full=*\n");
                        os.writeBytes("echo DONE_3\n");
                        os.writeBytes("wm overscan 0,0,0,0\n");
                        os.writeBytes("echo DONE_4\n");
                        os.writeBytes("killall com.android.systemui\n");
                        os.writeBytes("echo DONE_5\n");
                        os.writeBytes("exit\n");
                        os.flush();

                        // Drain stdout/stderr in separate threads to prevent pipe buffer
                        // deadlock when command output exceeds the OS pipe buffer size.
                        final PrintWriter fLog = log;
                        Thread outThread = new Thread(new Runnable() {
                            public void run() {
                                try {
                                    String line;
                                    while ((line = outReader.readLine()) != null) {
                                        fLog.println("OUT: " + line);
                                        fLog.flush();
                                    }
                                } catch (Exception ignored) {}
                            }
                        });
                        Thread errThread = new Thread(new Runnable() {
                            public void run() {
                                try {
                                    String line;
                                    while ((line = errReader.readLine()) != null) {
                                        fLog.println("ERR: " + line);
                                        fLog.flush();
                                    }
                                } catch (Exception ignored) {}
                            }
                        });
                        outThread.start();
                        errThread.start();

                        int exit = suProc.waitFor();
                        outThread.join(3000);
                        errThread.join(3000);

                        log.println("exit=" + exit);
                        log.flush();

                        prefs.edit().putBoolean("nav_root_applied", true).apply();
                        log.println("nav_root_applied saved");
                    } catch (Throwable t) {
                        if (log != null) {
                            log.println("FATAL: " + t.getClass().getName() + ": " + t.getMessage());
                            t.printStackTrace(log);
                            log.flush();
                        }
                    } finally {
                        if (log != null) log.close();
                    }
                    // Re-apply window flags after SystemUI has restarted
                    try { Thread.sleep(2000); } catch (Exception ignored) {}
                    mMainHandler.post(new Runnable() {
                        public void run() { applyImmersive(); }
                    });
                }
            }).start();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        applyImmersive();
        new Thread(new Runnable() {
            public void run() {
                rootExec("settings put global policy_control immersive.full=*");
                rootExec("am broadcast -a android.intent.action.USER_PRESENT");
            }
        }).start();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            applyImmersive();
            new Thread(new Runnable() {
                public void run() {
                    rootExec("settings put global policy_control immersive.full=*");
                    rootExec("am broadcast -a android.intent.action.USER_PRESENT");
                }
            }).start();
        }
    }

    @SuppressWarnings("deprecation")
    private void applyImmersive() {
        // Layer 1: legacy systemUiVisibility — required on Samsung One UI 7 HOME
        // activities because WindowInsetsController alone is ignored there.
        int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
        getWindow().getDecorView().setSystemUiVisibility(flags);

        // Layer 2: WindowInsetsController (API 30+) applied simultaneously.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            android.view.WindowInsetsController wic = getWindow().getInsetsController();
            if (wic != null) {
                wic.hide(android.view.WindowInsets.Type.systemBars());
                wic.setSystemBarsBehavior(
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        }
    }

    // Scans known Magisk su install locations in order. Returns the first
    // executable found, or null if su is not present at any candidate path.
    private String findSu() {
        String[] candidates = {
            "/system/bin/su",
            "/sbin/su",
            "/su/bin/su",
            "/magisk/.core/bin/su",
            "/data/adb/magisk/su"
        };
        for (String path : candidates) {
            if (new File(path).exists()) return path;
        }
        return null;
    }

    // Executes a single root command using the located su binary.
    // Uses waitFor() for sequential ordering across callers.
    private void rootExec(String cmd) {
        String su = findSu();
        if (su == null) return;
        try {
            Process p = Runtime.getRuntime().exec(new String[]{su, "-c", cmd});
            p.waitFor();
        } catch (Exception ignored) {}
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            mWebView.evaluateJavascript(
                "if(typeof drawerOpen!='undefined'&&drawerOpen)closeDrawer();", null);
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mIconPool.shutdownNow();
    }

    private class PlasmaJS {

        @JavascriptInterface
        public void requestApps() {
            final PackageManager pm = getPackageManager();
            final Intent launchIntent = new Intent(Intent.ACTION_MAIN);
            launchIntent.addCategory(Intent.CATEGORY_LAUNCHER);

            mMainHandler.postDelayed(new Runnable() {
                public void run() {
                    mWebView.evaluateJavascript("if(!appsLoaded)renderApps([])", null);
                }
            }, 3000);

            mIconPool.submit(new Runnable() {
                public void run() {
                    try {
                        List<android.content.pm.ResolveInfo> list;
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            list = pm.queryIntentActivities(launchIntent,
                                PackageManager.ResolveInfoFlags.of(0));
                        } else {
                            //noinspection deprecation
                            list = pm.queryIntentActivities(launchIntent, 0);
                        }

                        long deadline = System.currentTimeMillis() + 3000;
                        JSONArray arr = new JSONArray();
                        for (android.content.pm.ResolveInfo ri : list) {
                            if (System.currentTimeMillis() > deadline) break;
                            String pkg = ri.activityInfo.packageName;
                            if (pkg.equals(getPackageName())) continue;
                            try {
                                ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
                                String label = pm.getApplicationLabel(ai).toString();
                                JSONObject o = new JSONObject();
                                o.put("pkg", pkg);
                                o.put("label", label);
                                arr.put(o);
                            } catch (Exception ignored) {}
                        }
                        final String json = sortByLabel(arr).toString();
                        mMainHandler.post(new Runnable() {
                            public void run() {
                                mWebView.evaluateJavascript("renderApps(" + json + ")", null);
                            }
                        });
                        sendShelfApps(pm);
                    } catch (Exception ignored) {}
                }
            });
        }

        @JavascriptInterface
        public void getAppIcon(final String pkg) {
            mIconPool.submit(new Runnable() {
                public void run() {
                    final String b64 = iconToBase64(getPackageManager(), pkg);
                    if (b64.isEmpty()) return;
                    mMainHandler.post(new Runnable() {
                        public void run() {
                            mWebView.evaluateJavascript(
                                "renderAppIcon(\"" + pkg + "\",\"" + b64 + "\")", null);
                        }
                    });
                }
            });
        }

        @JavascriptInterface
        public void launchApp(String pkg) {
            try {
                Intent intent = getPackageManager().getLaunchIntentForPackage(pkg);
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(intent);
                    return;
                }
            } catch (Exception ignored) {}
            try {
                Runtime.getRuntime().exec("am start -n " + pkg);
            } catch (Exception ignored) {}
        }

        @JavascriptInterface
        public void openSearch() {
            try {
                Intent i = new Intent(Intent.ACTION_WEB_SEARCH);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
            } catch (Exception ignored) {
                mMainHandler.post(new Runnable() {
                    public void run() {
                        mWebView.evaluateJavascript("openDrawer();", null);
                    }
                });
            }
        }

        @JavascriptInterface
        public void openRecents() {
            mMainHandler.post(new Runnable() {
                public void run() {
                    try {
                        mWebView.dispatchKeyEvent(
                            new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_APP_SWITCH));
                        mWebView.dispatchKeyEvent(
                            new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_APP_SWITCH));
                    } catch (Exception ignored) {
                        try {
                            Runtime.getRuntime().exec("input keyevent KEYCODE_APP_SWITCH");
                        } catch (Exception e) {}
                    }
                }
            });
        }

        @JavascriptInterface
        public void goBack() {
            mMainHandler.post(new Runnable() {
                public void run() {
                    mWebView.evaluateJavascript(
                        "if(typeof drawerOpen!='undefined'&&drawerOpen)closeDrawer();", null);
                }
            });
        }

        @JavascriptInterface
        public int getNavBarHeight() {
            int id = getResources().getIdentifier("navigation_bar_height", "dimen", "android");
            return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
        }

        @JavascriptInterface
        public int getStatusBarHeight() {
            int id = getResources().getIdentifier("status_bar_height", "dimen", "android");
            return id > 0 ? getResources().getDimensionPixelSize(id) : 0;
        }

        @JavascriptInterface
        public void resetNavBar() {
            new Thread(new Runnable() {
                public void run() {
                    rootExec("settings put secure navigation_mode 0");
                    rootExec("killall com.android.systemui");
                }
            }).start();
        }

        @JavascriptInterface
        public void restoreNavBar() {
            new Thread(new Runnable() {
                public void run() {
                    rootExec("settings put secure navigation_mode 0");
                    rootExec("killall com.android.systemui");
                }
            }).start();
        }

        private void sendShelfApps(final PackageManager pm) {
            final String[] pkgs = {
                "com.samsung.android.dialer", "com.android.dialer",
                "com.samsung.android.messaging", "com.android.mms",
                "com.sec.android.app.camera", "com.android.camera2",
                "org.kde.kdeconnect_tp", "org.kde.kasts"
            };
            final String[] labels = {
                "Phone", "Phone", "Messages", "Messages",
                "Camera", "Camera", "KDE Connect", "Kasts"
            };
            try {
                JSONArray arr = new JSONArray();
                for (int i = 0; i < pkgs.length && arr.length() < 5; i++) {
                    try {
                        pm.getApplicationInfo(pkgs[i], 0);
                        JSONObject o = new JSONObject();
                        o.put("pkg", pkgs[i]);
                        o.put("label", labels[i]);
                        o.put("icon", iconToBase64(pm, pkgs[i]));
                        arr.put(o);
                    } catch (PackageManager.NameNotFoundException ignored) {}
                }
                if (arr.length() == 0) return;
                final String json = arr.toString();
                mMainHandler.post(new Runnable() {
                    public void run() {
                        mWebView.evaluateJavascript("renderShelfApps(" + json + ")", null);
                    }
                });
            } catch (Exception ignored) {}
        }

        private String iconToBase64(PackageManager pm, String pkg) {
            try {
                Drawable d = pm.getApplicationIcon(pkg);
                Bitmap bm = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888);
                Canvas c = new Canvas(bm);
                d.setBounds(0, 0, 96, 96);
                d.draw(c);
                ByteArrayOutputStream bos = new ByteArrayOutputStream();
                bm.compress(Bitmap.CompressFormat.PNG, 80, bos);
                bm.recycle();
                return Base64.encodeToString(bos.toByteArray(), Base64.NO_WRAP);
            } catch (Exception e) {
                return "";
            }
        }

        private JSONArray sortByLabel(JSONArray arr) {
            try {
                int n = arr.length();
                for (int i = 0; i < n - 1; i++) {
                    for (int j = 0; j < n - i - 1; j++) {
                        String a = arr.getJSONObject(j).getString("label").toLowerCase();
                        String b = arr.getJSONObject(j + 1).getString("label").toLowerCase();
                        if (a.compareTo(b) > 0) {
                            JSONObject tmp = arr.getJSONObject(j);
                            arr.put(j, arr.getJSONObject(j + 1));
                            arr.put(j + 1, tmp);
                        }
                    }
                }
            } catch (Exception ignored) {}
            return arr;
        }
    }
}
