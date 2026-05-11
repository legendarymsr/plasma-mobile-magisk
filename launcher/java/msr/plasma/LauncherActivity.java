package msr.plasma;

import android.app.Activity;
import android.content.Intent;
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

import java.io.ByteArrayOutputStream;
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

        // Root layer — 4-step sequence to eliminate nav bar at system level.
        // Samsung WM pre-subtracts nav bar from window bounds before immersive applies;
        // only removing the bar via root bypasses that pre-subtraction.
        new Thread(new Runnable() {
            public void run() {
                java.io.PrintWriter log = null;
                try {
                    log = new java.io.PrintWriter(
                        new java.io.FileWriter("/data/local/tmp/plasma-nav.log", true));
                    log.println("[" + System.currentTimeMillis() + "] plasma-mobile nav-hide start");
                    log.flush();

                    // Step 1: switch to gesture navigation
                    Process p = Runtime.getRuntime().exec(new String[]{"su", "-c",
                        "cmd overlay enable-exclusive --category com.android.internal.systemui.navbar.gestural"});
                    log.println("step1a (gestural overlay) exit=" + p.waitFor());
                    log.flush();
                    Thread.sleep(500);

                    p = Runtime.getRuntime().exec(new String[]{"su", "-c",
                        "settings put secure navigation_mode 2"});
                    log.println("step1b (navigation_mode 2) exit=" + p.waitFor());
                    log.flush();

                    // Step 2: force immersive for all apps via policy_control
                    p = Runtime.getRuntime().exec(new String[]{"su", "-c",
                        "settings put global policy_control immersive.full=*"});
                    log.println("step2 (policy_control) exit=" + p.waitFor());
                    log.flush();

                    // Step 3: restart SystemUI to apply nav mode change
                    p = Runtime.getRuntime().exec(new String[]{"su", "-c",
                        "killall com.android.systemui"});
                    log.println("step3 (killall systemui) exit=" + p.waitFor());
                    log.flush();

                    log.println("step4: sleeping 2000ms then re-applying window flags");
                } catch (Exception e) {
                    if (log != null) {
                        log.println("ERROR: " + e);
                        log.flush();
                    }
                } finally {
                    if (log != null) log.close();
                }
                // Step 4: re-apply window flags after SystemUI has restarted
                try { Thread.sleep(2000); } catch (Exception ignored) {}
                mMainHandler.post(new Runnable() {
                    public void run() { applyImmersive(); }
                });
            }
        }).start();
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

    // Executes a root shell command synchronously. Uses waitFor() so callers
    // running sequential commands (e.g. settings put then killall) get ordering.
    private void rootExec(String cmd) {
        try {
            Process p = Runtime.getRuntime().exec(new String[]{"su", "-c", cmd});
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
