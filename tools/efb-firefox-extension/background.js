// Strips X-Frame-Options, CSP frame-ancestors, CORP/COEP/COOP (which block VATSIM Radar),
// and rewrites every Set-Cookie line to SameSite=None; Secure so Navigraph, VATSIM SSO,
// vEZY, and FSLabs multi-cookie logins work inside EFB iframes.
browser.webRequest.onHeadersReceived.addListener(
  (details) => {
    const out = [];
    for (const h of details.responseHeaders || []) {
      const name = h.name.toLowerCase();

      // 1. Remove iframe & cross-origin isolation blocking headers
      if (
        name === 'x-frame-options' ||
        name === 'x-content-security-policy' ||
        name === 'cross-origin-resource-policy' ||
        name === 'cross-origin-embedder-policy' ||
        name === 'cross-origin-embedder-policy-report-only' ||
        name === 'cross-origin-opener-policy' ||
        name === 'cross-origin-opener-policy-report-only'
      ) {
        continue;
      }

      if (name === 'content-security-policy' || name === 'content-security-policy-report-only') {
        const cleaned = h.value
          .split(';')
          .filter((dir) => !/^\s*frame-ancestors\b/i.test(dir))
          .join(';');
        if (cleaned.trim()) out.push({ name: h.name, value: cleaned });
        continue;
      }

      // 2. Rewrite every Set-Cookie line (Firefox joins multiple Set-Cookie headers with \n)
      if (name === 'set-cookie' && h.value) {
        const fixedLines = h.value.split(/\r?\n/).map((line) => {
          if (!line.trim()) return line;
          let v = line.replace(/;\s*SameSite=(Lax|Strict|None)/gi, '');
          v = v.replace(/;\s*Partitioned\b/gi, '');
          v += '; SameSite=None';
          if (!/;\s*Secure\b/i.test(v)) v += '; Secure';
          return v;
        });
        out.push({ name: h.name, value: fixedLines.join('\n') });
        continue;
      }

      out.push(h);
    }

    // 3. Add Access-Control-Allow-Origin: * if not present
    if (!out.some((h) => h.name.toLowerCase() === 'access-control-allow-origin')) {
      out.push({ name: 'Access-Control-Allow-Origin', value: '*' });
    }
    return { responseHeaders: out };
  },
  { urls: ['<all_urls>'] },
  ['blocking', 'responseHeaders']
);
