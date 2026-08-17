package msr.plasma;

import android.app.Activity;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileWriter;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class LauncherActivity extends Activity {

    private static final String MOD_DIR  = "/data/adb/modules/privacy-hardening";
    private static final String CONF     = "/data/local/tmp/plasma-harden.conf";
    private static final String RB_CONF  = "/data/local/tmp/plasma-reboot-hours";
    private static final String[] KEYS   = {
        "WIFI_MAC_RANDOM", "AUTO_REVOKE", "RESTRICT_SIDELOAD",
        "NFC_DISABLED", "BLUETOOTH_DISABLED", "BLE_SCAN_DISABLED",
        "WIFI_SCAN_DISABLED", "WIRELESS_ADB_DISABLED"
    };

    private WebView mWebView;
    private ExecutorService mPool;
    private final Handler mMain = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        mPool = Executors.newFixedThreadPool(4);
        mWebView = new WebView(this);
        mWebView.setBackgroundColor(Color.parseColor("#0f0f0f"));

        WebSettings ws = mWebView.getSettings();
        ws.setJavaScriptEnabled(true);
        ws.setDomStorageEnabled(true);

        mWebView.setWebViewClient(new WebViewClient());
        mWebView.setWebChromeClient(new WebChromeClient());
        mWebView.addJavascriptInterface(new JS(), "Android");
        mWebView.loadUrl("file:///android_asset/plasma/index.html");

        setContentView(mWebView);
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        mPool.shutdownNow();
    }

    private String findSu() {
        String[] cands = {
            "/debug_ramdisk/su", "/system/bin/su", "/sbin/su",
            "/su/bin/su", "/data/adb/magisk/su"
        };
        for (String p : cands) if (new File(p).exists()) return p;
        return null;
    }

    private void rootExec(String cmd) {
        String su = findSu();
        if (su == null) return;
        try {
            Process p = Runtime.getRuntime().exec(new String[]{su, "-c", cmd});
            p.waitFor();
        } catch (Exception ignored) {}
    }

    private String rootOut(String cmd) {
        String su = findSu();
        if (su == null) return "";
        try {
            Process p = Runtime.getRuntime().exec(new String[]{su, "-c", cmd});
            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = r.readLine()) != null) sb.append(line).append('\n');
            p.waitFor();
            return sb.toString().trim();
        } catch (Exception e) { return ""; }
    }

    private Map<String, String> readConf() {
        Map<String, String> m = new LinkedHashMap<>();
        for (String k : KEYS) m.put(k, "1");
        String raw = rootOut("cat " + CONF + " 2>/dev/null");
        if (!raw.isEmpty()) {
            for (String line : raw.split("\n")) {
                int eq = line.indexOf('=');
                if (eq > 0) m.put(line.substring(0, eq).trim(), line.substring(eq + 1).trim());
            }
        }
        return m;
    }

    private void writeConf(Map<String, String> m) {
        StringBuilder sb = new StringBuilder();
        for (Map.Entry<String, String> e : m.entrySet())
            sb.append(e.getKey()).append('=').append(e.getValue()).append('\n');
        String b64 = Base64.encodeToString(sb.toString().getBytes(), Base64.NO_WRAP);
        rootExec("echo " + b64 + " | base64 -d > " + CONF);
    }

    private class JS {

        @JavascriptInterface
        public boolean hasSu() { return findSu() != null; }

        @JavascriptInterface
        public void log(final String msg) {
            mPool.submit(new Runnable() { public void run() {
                try {
                    new File("/data/local/tmp").mkdirs();
                    PrintWriter w = new PrintWriter(new FileWriter("/data/local/tmp/privacy-webview.log", true));
                    w.println("[" + System.currentTimeMillis() + "] " + msg);
                    w.close();
                } catch (Exception ignored) {}
            }});
        }

        // Returns "enabled", "disabled", or "missing" for a single package.
        @JavascriptInterface
        public String pkgStatus(String pkg) {
            try {
                ApplicationInfo ai = getPackageManager().getApplicationInfo(pkg, 0);
                return ai.enabled ? "enabled" : "disabled";
            } catch (PackageManager.NameNotFoundException e) { return "missing"; }
        }

        // Takes comma-separated package names, returns JSON map pkg→status.
        @JavascriptInterface
        public String pkgStatuses(String csv) {
            StringBuilder sb = new StringBuilder("{");
            boolean first = true;
            for (String pkg : csv.split(",")) {
                pkg = pkg.trim();
                if (pkg.isEmpty()) continue;
                if (!first) sb.append(',');
                sb.append('"').append(pkg).append("\":\"").append(pkgStatus(pkg)).append('"');
                first = false;
            }
            return sb.append('}').toString();
        }

        // Disable or enable one package, then calls back onPkg(pkg, newStatus).
        @JavascriptInterface
        public void setPkg(final String pkg, final boolean enable) {
            mPool.submit(new Runnable() { public void run() {
                rootExec((enable ? "pm enable --user 0 " : "pm disable-user --user 0 ") + pkg);
                final String st = pkgStatus(pkg);
                mMain.post(new Runnable() { public void run() {
                    mWebView.evaluateJavascript("onPkg('" + pkg + "','" + st + "')", null);
                }});
            }});
        }

        // Disable all packages in comma-separated list, then calls back onBatch(csv).
        @JavascriptInterface
        public void disableAll(final String csv) {
            mPool.submit(new Runnable() { public void run() {
                for (String pkg : csv.split(",")) {
                    pkg = pkg.trim();
                    if (!pkg.isEmpty()) rootExec("pm disable-user --user 0 " + pkg);
                }
                final String done = csv;
                mMain.post(new Runnable() { public void run() {
                    mWebView.evaluateJavascript("onBatch('" + done + "')", null);
                }});
            }});
        }

        // Hardening config read → calls renderHardening(cfg).
        @JavascriptInterface
        public void getHardening() {
            mPool.submit(new Runnable() { public void run() {
                Map<String, String> m = readConf();
                int hours = 24;
                try { hours = Integer.parseInt(rootOut("cat " + RB_CONF + " 2>/dev/null")); }
                catch (Exception ignored) {}
                StringBuilder sb = new StringBuilder("{");
                boolean first = true;
                for (Map.Entry<String, String> e : m.entrySet()) {
                    if (!first) sb.append(',');
                    sb.append('"').append(e.getKey()).append("\":").append(e.getValue());
                    first = false;
                }
                sb.append(",\"rebootHours\":").append(hours).append('}');
                final String json = sb.toString();
                mMain.post(new Runnable() { public void run() {
                    mWebView.evaluateJavascript("renderHardening(" + json + ")", null);
                }});
            }});
        }

        @JavascriptInterface
        public void setHardening(final String key, final boolean on) {
            boolean valid = false;
            for (String k : KEYS) if (k.equals(key)) { valid = true; break; }
            if (!valid) return;
            mPool.submit(new Runnable() { public void run() {
                Map<String, String> m = readConf();
                m.put(key, on ? "1" : "0");
                writeConf(m);
                applyHardening(key, on);
            }});
        }

        private void applyHardening(String key, boolean on) {
            switch (key) {
                case "WIFI_MAC_RANDOM":
                    rootExec("settings put global wifi_connected_mac_randomization_enabled " + (on?"1":"0")); break;
                case "AUTO_REVOKE":
                    rootExec("device_config put permissions auto_revoke_enabled " + (on?"true":"false")); break;
                case "NFC_DISABLED":      rootExec(on ? "svc nfc disable"       : "svc nfc enable");       break;
                case "BLUETOOTH_DISABLED":rootExec(on ? "svc bluetooth disable"  : "svc bluetooth enable"); break;
                case "BLE_SCAN_DISABLED":
                    rootExec("settings put global ble_scan_always_enabled "  + (on?"0":"1")); break;
                case "WIFI_SCAN_DISABLED":
                    rootExec("settings put global wifi_scan_always_enabled " + (on?"0":"1")); break;
                case "WIRELESS_ADB_DISABLED":
                    rootExec("settings put global adb_wifi_enabled "         + (on?"0":"1")); break;
                case "RESTRICT_SIDELOAD":
                    if (on) rootExec("sh " + MOD_DIR + "/harden.sh");
                    else rootExec("for p in $(pm list packages -3|sed 's/^package://');do appops set $p REQUEST_INSTALL_PACKAGES allow;done");
                    break;
            }
        }

        @JavascriptInterface
        public void setRebootHours(final int h) {
            mPool.submit(new Runnable() { public void run() {
                rootExec("echo " + (h < 1 ? 1 : h) + " > " + RB_CONF);
            }});
        }

        @JavascriptInterface
        public void runHardening() {
            mPool.submit(new Runnable() { public void run() {
                rootExec("sh " + MOD_DIR + "/harden.sh");
            }});
        }
    }
}
