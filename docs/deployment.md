# Netra — Deployment Guide

How to put Netra on a public URL for free, and what the honest limits are.

---

## 1. Read this first: why the backend can't be "fully cloud hosted for free"

Netra's runtime pipeline is **MATLAB** — that's a locked constraint (PS 26038 is
a MathWorks problem statement; staying on-platform is a judging factor).

MATLAB cannot run on any free hosting tier:

| Host | Why not |
|---|---|
| Vercel / Netlify / GitHub Pages | Static files + JS serverless only. No MATLAB. |
| Render / Railway / Fly free tier | ~512 MB RAM. MATLAB Runtime is 4–6 GB. |
| MATLAB Production Server | Paid MathWorks product. |
| Hugging Face Spaces | Python/Docker. Running MATLAB needs a license server. |

So we use a **split deployment**:

```
   Judge's browser
        │
        ├── static site ───────────►  Vercel (free, always on)
        │                             HTML/CSS/JS + baked pipeline snapshot
        │
        └── /api/* ────────────────►  Cloudflare Tunnel (free)
                                          │
                                          ▼
                                   your laptop
                                   MATLAB netraServer  ← the real pipeline
```

**Laptop on**  → live screening. Upload a fundus image, the real MATLAB
pipeline grades it in ~10 s, overlays and PDF come back.

**Laptop off** → the site still loads and shows **real pipeline output that was
computed earlier** (`web/data/snapshot.json`), with a badge reading
*"Cached pipeline output"*. Nothing is fabricated; live screening is disabled.

---

## 2. Run it locally (do this first)

One command:

```matlab
cd 'C:\Users\sharm\Desktop\SIH PROJECT\netra2.0\netra'
addpath(genpath('src')); addpath('app')
NetraApp
```

That starts the MATLAB backend **and** opens the netra_ui site in your browser.
One MATLAB process serves both, on one port:

```
http://localhost:8090/          the netra_ui site (web/)
http://localhost:8090/api/...   the MATLAB pipeline
```

Same origin, so there is no CORS to configure, no second server, and no Python
dependency. **Ctrl-C** in the MATLAB window stops it.

Bottom-right of the page should read **"MATLAB backend live"** in green.

### Check it works

| Where | Do this | Expect |
|---|---|---|
| Any page | look bottom-right | green "MATLAB backend live" |
| Login | doctor login `admin` / `netra2026` | lands on the doctor dashboard |
| Doctor dashboard | — | triage queue filled with real registry patients |
| Patient dashboard | click a scan button | file picker → pick `data/samples/003f0afdcd15.png` |
| after upload | — | Grade 2 Moderate, 31 MA / 22 HE, real overlays on the layer buttons |

Credentials are in `src/datalayer/checkAuth.m`:
`admin`/`netra2026` · `phc`/`phc2026` · `doctor`/`doctor2026`.

First screening after startup takes ~35 s (cold caches); after that ~10 s.

### The other two entry points

| Command | What it is |
|---|---|
| `NetraApp` | **the demo.** MATLAB backend + netra_ui in the browser. |
| `NetraAppNative` | the original single-window MATLAB UI (`uihtml`). No browser, no netra_ui. Offline fallback. |
| `netraServer(8090)` | backend only, no browser — use when driving it from Vercel via a tunnel. |

> Don't open the HTML files directly with `file://` — browsers block `fetch()`
> there and the app will look permanently offline. Always go through
> `http://localhost:8090`.

---

## 2b. Pulling frontend updates from the UI teammate

`netra_ui/` is a clone of the frontend repo (`karthickkr2426/netra`) that we
don't own. `web/` is what actually ships, and it is a **build output**:

```
web/  =  netra_ui/  +  js/config.js + js/api.js + js/netra-bridge.js + data/
```

Never hand-edit the UI inside `web/` — it gets overwritten. When the frontend
teammate pushes:

```matlab
cd netra_ui
!git pull
cd ..
syncUI          % rebuilds web/ and re-wires the MATLAB integration
```

`syncUI` copies the upstream UI over `web/`, preserves our four integration
paths, and re-injects the script tags in the right order (`config.js` + `api.js`
before the page's own scripts, `netra-bridge.js` after). It's idempotent —
running it twice changes nothing.

If you need to change the UI itself, edit it in `netra_ui/` (or ask the
frontend owner to) and re-run `syncUI`.

---

## 3. Refresh the offline snapshot

Re-run whenever the pipeline changes:

```matlab
exportSnapshot(6)      % runs the real pipeline on 6 sample images
```

Writes `web/data/snapshot.json` + `web/data/images/`. **Commit both** — this is
what the hosted site falls back to. Stop `netraServer` first so the two
processes don't write `netra_db.mat` at the same time.

---

## 4. Host the frontend free (Vercel)

Vercel's Hobby tier is free, no credit card, with HTTPS and a public URL.

```bash
npm i -g vercel
cd "C:/Users/sharm/Desktop/SIH PROJECT/netra2.0/netra"
vercel login
vercel --prod
```

`vercel.json` already sets `outputDirectory: "web"`, so it publishes the
`web/` folder. You get something like
`https://netra-xxxx.vercel.app`.

**Or via the dashboard:** push this repo to GitHub → vercel.com → *Add New
Project* → import the repo → framework **Other** → *Deploy*. It auto-redeploys
on every push.

### Free alternatives

| Host | Command / setup | Note |
|---|---|---|
| **Netlify** | `npx netlify deploy --prod --dir=web` | equivalent |
| **GitHub Pages** | push `web/` to `gh-pages` | no `cleanUrls`; use `.html` in links |
| **Cloudflare Pages** | connect repo, output dir `web` | same CDN as the tunnel |

---

## 5. Expose the MATLAB backend free (Cloudflare Tunnel)

Gives your laptop a public HTTPS URL. No account, no card, no port forwarding.

**Install** — <https://github.com/cloudflare/cloudflared/releases> →
`cloudflared-windows-amd64.exe`, rename to `cloudflared.exe`, put it on PATH.
(Or `winget install --id Cloudflare.cloudflared`.)

**Run** (with `netraServer(8090)` already running):

```bash
cloudflared tunnel --url http://localhost:8090
```

It prints:

```
+---------------------------------------------------------+
|  https://random-words-here.trycloudflare.com             |
+---------------------------------------------------------+
```

**Point the site at it** — edit `web/js/config.js`:

```js
window.NETRA_CONFIG = {
  apiBase: 'https://random-words-here.trycloudflare.com',
  ...
};
```

Then redeploy: `vercel --prod`.

> `apiBase` defaults to `''`, meaning *same origin* — correct for local use,
> where MATLAB serves the site itself. Only set it when the site is hosted
> somewhere else (Vercel) and the backend is reached through a tunnel.
> **Set it back to `''` for local runs**, or `NetraApp` will point at a dead
> tunnel instead of itself.

> The quick-tunnel URL **changes every restart**. For a fixed URL, create a
> named tunnel on a free Cloudflare account:
> `cloudflared tunnel login` → `cloudflared tunnel create netra` →
> `cloudflared tunnel route dns netra netra.yourdomain.com`.
>
> For the demo, simplest is: start the tunnel, paste the URL into
> `config.js`, `vercel --prod`. Takes about a minute.

**ngrok** works the same way if you prefer: `ngrok http 8090`.

---

## 6. Demo-day checklist

1. `exportSnapshot(6)` → commit `web/data/` → `vercel --prod`
   *(so the public URL is good even if the laptop dies)*
2. On the day: `netraServer(8090)` → wait for "listening"
3. `cloudflared tunnel --url http://localhost:8090` → copy the URL
4. Paste into `web/js/config.js` → `vercel --prod`
5. Open the public URL → confirm the badge says **"MATLAB backend live"**
6. Run one screening end-to-end before anyone is watching

**Keep a local fallback ready.** If conference wifi blocks the tunnel, run the
site at `localhost:5500` against `localhost:8090` — everything works offline
except the public URL.

---

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Badge stuck on "Cached pipeline output" | backend unreachable | is `netraServer` running? does `apiBase` match the tunnel URL exactly (no trailing `/`)? |
| CORS error in console | `apiBase` host ≠ the URL you opened | the server already sends `Access-Control-Allow-Origin: *`; re-check `apiBase` |
| `Address already in use` | port taken | `netraServer(9000)` and update `config.js` |
| Upload returns 500 | pipeline threw | check the MATLAB console — it prints the real error |
| Images 404 offline | snapshot not committed | re-run `exportSnapshot`, commit `web/data/` |
| Site looks dead on `file://` | `fetch()` blocked | serve over `http://localhost` |

---

## 8. What this is not

This is a **hackathon prototype**, not a certified medical device. Grading
currently runs on a transparent **classical rules baseline** — the trained
ResNet-50 plugs into the same interface once `dr_grader.onnx` re-exports
cleanly. Don't claim >90% sensitivity from the current numbers. See
`docs/demo_script.md` §PART C for what to say and what not to.
