// Long-lived host entrypoint (Render today). Unchanged behaviour: load the
// secrets, initialise the clients, then listen on PORT. The application itself
// lives in app.js so the same code can also run as a serverless function.
import app, { bootstrap, startupSummary } from './app.js'

const port = process.env.PORT || 3000

async function start() {
  await bootstrap()
  const server = app.listen(port, () => {
    console.log(`Sangeet Supabase server running on port ${port} - v3`)
    console.log(startupSummary())
    // Expose the bound port (PORT=0 lets the OS choose) so integration tests
    // can address the server without hard-coding one.
    global.__PARTNER_TEST_PORT = server.address().port
    global.__SERVER_PORT = server.address().port
  })
}

start().catch((err) => {
  console.error('[startup] failed:', err)
  process.exit(1)
})
