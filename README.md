# Evolve — Social Science Chronoflux Framework

**Version 1.0.7** — [Live web app](https://rgsneddon.github.io/evolve/) · [GitHub Releases](https://github.com/rgsneddon/evolve/releases)

Evolve is a cross-platform app for analysing social and political scenarios using the **Chronoflux** hydrodynamic framework. It produces:

- **Percent Chance** — an @grok-style observational probability reply for a posed question (ω)
- **Social Cohesion Score (SCS)** — a three-part cohesion report (PART ONE / TWO / THREE) with **five** establishment-facing agent actions
- **How to read this conclusion** — an explainer under each result showing construal data points and matched historical registry cases (`OR-xxxx`)
- **Complete synopsis export** — PDF, Markdown text, in-browser view, or clipboard after each successful run

All core Chronoflux calculations run **locally** on your device. Optional **Grok construal** can fill blank σ / Iτ / Jμ / ω fields before each Calculate — behaviour depends on platform (see [Grok construal](#2-grok-construal-optional)).

The **Chronoflux Principia**, realised by **Roy D Herbert**, is the core mechanical foundation of the Evolve analysis engine (see [License](#license)).

### What's new in 1.0.7

| Change | What you get |
|--------|----------------|
| **Sentience/salience reverted** | Experimental σ/Iτ awareness reaction layer removed from the hydrodynamic core; PART TWO again cites scenario **weight % salience** on σ and Iτ |
| **Retained from 1.0.6** | Social narrative links and calibrated cohesion headline % under `~XX/100` unchanged |

### What's new in 1.0.6

| Feature | What you get |
|---------|----------------|
| **Social narrative links** | Paste X, YouTube, Bluesky, Reddit, or Mastodon URLs in Social Cohesion mode — text fetched via Grok proxy (oEmbed / syndication) for party-response scoring |
| **Cohesion headline %** | SCS panel shows calibrated percent-chance under `~XX/100` (not the raw THE CONTINUUM regressive/progressive split) |

### Core features (1.0+)

| Feature | What you get |
|---------|----------------|
| **Conclusion explainer** | Below each Percent Chance or SCS conclusion: momentum, σ/continuum scores, registry filter, and bullet list of exact `OR-xxxx` cases used in calibration |
| **PART THREE (5 actions)** | Five progressive actions for the accountable establishment figurehead — each with a data-driven rationale (ω/σ/Iτ/Jμ weights, continuum lean, registry base rate, lever projections) |
| **Synopsis export** | After Calculate: **PDF**, **Text (.md)**, **View in browser**, or **Copy to clipboard** — full MarkdownBin-style report including PART THREE actions |
| **Web Grok heuristic** | [GitHub Pages](https://rgsneddon.github.io/evolve/) uses `@evolve_web` in-browser construal — no local proxy, no X sign-in, no “proxy not found” error |
| **Android Grok** | Release APK includes `INTERNET` permission and loopback cleartext for the embedded proxy; Grok construal connects as `@evolve_mock` (or `@evolve_android` heuristic fallback) |

---

## Quick start

### Windows (easiest)

1. Run the release build:

   ```
   build\windows\x64\runner\Release\evolve.exe
   ```

2. Or double-click the **Evolve** desktop shortcut if you created one.

### Web

Live app: [https://rgsneddon.github.io/evolve/](https://rgsneddon.github.io/evolve/)

Or open `build\web\index.html` via a local server after building. To publish updates, deploy the contents of `build\web` to GitHub Pages (see [Deploying the web build](#deploying-the-web-build)).

### Android

Install:

```
build\app\outputs\flutter-apk\app-release.apk
```

---

## How to use Evolve

### 1. Select region and language

At the top of the app:

1. **Region** — choose the country or area you want to analyse. This scopes all observations, base rates, and construct language to that region (not Global unless you pick Global).
2. **Language** — choose the output language (English, Español, Français, Deutsch, and others).

The amber bar reminds you to select the region before you pose your question.

### 2. Grok construal (optional)

Below region and language is a second amber bar: **GROK CONSTRUE**.

| Setting | What happens |
|--------|----------------|
| **Don't use** | Fully offline. Local Chronoflux only. No X account needed. |
| **Use** | Grok construal fills **blank** σ / Iτ / Jμ / ω fields before each Calculate. Fields you already typed are never overwritten. |

Grok construal works differently on each platform:

| Platform | **Use** connects as | How blank fields are filled |
|----------|---------------------|-----------------------------|
| **Windows / Android** | `@your_username` (X OAuth) or `@evolve_mock` (dev) | Built-in Grok proxy; live Grok when **X Premium** and credentials are configured |
| **Web** | `@evolve_web` | **Web heuristic mode** — region-aware suggestions in the browser (no X sign-in, no local proxy) |

**Desktop / Android:** slide to **Use** — the embedded proxy starts automatically; sign in with X when prompted. No manual scripts.

**Web (including GitHub Pages):** slide to **Use** — connects immediately as `@evolve_web` in heuristic mode. No proxy setup, no X sign-in, and no “Grok proxy not found” message. Chronoflux still runs locally. For **live** X Premium Grok on the web, host a remote Grok proxy and rebuild with:

```powershell
flutter build web --release --base-href /evolve/ --dart-define=GROK_PROXY_URL=https://your-proxy.example.com
```

When connected, the bar shows e.g. `Connected @your_username` (desktop) or `Connected @evolve_web` (web heuristic).

### 3. Choose analysis mode

| Mode | Best for |
|------|----------|
| **Percent Chance** | “What is the chance of…?” — probability-style Chronoflux output |
| **Social Cohesion Score** | Narratives, disputes, cohesion trajectories — full SCS report |

### 4. Enter your scenario

**Required:** **POSE YOUR QUESTION HERE** — your base scenario question (ω). Example:

> What is the chance of sporadic civil unrest near-term?

**Optional construct fields** (leave blank for observational inference, or fill to bias the analysis):

| Field | Symbol | Role |
|-------|--------|------|
| Vortex | ω | Circulation / focal tension around the question |
| Shear | σ | Directional bias, polarisation, narrative shear |
| Resistance | Iτ | Institutional or social resistance |
| Flow | Jμ | Trust transport, cohesion flow |

**Social Cohesion mode only:**

- **Narrative link** — paste a URL (news article, X post, YouTube, Bluesky, Reddit, Mastodon, etc.) and fetch text into the scenario via the Grok proxy.
- If the narrative relies on **attributed party responses**, Evolve scores each quote individually and blends them into the overall SCS.

### 5. Calculate

Tap **Calculate percent chance** or **Calculate social cohesion score**.

The pipeline runs:

1. **PART ONE** — core Chronoflux constructs and continuum
2. **PART TWO** — broader political continuum integration (refined SCS where applicable)
3. **PART THREE** — **five** recommended actions for the accountable establishment figurehead (mayor, minister, agency lead, etc.)

With **Grok construal on**, Grok suggestions are applied to empty fields first, then the same local pipeline runs.

### 6. Read and export results

**Percent Chance panel**

- @grok-style reply with continuum conclusion
- **How to read this conclusion** — explains the ~% headline, regressive/progressive momentum, σ and strain scores, registry filter (event class, region, horizon), and lists each historical `OR-xxxx` case used in the base rate

**Social Cohesion panel**

- Full PART ONE / TWO / THREE report
- Party-response refinement when a linked narrative relies on attributed quotes
- Same **How to read this conclusion** explainer (refined SCS delta, continuum split, lever projections)

**PART THREE actions** (both modes)

- Five numbered actions with per-action rationales grounded in Chronoflux calculations
- Target SCS or PROGRESSIVE transport shift for the detected agent
- Copy all actions with the panel copy button

**Export complete synopsis** (below results)

| Button | Output |
|--------|--------|
| **PDF** | Download a formatted synopsis document |
| **Text (.md)** | Save a Markdown file (MarkdownBin-compatible) |
| **View in browser** | Open the full report in an in-app browser viewer |
| **Copy to clipboard** | Paste the complete synopsis anywhere |

The synopsis includes your posed question, region, mode, full analysis text, refined scores, and all five PART THREE actions.

### 7. License & attribution

Scroll to the bottom of the app and expand **License & Chronoflux attribution** for the Roy D Herbert / Chronoflux Principia notice and a link to the full [LICENSE](LICENSE) text.

---

## The five constructs

Chronoflux uses five hydrodynamic constructs:

| Symbol | Name | Meaning (short) |
|--------|------|-----------------|
| ρt | Continuum | Baseline social–political continuum |
| Jμ | Flow | Trust and cohesion transport |
| σ | Shear | Bias layers, polarisation |
| Iτ | Resistance | Institutional / cultural resistance |
| ω | Vortex | Question-anchored circulation |

Weights are ascertained from your inputs (and Grok suggestions when enabled), then normalised before the hydrodynamic core runs.

---

## Building from source

Requires [Flutter](https://docs.flutter.dev/get-started/install) (SDK ≥ 3.2).

```powershell
cd evolve
flutter pub get
flutter test
```

**All platforms (Windows host):**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_all.ps1
```

Outputs:

| Platform | Path |
|----------|------|
| Web | `build\web\` |
| Windows | `build\windows\x64\runner\Release\evolve.exe` |
| Android | `build\app\outputs\flutter-apk\app-release.apk` |

Close a running `evolve.exe` before rebuilding Windows, or the linker may fail because the file is locked.

**Web only, with GitHub Pages base path** (repo name must match exactly — lowercase `Evolve`):

```powershell
flutter build web --release --base-href /evolve/
```

Optional remote Grok proxy for web (live X OAuth instead of heuristic mode):

```powershell
flutter build web --release --base-href /evolve/ --dart-define=GROK_PROXY_URL=https://your-proxy.example.com
```

Or use the deploy helper (builds, checks `assets/` + `canvaskit/` + `icons/`, copies `LICENSE`, creates a zip):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_web_github.ps1
```

---

## Deploying the web build

Upload **everything inside** `build\web\` to the GitHub Pages repo root (not the full Flutter source tree).

Live site: [https://rgsneddon.github.io/evolve/](https://rgsneddon.github.io/evolve/)

1. Run `.\scripts\deploy_web_github.ps1` (or build with `--base-href /evolve/` as above).
2. Open [rgsneddon/Evolve](https://github.com/rgsneddon/Evolve) and upload **all** files **and** folders from `build\web\`:
   - **Required folders:** `assets/`, `canvaskit/`, `icons/` (a blank page usually means one of these is missing).
   - **Required files:** `index.html`, `main.dart.js`, `flutter_bootstrap.js`, etc.
3. Confirm `index.html` contains `<base href="/evolve/">` — must match the repo name **exactly** (lowercase).
4. **Settings → Pages →** deploy from `main` branch, `/ (root)`.
5. After 1–2 minutes, verify [canvaskit.js](https://rgsneddon.github.io/evolve/canvaskit/canvaskit.js) loads (HTTP 200, not 404).

If you only upload loose files (`index.html`, `main.dart.js`, …) without the three folders, the page stays blank.

---

## Grok / X configuration (production)

### Windows / Android (embedded proxy)

By default, without credentials, the desktop app uses **mock Premium** for development (connected as `@evolve_mock`). The embedded proxy starts automatically when you slide Grok construal to **Use**.

For live X OAuth and Grok construal, set environment variables before launching:

| Variable | Purpose |
|----------|---------|
| `X_CLIENT_ID` | X API OAuth client ID |
| `X_CLIENT_SECRET` | Optional OAuth secret |
| `XAI_API_KEY` | Live Grok construal via xAI (otherwise heuristic fallback) |

Optional standalone proxy (debug only):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start_grok_proxy.ps1
```

### Web

| Mode | When | How |
|------|------|-----|
| **Heuristic** (default) | No `GROK_PROXY_URL` at build time | Slide **Use** → `@evolve_web`; blank fields filled in-browser before Calculate |
| **Live Grok** | `GROK_PROXY_URL` points to a hosted proxy with CORS | Same OAuth flow as desktop, via your remote proxy |

The web app cannot run a localhost proxy (browser security). Heuristic mode is the default on [rgsneddon.github.io/Evolve](https://rgsneddon.github.io/evolve/).

---

## Tips

- Expand **How to read this conclusion** under your result to see which registry cases (`OR-xxxx`) drove the calibrated outcome.
- Use **Export complete synopsis** → **PDF** or **Text (.md)** to archive or share a full run; **View in browser** for a quick readable layout.
- PART THREE lists **five** actions — read the grey rationale line under each for the ω/σ/Iτ/Jμ or continuum data behind it.
- Change **region** after entering a question only when you want that region to re-scope the scenario; the example question updates when the posed field is empty or still the old regional example.
- Switching **Percent Chance ↔ Social Cohesion** saves your current tab’s input and restores the other tab if you had posed a question there before.
- Leave bias fields blank to let the engine infer observational values relative to your ω question and selected region.
- **Don't use** Grok for reproducible, fully local analysis with no network dependency.
- On **web**, Grok heuristic mode (`@evolve_web`) needs no X account; use **Windows/Android** for live Premium Grok.
- After deploying to GitHub Pages, always use the lowercase URL: `https://rgsneddon.github.io/evolve/` (not `/Evolve/`).

---

## Project layout

```
lib/           Application source
assets/data/   Outcome registry (base rates)
scripts/       Build and tooling (build_all.ps1, build.ps1)
tool/          Optional Grok proxy CLI
test/          Unit and widget tests
build/         Release outputs (after build)
```

---

## License

Copyright (c) 2026 rgsneddon. All rights reserved.

The **Chronoflux Principia**, realised by **Roy D Herbert**, is a **core mechanical part** of the Evolve framework — the hydrodynamic constructs and analysis pipeline at the centre of the engine derive from and operate through that Principia. Evolve is a derivative computational implementation of that work.

Evolve and this Chronoflux implementation are **proprietary software** offered under a **dual licensing** model:

| Use | License |
|-----|---------|
| Personal, private, non-commercial use | [LICENSE](LICENSE) (proprietary grant) |
| Commercial use, redistribution, SaaS, or derivative products for sale | Separate **Commercial License** — contact [ra5kul@protonmail.com](mailto:ra5kul@protonmail.com) |

Third-party dependencies (Flutter packages, fonts, etc.) remain under their own licenses; see `NOTICES` in build outputs.