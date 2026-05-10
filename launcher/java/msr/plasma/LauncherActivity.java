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

        // Transparent bars so the theme's translucent flags actually show through
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);

        // Black prevents white flash while WebView loads
        getWindow().getDecorView().setBackgroundColor(Color.BLACK);

        // Re-hide bars whenever Samsung's shell briefly un-hides them
        getWindow().getDecorView().setOnSystemUiVisibilityChangeListener(
            new View.OnSystemUiVisibilityChangeListener() {
                @Override
                public void onSystemUiVisibilityChange(int visibility) {
                    if ((visibility & View.SYSTEM_UI_FLAG_FULLSCREEN) == 0) {
                        applyImmersive();
                    }
                }
            }
        );

        mIconPool = Executors.newFixedThreadPool(3);

        mWebView = new WebView(this);
        mWebView.setBackgroundColor(Color.BLACK);
        // Prevent Android from adding inset padding — the WebView must fill the full screen
        mWebView.setFitsSystemWindows(false);
        setContentView(mWebView);

        WebSettings ws = mWebView.getSettings();
        ws.setJavaScriptEnabled(true);
        ws.setDomStorageEnabled(true);

        mWebView.setWebViewClient(new WebViewClient());
        mWebView.setWebChromeClient(new WebChromeClient());
        mWebView.addJavascriptInterface(new PlasmaJS(), "Android");
        mWebView.loadUrl("file:///android_asset/plasma/index.html");
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        // Called every time the launcher comes to foreground — Samsung needs this
        if (hasFocus) applyImmersive();
    }

    @SuppressWarnings("deprecation")
    private void applyImmersive() {
        // Layer 1: legacy systemUiVisibility — Samsung One UI 7 HOME activities ignore
        // WindowInsetsController alone; both layers must be set simultaneously.
        int flags = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
        getWindow().getDecorView().setSystemUiVisibility(flags);

        // Layer 2: WindowInsetsController (Android 11+) for forward-compatibility
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            android.view.WindowInsetsController wic = getWindow().getInsetsController();
            if (wic != null) {
                wic.hide(android.view.WindowInsets.Type.systemBars());
                wic.setSystemBarsBehavior(
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        }
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

            // If the background thread hasn't called renderApps within 3 s, unblock the UI
            mMainHandler.postDelayed(new Runnable() {
                public void run() {
                    mWebView.evaluateJavascript(
                        "if(!appsLoaded)renderApps([])", null);
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
                            } catch (Exception ignored) { /* skip */ }
                        }
                        final String json = sortByLabel(arr).toString();
                        mMainHandler.post(new Runnable() {
                            public void run() {
                                mWebView.evaluateJavascript("renderApps(" + json + ")", null);
                            }
                        });
                        sendShelfApps(pm);
                    } catch (Exception ignored) { /* ignored */ }
                }
            });
        }

        // Called by JavaScript for each app card that needs an icon.
        // Encodes a single icon on a pool thread and calls back renderAppIcon(pkg, b64).
        @JavascriptInterface
        public void getAppIcon(final String pkg) {
            mIconPool.submit(new Runnable() {
                public void run() {
                    final String b64 = iconToBase64(getPackageManager(), pkg);
                    if (b64.isEmpty()) return;
                    mMainHandler.post(new Runnable() {
                        public void run() {
                            mWebView.evaluateJavascript(
                                "renderAppIcon(" + jsonStr(pkg) + "," + jsonStr(b64) + ")", null);
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
                }
            } catch (Exception ignored) { /* ignored */ }
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
                    mWebView.dispatchKeyEvent(
                        new KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_APP_SWITCH));
                    mWebView.dispatchKeyEvent(
                        new KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_APP_SWITCH));
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

        // Shelf apps (max 5) are small enough to encode icons eagerly
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
                    } catch (PackageManager.NameNotFoundException ignored) { /* not installed */ }
                }
                if (arr.length() == 0) return;
                final String json = arr.toString();
                mMainHandler.post(new Runnable() {
                    public void run() {
                        mWebView.evaluateJavascript("renderShelfApps(" + json + ")", null);
                    }
                });
            } catch (Exception ignored) { /* ignored */ }
        }

        private String iconToBase64(PackageManager pm, String pkg) {
            try {
                Drawable d = pm.getApplicationIcon(pkg);
                int w = d.getIntrinsicWidth()  > 0 ? d.getIntrinsicWidth()  : 48;
                int h = d.getIntrinsicHeight() > 0 ? d.getIntrinsicHeight() : 48;
                Bitmap bm = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888);
                Canvas c = new Canvas(bm);
                d.setBounds(0, 0, w, h);
                d.draw(c);
                ByteArrayOutputStream bos = new ByteArrayOutputStream();
                bm.compress(Bitmap.CompressFormat.PNG, 80, bos);
                bm.recycle();
                return Base64.encodeToString(bos.toByteArray(), Base64.NO_WRAP);
            } catch (Exception e) {
                return "";
            }
        }

        private String jsonStr(String s) {
            return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
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
            } catch (Exception ignored) { /* return as-is */ }
            return arr;
        }
    }
}
