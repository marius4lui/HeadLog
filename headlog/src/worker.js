export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const stableTag = env.STABLE_TAG || env.DEFAULT_TAG || "latest";

    try {
      if (url.pathname === "/") {
        return new Response(renderLandingPage(stableTag), {
          headers: {
            "content-type": "text/html; charset=utf-8",
            "cache-control": "public, max-age=300",
          },
        });
      }

      if (url.pathname.startsWith("/meta")) {
        if (!env.GITHUB_TOKEN) {
          return new Response("Missing GITHUB_TOKEN secret", { status: 500 });
        }

        const tag = resolveTag(url.pathname.replace(/^\/meta/, "/download"), stableTag);
        const release = await fetchRelease(tag, env);
        const asset = pickApkAsset(
          release.assets,
          url.searchParams.get("asset"),
          env.APK_ASSET_NAME || "app-release.apk",
        );

        if (!asset) {
          return new Response(
            JSON.stringify({
              ok: false,
              error: `No APK asset found in release ${release.tag_name}.`,
            }),
            {
              status: 404,
              headers: { "content-type": "application/json; charset=utf-8" },
            },
          );
        }

        return Response.json({
          ok: true,
          tag: release.tag_name,
          name: release.name,
          requestedTag: tag,
          assetName: asset.name,
          sizeBytes: asset.size,
          sizeMb: Number((asset.size / (1024 * 1024)).toFixed(2)),
          contentType: asset.content_type,
          updatedAt: asset.updated_at,
          downloadPath: buildDownloadPath(tag, release.tag_name),
        });
      }

      if (!url.pathname.startsWith("/download")) {
        return new Response("Not found", { status: 404 });
      }

      if (!env.GITHUB_TOKEN) {
        return new Response("Missing GITHUB_TOKEN secret", { status: 500 });
      }

      const tag = resolveTag(url.pathname, stableTag);
      const release = await fetchRelease(tag, env);
      const asset = pickApkAsset(
        release.assets,
        url.searchParams.get("asset"),
        env.APK_ASSET_NAME || "app-release.apk",
      );

      if (!asset) {
        return new Response(
          `No APK asset found in release ${release.tag_name}.`,
          { status: 404 },
        );
      }

      const assetResponse = await fetch(
        `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/releases/assets/${asset.id}`,
        {
          headers: githubHeaders(env.GITHUB_TOKEN, "application/octet-stream"),
        },
      );

      if (!assetResponse.ok || !assetResponse.body) {
        return new Response(
          `Failed to download APK asset: ${await safeText(assetResponse)}`,
          { status: assetResponse.status || 502 },
        );
      }

      const headers = new Headers();
      headers.set(
        "content-type",
        asset.content_type || "application/vnd.android.package-archive",
      );
      headers.set("content-disposition", `attachment; filename="${asset.name}"`);
      headers.set("cache-control", "private, max-age=300");
      headers.set("x-headlog-release-tag", release.tag_name);

      if (asset.size) {
        headers.set("content-length", String(asset.size));
      }

      return new Response(assetResponse.body, {
        status: 200,
        headers,
      });
    } catch (error) {
      console.error("Release proxy failed", error);
      return new Response(
        JSON.stringify({
          ok: false,
          error: error instanceof Error ? error.message : "Unknown worker error",
        }),
        {
          status: 500,
          headers: { "content-type": "application/json; charset=utf-8" },
        },
      );
    }
  },
};

function renderLandingPage(stableTag) {
  const defaultMetaPath = stableTag === "latest" ? "/meta/latest" : "/meta";
  const defaultDownloadPath = stableTag === "latest" ? "/download/latest" : "/download";

  return `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>HeadLog</title>
    <meta
      name="description"
      content="Track headaches instantly with HeadLog. One tap to log, optional detail when you need it, and fast local-first review."
    />
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Manrope:wght@600;700;800&display=swap" rel="stylesheet">
    <style>
      :root {
        --surface: #f9f9fa;
        --surface-low: #f2f4f5;
        --surface-lowest: #ffffff;
        --surface-deep: #e9edf0;
        --text: #1c2228;
        --muted: #5a6063;
        --primary: #515f74;
        --primary-soft: #d5e3fc;
        --accent: #8ea5c8;
        --shadow: 0 20px 40px rgba(45, 51, 54, 0.06);
        --radius-xl: 40px;
        --radius-lg: 32px;
        --radius-pill: 999px;
      }

      * { box-sizing: border-box; }
      html { scroll-behavior: smooth; }
      body {
        margin: 0;
        font-family: Inter, sans-serif;
        color: var(--text);
        background:
          radial-gradient(circle at top left, rgba(213, 227, 252, 0.9), transparent 30%),
          linear-gradient(180deg, #fcfcfd 0%, var(--surface) 42%, #f4f6f7 100%);
      }

      a { color: inherit; text-decoration: none; }

      .shell {
        width: min(1180px, calc(100% - 32px));
        margin: 0 auto;
      }

      .topbar {
        position: sticky;
        top: 0;
        z-index: 10;
        backdrop-filter: blur(24px);
        background: rgba(249, 249, 250, 0.78);
      }

      .topbar-inner {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 18px 0;
      }

      .brand {
        display: flex;
        align-items: center;
        gap: 12px;
        font-weight: 800;
        letter-spacing: 0.02em;
      }

      .brand-mark {
        width: 42px;
        height: 42px;
        border-radius: 16px;
        background: linear-gradient(135deg, var(--primary) 0%, var(--primary-soft) 100%);
        box-shadow: var(--shadow);
      }

      .nav {
        display: flex;
        gap: 24px;
        color: var(--muted);
        font-size: 0.95rem;
      }

      .hero {
        padding: 48px 0 40px;
        display: grid;
        grid-template-columns: minmax(0, 1.05fr) minmax(320px, 0.95fr);
        gap: 36px;
        align-items: stretch;
      }

      .hero-copy {
        padding: 28px 0 8px;
      }

      .eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 10px;
        padding: 10px 14px;
        border-radius: var(--radius-pill);
        background: rgba(255, 255, 255, 0.72);
        color: var(--muted);
        font-size: 0.82rem;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      h1 {
        margin: 24px 0 0;
        font-family: Manrope, sans-serif;
        font-size: clamp(3rem, 7vw, 5.4rem);
        line-height: 0.95;
        letter-spacing: -0.06em;
        max-width: 720px;
      }

      .hero-copy p {
        margin: 28px 0 0;
        max-width: 600px;
        color: var(--muted);
        font-size: 1.05rem;
        line-height: 1.75;
      }

      .hero-actions {
        margin-top: 36px;
        display: flex;
        flex-wrap: wrap;
        gap: 14px;
      }

      .button {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 10px;
        min-height: 56px;
        padding: 0 24px;
        border-radius: var(--radius-pill);
        font-weight: 800;
        transition: transform 200ms ease, opacity 200ms ease;
      }

      .button:hover { transform: translateY(-1px); }
      .button-primary {
        color: white;
        background: linear-gradient(135deg, var(--primary) 0%, var(--primary-soft) 100%);
        box-shadow: var(--shadow);
      }
      .button-secondary {
        background: rgba(255,255,255,0.82);
        color: var(--primary);
      }

      .hero-panel {
        position: relative;
        min-height: 640px;
        border-radius: 48px;
        background: linear-gradient(180deg, rgba(255,255,255,0.9), rgba(255,255,255,0.68));
        box-shadow: var(--shadow);
        overflow: hidden;
      }

      .hero-glow {
        position: absolute;
        inset: auto auto -90px -40px;
        width: 320px;
        height: 320px;
        background: radial-gradient(circle, rgba(213, 227, 252, 0.92), transparent 65%);
      }

      .phone {
        position: absolute;
        top: 28px;
        right: 28px;
        left: 28px;
        bottom: 28px;
        border-radius: 36px;
        background: var(--surface-lowest);
        padding: 24px;
        display: flex;
        flex-direction: column;
        gap: 18px;
      }

      .phone-top {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
      }

      .phone-top small {
        display: block;
        color: var(--primary);
        font-size: 0.72rem;
        letter-spacing: 0.22em;
        font-weight: 800;
        text-transform: uppercase;
      }

      .phone-top h2 {
        margin: 6px 0 0;
        font-family: Manrope, sans-serif;
        font-size: 2.15rem;
        line-height: 1;
        letter-spacing: -0.05em;
      }

      .theme-pill {
        width: 56px;
        height: 56px;
        border-radius: 50%;
        background: var(--surface);
        display: grid;
        place-items: center;
        color: var(--primary);
        box-shadow: inset 0 0 0 1px rgba(173, 179, 182, 0.15);
      }

      .surface-card {
        border-radius: 32px;
        background: var(--surface);
        padding: 20px;
      }

      .segments {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 8px;
        padding: 6px;
        border-radius: 999px;
        background: var(--surface-deep);
      }

      .segments span {
        min-height: 44px;
        display: grid;
        place-items: center;
        border-radius: 999px;
        color: var(--muted);
        font-size: 0.74rem;
        font-weight: 800;
        letter-spacing: 0.18em;
        text-transform: uppercase;
      }

      .segments .active {
        background: var(--surface-lowest);
        color: var(--text);
      }

      .release-card {
        padding: 26px;
        border-radius: 32px;
        background: linear-gradient(180deg, #233040 0%, #3d4c61 100%);
        color: white;
      }

      .release-card strong {
        display: block;
        font-family: Manrope, sans-serif;
        font-size: 2.2rem;
        letter-spacing: -0.05em;
      }

      .release-meta {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
        margin-top: 18px;
      }

      .release-meta div {
        border-radius: 24px;
        padding: 16px;
        background: rgba(255,255,255,0.08);
      }

      .release-meta span {
        display: block;
        font-size: 0.74rem;
        text-transform: uppercase;
        letter-spacing: 0.12em;
        color: rgba(255,255,255,0.62);
      }

      .release-meta b {
        display: block;
        margin-top: 8px;
        font-size: 1rem;
      }

      .log-list {
        display: grid;
        gap: 14px;
      }

      .log-item {
        display: flex;
        gap: 16px;
        align-items: center;
        padding: 16px 18px;
        border-radius: 26px;
        background: var(--surface);
      }

      .dot {
        width: 12px;
        height: 12px;
        border-radius: 999px;
        flex: 0 0 auto;
      }

      .section {
        padding: 36px 0;
      }

      .section-grid {
        display: grid;
        grid-template-columns: 0.95fr 1.05fr;
        gap: 28px;
        align-items: start;
      }

      .section h3,
      .section h2 {
        font-family: Manrope, sans-serif;
        letter-spacing: -0.05em;
      }

      .section h2 {
        margin: 0;
        font-size: clamp(2rem, 4vw, 3rem);
      }

      .section p.lead {
        margin: 24px 0 0;
        color: var(--muted);
        line-height: 1.75;
        max-width: 620px;
      }

      .stack {
        display: grid;
        gap: 18px;
      }

      .feature-card,
      .step-card,
      .download-card {
        border-radius: 32px;
        background: rgba(255,255,255,0.78);
        padding: 28px;
        box-shadow: 0 20px 40px rgba(45, 51, 54, 0.03);
      }

      .feature-card h3,
      .step-card h3,
      .download-card h3 {
        margin: 0 0 12px;
        font-size: 1.2rem;
      }

      .feature-card p,
      .step-card p,
      .download-card p {
        margin: 0;
        color: var(--muted);
        line-height: 1.7;
      }

      .stats-band {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 18px;
        margin-top: 24px;
      }

      .stat {
        padding: 24px;
        border-radius: 28px;
        background: rgba(255,255,255,0.72);
      }

      .stat span {
        display: block;
        color: var(--muted);
        font-size: 0.75rem;
        letter-spacing: 0.14em;
        text-transform: uppercase;
        font-weight: 800;
      }

      .stat strong {
        display: block;
        margin-top: 12px;
        font-family: Manrope, sans-serif;
        font-size: 2rem;
        letter-spacing: -0.04em;
      }

      .download-band {
        margin-top: 24px;
        display: grid;
        grid-template-columns: 1.1fr 0.9fr;
        gap: 18px;
      }

      footer {
        padding: 56px 0 72px;
        color: var(--muted);
      }

      .footer-card {
        display: flex;
        justify-content: space-between;
        gap: 18px;
        align-items: center;
        border-radius: 32px;
        padding: 22px 24px;
        background: rgba(255,255,255,0.74);
      }

      .muted {
        color: var(--muted);
      }

      .mono {
        font-variant-numeric: tabular-nums;
      }

      @media (max-width: 980px) {
        .hero,
        .section-grid,
        .download-band {
          grid-template-columns: 1fr;
        }

        .hero-panel {
          min-height: 580px;
        }

        .stats-band {
          grid-template-columns: 1fr;
        }

        .footer-card {
          flex-direction: column;
          align-items: flex-start;
        }
      }

      @media (max-width: 720px) {
        .shell { width: min(100% - 20px, 1180px); }
        .topbar-inner { padding: 14px 0; }
        .nav { display: none; }
        .hero { padding-top: 28px; }
        .hero-panel { min-height: 520px; border-radius: 36px; }
        .phone { inset: 18px; padding: 18px; }
        .release-meta { grid-template-columns: 1fr; }
      }
    </style>
  </head>
  <body>
    <header class="topbar">
      <div class="shell topbar-inner">
        <a class="brand" href="/">
          <div class="brand-mark"></div>
          <span>HeadLog</span>
        </a>
        <nav class="nav">
          <a href="#features">Features</a>
          <a href="#how-it-works">How it works</a>
          <a href="#download">Download</a>
        </nav>
      </div>
    </header>

    <main class="shell">
      <section class="hero">
        <div class="hero-copy">
          <div class="eyebrow">Private release delivery + instant tracking</div>
          <h1>Track headaches instantly, without breaking the moment.</h1>
          <p>
            HeadLog is built for speed. One tap logs one event, repeated taps log repeated pain spikes,
            and deeper context stays optional. Clean, local-first, and fast enough to use when you least want friction.
          </p>
          <div class="hero-actions">
            <a class="button button-primary" id="download-cta" href="${defaultDownloadPath}">Download Stable APK</a>
            <a class="button button-secondary" href="#features">See features</a>
          </div>
        </div>

        <div class="hero-panel">
          <div class="hero-glow"></div>
          <div class="phone">
            <div class="phone-top">
              <div>
                <small>Journal</small>
                <h2>Overview</h2>
              </div>
              <div class="theme-pill">◐</div>
            </div>

            <div class="surface-card">
              <div class="segments">
                <span>Day</span>
                <span class="active">Week</span>
                <span>Month</span>
              </div>
            </div>

            <div class="release-card">
              <span class="muted" style="color: rgba(255,255,255,0.66); font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.16em;">Stable Android Release</span>
              <strong id="release-version">Loading…</strong>
              <p id="release-name" style="margin: 10px 0 0; color: rgba(255,255,255,0.75); line-height: 1.7;">
                Pulling the default stable APK metadata directly from the release worker.
              </p>
              <div class="release-meta">
                <div>
                  <span>APK size</span>
                  <b class="mono" id="release-size">--</b>
                </div>
                <div>
                  <span>Updated</span>
                  <b id="release-updated">--</b>
                </div>
              </div>
            </div>

            <div class="log-list">
              <div class="log-item">
                <span class="dot" style="background:#10b981;"></span>
                <div>
                  <strong>Light</strong>
                  <div class="muted">Rapid tap logging with zero debounce.</div>
                </div>
              </div>
              <div class="log-item">
                <span class="dot" style="background:#f59e0b;"></span>
                <div>
                  <strong>Context when you need it</strong>
                  <div class="muted">Intensity, causes, and notes stay optional.</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="section" id="features">
        <div class="section-grid">
          <div>
            <h2>Built for low-friction logging.</h2>
            <p class="lead">
              HeadLog strips symptom tracking down to the part that matters most: capturing the moment quickly,
              accurately, and without cognitive overhead.
            </p>
          </div>
          <div class="stack">
            <div class="feature-card">
              <h3>1-tap instant logging</h3>
              <p>Open the app and log immediately. No modal maze, no forced form, no debounce blocking rapid repeated taps.</p>
            </div>
            <div class="feature-card">
              <h3>Optional detail, not mandatory friction</h3>
              <p>Add intensity, possible causes, and extra context only when it helps. The fast path always stays fast.</p>
            </div>
            <div class="feature-card">
              <h3>Private and local-first</h3>
              <p>Your headache entries stay on device. The optional worker is only used for delivering APK builds, not your data.</p>
            </div>
          </div>
        </div>
      </section>

      <section class="section" id="how-it-works">
        <div class="section-grid">
          <div class="stack">
            <div class="step-card">
              <h3>1. Tap to log</h3>
              <p>Every tap creates a fresh entry instantly, even if you tap multiple times in quick succession.</p>
            </div>
            <div class="step-card">
              <h3>2. Add detail if needed</h3>
              <p>Open the composer for intensity, possible causes, and notes without slowing down the primary action.</p>
            </div>
            <div class="step-card">
              <h3>3. Review patterns over time</h3>
              <p>Use the daily overview, timeline, and calendar views to quickly understand when headaches cluster and what might be driving them.</p>
            </div>
          </div>
          <div>
            <h2>Simple enough to use in pain.</h2>
            <p class="lead">
              The app is designed around the reality that logging often happens during discomfort, not during calm analysis.
              That is why the interface stays minimal, fast, and forgiving.
            </p>
            <div class="stats-band">
              <div class="stat">
                <span>Offline-first</span>
                <strong>Local</strong>
              </div>
              <div class="stat">
                <span>Logging flow</span>
                <strong>1 Tap</strong>
              </div>
              <div class="stat">
                <span>Repeat input</span>
                <strong>No debounce</strong>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section class="section" id="download">
        <h2>Download the stable Android build.</h2>
        <p class="lead">
          The site reads the configured stable release metadata directly from the worker API, so version and APK size stay current automatically.
        </p>
        <div class="download-band">
          <div class="download-card">
            <h3>Stable release</h3>
            <p id="download-summary">Preparing current release metadata…</p>
            <div class="hero-actions" style="margin-top:24px;">
              <a class="button button-primary" id="download-button" href="${defaultDownloadPath}">Download APK</a>
              <a class="button button-secondary" id="meta-button" href="${defaultMetaPath}">View metadata</a>
            </div>
          </div>
          <div class="download-card">
            <h3>Release details</h3>
            <p><strong>Version:</strong> <span id="release-version-inline">--</span></p>
            <p style="margin-top:10px;"><strong>APK size:</strong> <span class="mono" id="release-size-inline">--</span></p>
            <p style="margin-top:10px;"><strong>Asset:</strong> <span id="release-asset-inline">--</span></p>
          </div>
        </div>
      </section>
    </main>

    <footer class="shell">
      <div class="footer-card">
        <div>
          <strong style="display:block; margin-bottom:8px;">HeadLog</strong>
          <span>Minimal headache tracking with fast local-first logging and modern release delivery.</span>
        </div>
        <div>
          <a class="muted" href="${defaultMetaPath}">Stable metadata</a>
        </div>
      </div>
    </footer>

    <script>
      const version = document.getElementById('release-version');
      const releaseName = document.getElementById('release-name');
      const releaseSize = document.getElementById('release-size');
      const releaseUpdated = document.getElementById('release-updated');
      const releaseVersionInline = document.getElementById('release-version-inline');
      const releaseSizeInline = document.getElementById('release-size-inline');
      const releaseAssetInline = document.getElementById('release-asset-inline');
      const downloadSummary = document.getElementById('download-summary');
      const downloadCta = document.getElementById('download-cta');
      const downloadButton = document.getElementById('download-button');
      const metaButton = document.getElementById('meta-button');

      async function loadReleaseMeta() {
        try {
          const response = await fetch('${defaultMetaPath}');
          if (!response.ok) throw new Error('Failed to load release metadata');
          const data = await response.json();

          version.textContent = data.tag || 'Stable';
          releaseName.textContent = data.name || 'Stable Android release ready to download.';
          releaseSize.textContent = data.sizeMb ? data.sizeMb + ' MB' : '--';
          releaseUpdated.textContent = data.updatedAt ? new Date(data.updatedAt).toLocaleDateString() : '--';
          releaseVersionInline.textContent = data.tag || '--';
          releaseSizeInline.textContent = data.sizeMb ? data.sizeMb + ' MB' : '--';
          releaseAssetInline.textContent = data.assetName || '--';
          downloadSummary.textContent = \`\${data.tag || 'Stable'} is ready. APK size: \${data.sizeMb || '--'} MB.\`;

          if (data.downloadPath) {
            downloadCta.href = data.downloadPath;
            downloadButton.href = data.downloadPath;
          }
          metaButton.href = data.requestedTag === 'latest' ? '/meta/latest' : '${defaultMetaPath}';
        } catch (error) {
          version.textContent = 'Unavailable';
          releaseName.textContent = 'Release metadata could not be loaded right now.';
          downloadSummary.textContent = 'Metadata unavailable. You can still try the default download endpoint.';
          console.error(error);
        }
      }

      loadReleaseMeta();
    </script>
  </body>
</html>`;
}

function resolveTag(pathname, defaultTag) {
  const trimmed = pathname
    .replace(/^\/meta/, "/download")
    .replace(/^\/download\/?/, "");

  if (!trimmed || trimmed === "stable") {
    return defaultTag || "latest";
  }

  return trimmed;
}

function buildDownloadPath(requestedTag, resolvedReleaseTag) {
  if (requestedTag === "latest") {
    return "/download/latest";
  }

  if (requestedTag && requestedTag !== resolvedReleaseTag) {
    return `/download/${requestedTag}`;
  }

  return "/download";
}

async function fetchRelease(tag, env) {
  const endpoint = tag === "latest"
    ? `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/releases/latest`
    : `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/releases/tags/${tag}`;

  const response = await fetch(endpoint, {
    headers: githubHeaders(env.GITHUB_TOKEN),
  });

  if (!response.ok) {
    throw new Error(
      `GitHub release lookup failed (${response.status}): ${await safeText(response)}`,
    );
  }

  return response.json();
}

function pickApkAsset(assets, requestedAssetName, defaultAssetName) {
  return assets.find((asset) => asset.name === requestedAssetName)
    || assets.find((asset) => asset.name === defaultAssetName)
    || assets.find((asset) => asset.name.endsWith(".apk"));
}

function githubHeaders(token, accept = "application/vnd.github+json") {
  return {
    authorization: `Bearer ${token}`,
    accept,
    "user-agent": "headlog-release-proxy",
    "x-github-api-version": "2022-11-28",
  };
}

async function safeText(response) {
  try {
    return await response.text();
  } catch {
    return "Unknown GitHub API error";
  }
}
