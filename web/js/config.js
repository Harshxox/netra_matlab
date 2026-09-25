/**
 * Netra runtime config.
 *
 * apiBase -> where the MATLAB backend (netraServer) is reachable.
 *
 *   ''  (empty, the default)
 *       Same origin as the page. Correct when MATLAB is serving the site
 *       itself - i.e. you ran NetraApp, or netraServer, and opened
 *       http://localhost:8090. No CORS, nothing to configure.
 *
 *   'https://<something>.trycloudflare.com'
 *       Needed only when the site is hosted somewhere else (Vercel) and the
 *       MATLAB backend is reached through a tunnel. Paste the tunnel URL
 *       here, commit, redeploy. No trailing slash.
 *
 * If the backend can't be reached, the site falls back to the pre-computed
 * pipeline snapshot in web/data/ and labels itself "cached".
 *
 * This is the ONLY file that changes between environments.
 */
window.NETRA_CONFIG = {
  apiBase: '',

  // How long to wait for the backend before deciding it's offline (ms).
  probeTimeout: 4000,

  // Where the baked "real pipeline output" snapshot lives.
  snapshotUrl: 'data/snapshot.json'
};
