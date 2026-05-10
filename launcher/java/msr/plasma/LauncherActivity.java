package msr.plasma;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.util.Base64;
import android.view.KeyEvent;
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

public class LauncherActivity extends Activity {

    private WebView mWebView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);

        mWebView = new WebView(this);
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
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            mWebView.evaluateJavascript("if(typeof drawerOpen!='undefined'&&drawerOpen)closeDrawer();", null);
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private class PlasmaJS {

        @JavascriptInterface
        public void requestApps() {
            final PackageManager pm = getPackageManager();
            final Intent launchIntent = new Intent(Intent.ACTION_MAIN);
            launchIntent.addCategory(Intent.CATEGORY_LAUNCHER);
            final List<android.content.pm.ResolveInfo> list =
                    pm.queryIntentActivities(launchIntent, 0);

            new Thread(new Runnable() {
                public void run() {
                    try {
                        JSONArray arr = new JSONArray();
                        for (android.content.pm.ResolveInfo ri : list) {
                            String pkg = ri.activityInfo.packageName;
                            if (pkg.equals(getPackageName())) continue;
                            try {
                                ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
                                String label = pm.getApplicationLabel(ai).toString();
                                String icon = iconToBase64(pm, pkg);
                                JSONObject o = new JSONObject();
                                o.put("pkg", pkg);
                                o.put("label", label);
                                o.put("icon", icon);
                                arr.put(o);
                            } catch (Exception ignored) { /* skip bad entries */ }
                        }
                        final JSONArray sorted = sortByLabel(arr);
                        final String json = sorted.toString();
                        runOnUiThread(new Runnable() {
                            public void run() {
                                mWebView.evaluateJavascript("renderApps(" + json + ")", null);
                            }
                        });
                        sendShelfApps(pm);
                    } catch (Exception ignored) { /* whole op failed silently */ }
                }
            }).start();
        }

        private void sendShelfApps(final PackageManager pm) {
            final String[] pkgs   = {
                "com.samsung.android.dialer", "com.android.dialer",
                "com.samsung.android.messaging", "com.android.mms",
                "com.sec.android.app.camera", "com.android.camera2",
                "org.kde.kdeconnect_tp",
                "org.kde.kasts"
            };
            final String[] labels = {
                "Phone", "Phone",
                "Messages", "Messages",
                "Camera", "Camera",
                "KDE Connect",
                "Kasts"
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
                runOnUiThread(new Runnable() {
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
                openDrawerViaJs();
            }
        }

        @JavascriptInterface
        public void openRecents() {
            runOnUiThread(new Runnable() {
                public void run() {
                    mWebView.dispatchKeyEvent(new KeyEvent(
                            KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_APP_SWITCH));
                    mWebView.dispatchKeyEvent(new KeyEvent(
                            KeyEvent.ACTION_UP, KeyEvent.KEYCODE_APP_SWITCH));
                }
            });
        }

        @JavascriptInterface
        public void goBack() {
            runOnUiThread(new Runnable() {
                public void run() {
                    mWebView.evaluateJavascript(
                        "if(typeof drawerOpen!='undefined'&&drawerOpen)closeDrawer();", null);
                }
            });
        }

        private void openDrawerViaJs() {
            runOnUiThread(new Runnable() {
                public void run() {
                    mWebView.evaluateJavascript("openDrawer();", null);
                }
            });
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
