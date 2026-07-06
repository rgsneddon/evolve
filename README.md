# Evolve — Social Science Chronoflux Framework

**Web** · **Releases** (see this repository’s GitHub Pages site and Releases tab)
BITCOIN TALK [ANN] https://bitcointalk.org/index.php?topic=5587544.msg66906190#msg66906190
Evolve is a cross-platform app for analysing social and political scenarios using the **Chronoflux** hydrodynamic framework.

All core Chronoflux calculations run **locally** on your device. Optional **Grok construal** can fill blank σ / Iτ / Jμ / ω fields before each Calculate — behaviour depends on platform (see [Grok construal](#2-grok-construal-optional)).

The **Chronoflux Principia**, realised by **Roy D Herbert**, is the core mechanical foundation of the Evolve analysis engine (see [License](#license)).

---

## Quick start

### Windows (easiest)

Download the latest **Windows** zip from this repository’s **Releases** tab, extract, and run `evolve.exe`.

### Web

Live app: deploy with `scripts/deploy_web_github.ps1` (GitHub Pages on your fork).

### Android

Download the latest **Android APK** from this repository’s **Releases** tab and install on your device.

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

- Calibrated ~% headline with REGRESSIVE / PROGRESSIVE lean and continuum conclusion
- **How to read this conclusion** — explains the ~% headline, regressive/progressive momentum, σ and strain scores, registry filter (event class, region, horizon), and lists each historical `OR-xxxx` case used in the base rate

**Social Cohesion panel**

- Full PART ONE / TWO / THREE report
- Party-response refinement when a linked narrative relies on attributed quotes
- Calibrated headline % under `~XX/100` (not the raw THE CONTINUUM regressive/progressive split)
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

## Features

| Feature | What you get |
|---------|----------------|
| **Percent Chance** | Observational probability output for a posed question (ω) |
| **Social Cohesion Score** | Three-part cohesion report (PART ONE / TWO / THREE) with **five** establishment-facing agent actions |
| **Conclusion explainer** | Below each result: momentum, σ/continuum scores, registry filter, and bullet list of exact `OR-xxxx` cases used in calibration |
| **Synopsis export** | After Calculate: **PDF**, **Text (.md)**, **View in browser**, or **Copy to clipboard** — full MarkdownBin-style report including PART THREE actions |
| **Social narrative links** | Paste X, YouTube, Bluesky, Reddit, or Mastodon URLs in Social Cohesion mode — text fetched via Grok proxy for party-response scoring |
| **Web Grok heuristic** | GitHub Pages builds use `@evolve_web` in-browser construal — no local proxy, no X sign-in |
| **Android Grok** | Release APK includes `INTERNET` permission and loopback cleartext for the embedded proxy; Grok construal connects as `@evolve_mock` (or `@evolve_android` heuristic fallback) |

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

The web app cannot run a localhost proxy (browser security). Heuristic mode is the default on GitHub Pages deployments without `GROK_PROXY_URL`.

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
- Use a lowercase GitHub Pages path: `/evolve/` (not `/Evolve/`) when deploying under a user or org site.

---

## Project layout

```
lib/           Application source
assets/data/   Outcome registry (base rates)
scripts/       Tooling
tool/          Optional Grok proxy CLI
test/          Unit and widget tests
```

---

## License

Copyright (c) 2026 Evolve Chronoflux. All rights reserved.

The **Chronoflux Principia**, realised by **Roy D Herbert**, is a **core mechanical part** of the Evolve framework — the hydrodynamic constructs and analysis pipeline at the centre of the engine derive from and operate through that Principia. Evolve is a derivative computational implementation of that work.

Evolve and this Chronoflux implementation are **proprietary software** offered under a **dual licensing** model:

| Use | License |
|-----|---------|
| Personal, private, non-commercial use | [LICENSE](LICENSE) (proprietary grant) |
| Commercial use, redistribution, SaaS, or derivative products for sale | Separate **Commercial License** — contact [licensing@evolve-chronoflux.dev](mailto:licensing@evolve-chronoflux.dev) |

Third-party dependencies (Flutter packages, fonts, etc.) remain under their own licenses; see `NOTICES` in build outputs.
