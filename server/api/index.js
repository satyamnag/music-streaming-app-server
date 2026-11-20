// Serverless entrypoint (Vercel). Every request is handed to this handler and
// the Express app in app.js does the routing, so the route table, the auth
// guards and the SRT/lyrics write paths are byte-identical to the Render
// deployment. The only per-host difference is how the process starts:
//
//   Render    server.js  -> bootstrap(), then app.listen(port)
//   Vercel    this file  -> bootstrap(), then app(req, res) per request
//
// bootstrap() is memoised inside app.js, so the first request on a cold
// instance loads the Vault/AWS secrets and the rest reuse them.
//
// Deliberately plain: no framework adapter, no body parsing of its own. Vercel
// parses the body and hands it over exactly as Node's http server would, which
// is what the multer and Razorpay raw-body handlers already expect.
import app, { bootstrap } from '../app.js'

export default async function handler(req, res) {
  await bootstrap()
  return app(req, res)
}
