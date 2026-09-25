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
 *   'https://linguist-rover-coaster.ngrok-free.dev'   <- current
 *       The site is hosted on Vercel and reaches the MATLAB backend through
 *       an ngrok tunnel. This domain is STATIC - it survives reboots, so it
 *       normally never needs changing. Start the tunnel with:
 *
 *         ngrok http --domain=linguist-rover-coaster.ngrok-free.dev 8090
 *
 *       No trailing slash on apiBase.
 *
 * If the backend can't be reached, the site falls back to the pre-computed
 * pipeline snapshot in web/data/ and labels itself "cached".
 *
 * This is the ONLY file that changes between environments.
 */
window.NETRA_CONFIG = {
  apiBase: 'https://linguist-rover-coaster.ngrok-free.dev',

  // How long to wait for the backend before deciding it's offline (ms).
  probeTimeout: 4000,

  // Where the baked "real pipeline output" snapshot lives.
  snapshotUrl: 'data/snapshot.json'
};
