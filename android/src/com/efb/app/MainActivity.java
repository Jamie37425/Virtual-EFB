package com.efb.app;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DownloadManager;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.JsResult;
import android.webkit.MimeTypeMap;
import android.webkit.PermissionRequest;
import android.webkit.URLUtil;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * EFB shell app.
 *  - The EFB home screen / top bar / local apps (checklists, calculator) live in a WebView ("shell")
 *    served from the app's bundled assets at https://appassets.androidplatform.net/.
 *  - Every website app (FSLabs, Navigraph, VATSIM Radar...) gets its OWN WebView placed underneath the
 *    EFB top bar. Because they are real top-level pages and not iframes, no site can block them.
 *  - A native draggable home button floats above everything.
 */
public class MainActivity extends Activity {
    static final String HOST = "appassets.androidplatform.net";

    FrameLayout root, container;
    WebView shell;
    FrameLayout orb;
    final Map<String, WebView> apps = new HashMap<>();
    String activeId = null;
    boolean orbPlaced = false;
    ValueCallback<Uri[]> fileUploadCallback;
    static final int FILE_CHOOSER_REQ = 2001;

    float dp(float v) { return v * getResources().getDisplayMetrics().density; }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        if (Build.VERSION.SDK_INT >= 28) {
            getWindow().getAttributes().layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
        }
        root = new FrameLayout(this);
        root.setBackgroundColor(0xFF050B14);

        shell = makeWebView(true);
        shell.addJavascriptInterface(new Bridge(), "EFBNative");
        root.addView(shell, new FrameLayout.LayoutParams(-1, -1));

        container = new FrameLayout(this);
        container.setBackgroundColor(0xFF050B14);
        container.setVisibility(View.GONE);
        FrameLayout.LayoutParams clp = new FrameLayout.LayoutParams(-1, -1);
        clp.topMargin = (int) dp(48);
        root.addView(container, clp);

        orb = buildOrb();
        orb.setVisibility(View.GONE);
        root.addView(orb, new FrameLayout.LayoutParams((int) dp(56), (int) dp(56)));

        setContentView(root);
        immersive();
        shell.loadUrl("https://" + HOST + "/index.html");
    }

    void immersive() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY | View.SYSTEM_UI_FLAG_FULLSCREEN
                | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) immersive();
    }

    /* ---------------- floating native home button ---------------- */
    FrameLayout buildOrb() {
        FrameLayout f = new FrameLayout(this);
        GradientDrawable ring = new GradientDrawable();
        ring.setShape(GradientDrawable.OVAL);
        ring.setColor(0xB3101A2A);
        ring.setStroke((int) dp(2), 0xCC9FB4CC);
        f.setBackground(ring);
        View core = new View(this);
        GradientDrawable c = new GradientDrawable();
        c.setShape(GradientDrawable.OVAL);
        c.setColor(0xE6E8F1FA);
        core.setBackground(c);
        FrameLayout.LayoutParams cl = new FrameLayout.LayoutParams((int) dp(24), (int) dp(24));
        cl.gravity = android.view.Gravity.CENTER;
        f.addView(core, cl);
        f.setElevation(dp(8));

        final float slop = dp(8);
        f.setOnTouchListener(new View.OnTouchListener() {
            float dx, dy, sx, sy;
            boolean moved;
            @Override
            public boolean onTouch(View v, MotionEvent e) {
                switch (e.getActionMasked()) {
                    case MotionEvent.ACTION_DOWN:
                        sx = e.getRawX(); sy = e.getRawY();
                        dx = v.getX() - sx; dy = v.getY() - sy;
                        moved = false;
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        if (Math.abs(e.getRawX() - sx) > slop || Math.abs(e.getRawY() - sy) > slop) moved = true;
                        if (moved) {
                            float nx = Math.max(0, Math.min(root.getWidth() - v.getWidth(), e.getRawX() + dx));
                            float ny = Math.max(0, Math.min(root.getHeight() - v.getHeight(), e.getRawY() + dy));
                            v.setX(nx); v.setY(ny);
                        }
                        return true;
                    case MotionEvent.ACTION_UP:
                        if (!moved) goHomeFromNative();
                        return true;
                }
                return false;
            }
        });
        return f;
    }

    void goHomeFromNative() {
        shell.evaluateJavascript("window.efbGoHome && window.efbGoHome()", null);
    }

    void placeOrbOnce() {
        if (orbPlaced) return;
        orbPlaced = true;
        orb.setX(root.getWidth() - dp(56) - dp(20));
        orb.setY(root.getHeight() - dp(56) - dp(24));
    }

    /* ---------------- web views ---------------- */
    WebView makeWebView(final boolean isShell) {
        final WebView wv = new WebView(this);
        wv.setBackgroundColor(0xFF050B14);
        WebSettings s = wv.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        // Only the EFB's own pages may talk to the PC over plain http (checklists); websites stay strict.
        s.setMixedContentMode(isShell ? WebSettings.MIXED_CONTENT_ALWAYS_ALLOW : WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE);
        s.setJavaScriptCanOpenWindowsAutomatically(true);
        s.setSupportMultipleWindows(false);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        s.setSupportZoom(true);
        s.setBuiltInZoomControls(true);
        s.setDisplayZoomControls(false);
        s.setGeolocationEnabled(true);
        // Look like regular mobile Chrome (not an embedded "wv" WebView) so sites and Cloudflare are happy.
        String ua = s.getUserAgentString().replace("; wv", "").replace("Version/4.0 ", "");
        s.setUserAgentString(ua);

        CookieManager cm = CookieManager.getInstance();
        cm.setAcceptCookie(true);
        cm.setAcceptThirdPartyCookies(wv, true);

        wv.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (HOST.equals(u.getHost())) return serveAsset(u);
                return null;
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest req) {
                Uri u = req.getUrl();
                String sch = u.getScheme() == null ? "" : u.getScheme();
                if (sch.equals("http") || sch.equals("https")) {
                    if (view == shell && !HOST.equals(u.getHost())) { openExternal(u.toString()); return true; }
                    return false;
                }
                if (sch.equals("about") || sch.equals("blob") || sch.equals("data")) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) {}
                return true;
            }
        });

        wv.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback cb) {
                cb.invoke(origin, true, false);
            }
            @Override
            public void onPermissionRequest(PermissionRequest r) { r.grant(r.getResources()); }
            @Override
            public boolean onJsAlert(WebView v, String url, String msg, final JsResult r) {
                new AlertDialog.Builder(MainActivity.this).setMessage(msg)
                    .setPositiveButton("OK", (d, w) -> r.confirm())
                    .setOnCancelListener(d -> r.cancel()).show();
                return true;
            }
            @Override
            public boolean onJsConfirm(WebView v, String url, String msg, final JsResult r) {
                new AlertDialog.Builder(MainActivity.this).setMessage(msg)
                    .setPositiveButton("OK", (d, w) -> r.confirm())
                    .setNegativeButton("Cancel", (d, w) -> r.cancel())
                    .setOnCancelListener(d -> r.cancel()).show();
                return true;
            }
            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
                if (fileUploadCallback != null) {
                    fileUploadCallback.onReceiveValue(null);
                }
                fileUploadCallback = filePathCallback;
                try {
                    Intent intent = fileChooserParams.createIntent();
                    startActivityForResult(intent, FILE_CHOOSER_REQ);
                    return true;
                } catch (Exception e) {
                    fileUploadCallback = null;
                    return false;
                }
            }
        });

        wv.setDownloadListener((url, ua2, cd, mime, len) -> {
            try {
                DownloadManager.Request rq = new DownloadManager.Request(Uri.parse(url));
                rq.setMimeType(mime);
                rq.addRequestHeader("Cookie", CookieManager.getInstance().getCookie(url));
                rq.addRequestHeader("User-Agent", ua2);
                rq.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
                rq.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, URLUtil.guessFileName(url, cd, mime));
                ((DownloadManager) getSystemService(DOWNLOAD_SERVICE)).enqueue(rq);
            } catch (Exception ignored) {}
        });
        return wv;
    }

    WebResourceResponse serveAsset(Uri u) {
        String path = u.getPath() == null ? "" : u.getPath();
        while (path.startsWith("/")) path = path.substring(1);
        if (path.isEmpty()) path = "index.html";
        try {
            InputStream in = getAssets().open(path);
            return new WebResourceResponse(mimeFor(path), "utf-8", in);
        } catch (Exception e) {
            Map<String, String> h = new HashMap<>();
            return new WebResourceResponse("text/plain", "utf-8", 404, "Not Found", h,
                new java.io.ByteArrayInputStream("Not Found".getBytes()));
        }
    }

    static String mimeFor(String path) {
        String p = path.toLowerCase();
        if (p.endsWith(".html") || p.endsWith(".htm")) return "text/html";
        if (p.endsWith(".js") || p.endsWith(".mjs")) return "application/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".json")) return "application/json";
        if (p.endsWith(".svg")) return "image/svg+xml";
        if (p.endsWith(".webmanifest")) return "application/manifest+json";
        if (p.endsWith(".wasm")) return "application/wasm";
        String ext = MimeTypeMap.getFileExtensionFromUrl(path);
        String m = ext == null ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext);
        return m == null ? "application/octet-stream" : m;
    }

    void openExternal(String url) {
        try {
            Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            i.addCategory(Intent.CATEGORY_BROWSABLE);
            startActivity(i);
        } catch (Exception ignored) {}
    }

    void showApp(String id) {
        activeId = id;
        for (Map.Entry<String, WebView> en : apps.entrySet()) {
            en.getValue().setVisibility(en.getKey().equals(id) ? View.VISIBLE : View.GONE);
        }
        container.setVisibility(View.VISIBLE);
    }

    void hideApps() {
        activeId = null;
        container.setVisibility(View.GONE);
    }

    /* ---------------- JS bridge (window.EFBNative) ---------------- */
    class Bridge {
        @JavascriptInterface public int version() { return 1; }

        @JavascriptInterface
        public void openApp(final String id, final String url, final int topPx) {
            runOnUiThread(() -> {
                FrameLayout.LayoutParams lp = (FrameLayout.LayoutParams) container.getLayoutParams();
                lp.topMargin = topPx;
                container.setLayoutParams(lp);
                WebView w = apps.get(id);
                if (w == null) {
                    w = makeWebView(false);
                    apps.put(id, w);
                    container.addView(w, new FrameLayout.LayoutParams(-1, -1));
                    w.loadUrl(url);
                }
                showApp(id);
                placeOrbOnce();
                orb.setVisibility(View.VISIBLE);
            });
        }

        @JavascriptInterface
        public void hideApps() {
            runOnUiThread(() -> { MainActivity.this.hideApps(); orb.setVisibility(View.GONE); });
        }

        @JavascriptInterface
        public void setOrb(final boolean visible) {
            runOnUiThread(() -> {
                if (visible) placeOrbOnce();
                orb.setVisibility(visible ? View.VISIBLE : View.GONE);
            });
        }

        @JavascriptInterface
        public void closeApp(final String id) {
            runOnUiThread(() -> {
                WebView w = apps.remove(id);
                if (w != null) { container.removeView(w); w.destroy(); }
                if (id.equals(activeId)) MainActivity.this.hideApps();
            });
        }

        @JavascriptInterface
        public void reloadApp(final String id) {
            runOnUiThread(() -> { WebView w = apps.get(id); if (w != null) w.reload(); });
        }

        @JavascriptInterface
        public String currentUrl(final String id) {
            WebView w = apps.get(id);
            return w == null ? "" : String.valueOf(w.getUrl());
        }

        @JavascriptInterface
        public void openExternal(final String url) {
            runOnUiThread(() -> MainActivity.this.openExternal(url));
        }

        @JavascriptInterface
        public void keepAwake(final boolean on) {
            runOnUiThread(() -> {
                if (on) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            });
        }

        @JavascriptInterface
        public String fetchUrl(final String urlString) {
            try {
                java.net.URL url = new java.net.URL(urlString);
                java.net.HttpURLConnection conn = (java.net.HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setConnectTimeout(8000);
                conn.setReadTimeout(8000);
                conn.setRequestProperty("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
                if (conn.getResponseCode() >= 200 && conn.getResponseCode() < 400) {
                    java.io.InputStream in = conn.getInputStream();
                    java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream();
                    byte[] buffer = new byte[8192];
                    int len;
                    while ((len = in.read(buffer)) > 0) {
                        out.write(buffer, 0, len);
                    }
                    in.close();
                    return new String(out.toByteArray(), "UTF-8");
                }
            } catch (Exception ignored) {}
            return "";
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == FILE_CHOOSER_REQ) {
            if (fileUploadCallback != null) {
                Uri[] results = null;
                if (resultCode == Activity.RESULT_OK && data != null) {
                    if (data.getClipData() != null) {
                        int count = data.getClipData().getItemCount();
                        results = new Uri[count];
                        for (int i = 0; i < count; i++) {
                            results[i] = data.getClipData().getItemAt(i).getUri();
                        }
                    } else if (data.getData() != null) {
                        results = new Uri[]{data.getData()};
                    }
                }
                fileUploadCallback.onReceiveValue(results);
                fileUploadCallback = null;
            }
        } else {
            super.onActivityResult(requestCode, resultCode, data);
        }
    }

    @Override
    public void onBackPressed() {
        if (activeId != null) {
            WebView w = apps.get(activeId);
            if (w != null && w.canGoBack()) { w.goBack(); return; }
            goHomeFromNative();
            return;
        }
        shell.evaluateJavascript("(function(){var d=document.querySelector('dialog[open]');if(d){d.close();return 1;}return 0;})()",
            value -> { if (!"1".equals(value)) moveTaskToBack(true); });
    }

    @Override
    protected void onPause() {
        super.onPause();
        CookieManager.getInstance().flush();
    }

    @Override
    protected void onDestroy() {
        CookieManager.getInstance().flush();
        super.onDestroy();
    }
}
