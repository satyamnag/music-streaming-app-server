import { createClient } from '@supabase/supabase-js'
import express from 'express'
import cors from 'cors'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'
import crypto from 'crypto'
import dotenv from 'dotenv'
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3'
import QRCode from 'qrcode'
import { rateLimit } from 'express-rate-limit'

dotenv.config()

const __dirname = path.dirname(fileURLToPath(import.meta.url))

function trackToJson(t, req) {
  const artists = (t.artist_names || []).map((name) => ({
    id: name.toLowerCase().replace(/\s+/g, '-'),
    name,
    externalUri: '',
    images: null,
  }))
  return {
    id: t.id,
    name: t.title,
    externalUri: `${req.protocol}://${req.get('host')}/stream/${t.id}`,
    artists,
    status: t.status || 'free',
    language: t.language || null,
    lyrics: t.lyrics || null,
    synced_lyrics: t.synced_lyrics || null,
    album: {
      id: `album-${t.id}`,
      name: t.title,
      externalUri: '',
      artists,
      images: t.thumbnail ? [{ url: t.thumbnail, width: 300, height: 300 }] : [],
      albumType: 'single',
      releaseDate: null,
    },
    durationMs: (t.duration || 0) * 1000,
    isrc: '',
    explicit: false,
  }
}

const DEFAULT_USER = { id: 'supabase', name: 'Supabase', images: [], externalUri: '' }

const PLAYLIST_ID = 'supabase-all-tracks'

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
    global: {
      headers: { 'X-Client-Info': 'sangeet-supabase-server@1.0.0' },
    },
  }
)

// ------------------------------------------------------------------
// Secrets from Supabase Vault (encrypted at rest).
//
// SUPABASE_URL and SUPABASE_SERVICE_KEY are the BOOTSTRAP credentials and
// must stay in the deployment env (they are what connects to the vault).
// Every other risky credential (R2 keys, ADMIN_TOKEN, webhook secrets) is
// loaded from vault.secrets via the public.get_secret RPC (service_role
// only — the anon/app key cannot decrypt them).
//
// Each value falls back to process.env so local dev without a vault entry
// keeps working, and a vault value always wins once present.
// ------------------------------------------------------------------
const secrets = {
  admin_token: process.env.ADMIN_TOKEN || '',
  r2_account_id: process.env.R2_ACCOUNT_ID || '',
  r2_access_key_id: process.env.R2_ACCESS_KEY_ID || '',
  r2_secret_access_key: process.env.R2_SECRET_ACCESS_KEY || '',
  superwall_webhook_secret: process.env.SUPERWALL_WEBHOOK_SECRET || '',
}

const VAULT_SECRET_KEYS = [
  'admin_token',
  'r2_account_id',
  'r2_access_key_id',
  'r2_secret_access_key',
  'superwall_webhook_secret',
]

// Loads each secret from the vault (overriding the env fallback when a
// vault value exists). Runs once at startup before the server listens.
async function loadSecretsFromVault() {
  for (const key of VAULT_SECRET_KEYS) {
    try {
      const { data, error } = await supabase.rpc('get_secret', { p_name: key })
      if (error) {
        console.warn(`[secrets] vault read failed for ${key}: ${error.message}`)
        continue
      }
      if (data) {
        secrets[key] = data
        console.log(`[secrets] ${key} loaded from vault`)
      }
    } catch (err) {
      console.warn(`[secrets] vault error for ${key}: ${err.message}`)
    }
  }
}

const app = express()
app.set('trust proxy', 1)
app.use(cors())

// ------------------------------------------------------------------
// Referral / Affiliate program
// ------------------------------------------------------------------
//
// Trust model (see migrations/003_referrals.sql):
//  - Referral codes and attribution are created by the app via the local
//    Dart server calling SECURITY DEFINER RPCs (get_or_create_referral_code,
//    record_referral_attribution, get_referral_summary). Those RPCs only
//    allow a user to create/read their OWN code and to record the
//    "new user signed up with this code" attribution once.
//  - Commission is credited EXCLUSIVELY here, from Superwall webhooks that
//    have passed Svix HMAC verification. The app can never self-credit.
//
// Commission percentages are read from the `commission_rates` table so the
// business model can change without a release. Payouts are tracked as
// `status = 'pending'` (track-first); no money moves in this server.

// --- Superwall webhook (raw body required for Svix verification) ---
// Must be parsed as raw BEFORE the global express.json() so the HMAC
// signature is computed over the exact bytes Superwall sent.
app.post('/api/superwall/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const payload = req.body
  const headers = {
    'svix-id': req.headers['svix-id'],
    'svix-timestamp': req.headers['svix-timestamp'],
    'svix-signature': req.headers['svix-signature'],
  }
  const secret = secrets.superwall_webhook_secret

  try {
    if (!secret) {
      console.error('[webhook] SUPERWALL_WEBHOOK_SECRET not configured')
      return res.status(503).json({ error: 'webhook not configured' })
    }
    if (!payload || !headers['svix-id'] || !headers['svix-timestamp'] || !headers['svix-signature']) {
      return res.status(400).json({ error: 'missing webhook headers or body' })
    }
    if (!verifySvixWebhook(payload, headers, secret)) {
      return res.status(400).json({ error: 'webhook verification failed' })
    }

    const event = JSON.parse(payload.toString())
    await handleSuperwallEvent(event)
    res.json({ status: 'ok' })
  } catch (err) {
    console.error('[webhook] error:', err)
    res.status(400).json({ error: 'webhook processing failed' })
  }
})

// --- Referral code + summary (for the admin/referrer view) ---
app.get('/api/referrals/:userId/code', async (req, res, next) => {
  try {
    const { data, error } = await supabase.rpc('get_or_create_referral_code', { p_user_id: req.params.userId })
    if (error) return res.status(500).json({ error: error.message })
    res.json({ code: data })
  } catch (err) { next(err) }
})

app.get('/api/referrals/:userId/summary', async (req, res, next) => {
  try {
    const { data, error } = await supabase.rpc('get_referral_summary', { p_user_id: req.params.userId })
    if (error) return res.status(500).json({ error: error.message })
    res.json(Array.isArray(data) && data.length ? data[0] : { code: null, referral_count: 0, pending_amount: 0, credited_amount: 0, total_amount: 0 })
  } catch (err) { next(err) }
})

// The app's local server uses the RPC endpoints directly; expose a small
// HTTP alias so non-Dart clients can attribute too (optional).
app.post('/api/referrals/attribute', async (req, res, next) => {
  try {
    const { code, referredUserId } = req.body || {}
    if (!code || !referredUserId) return res.status(400).json({ error: 'code and referredUserId required' })
    const { data, error } = await supabase.rpc('record_referral_attribution', {
      p_code: code,
      p_referred_user_id: referredUserId,
    })
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: data })
  } catch (err) { next(err) }
})

// Verifies a Superwall (Svix-delivered) webhook using the signing secret.
// Implements the official manual verification algorithm (Superwall docs:
// "Verify Webhook Requests"): HMAC-SHA256 over `${svix-id}.${timestamp}.${body}`.
function verifySvixWebhook(payload, headers, secret) {
  const msgId = headers['svix-id']
  const msgTimestamp = headers['svix-timestamp']
  const msgSignature = headers['svix-signature']

  const timestamp = parseInt(msgTimestamp, 10)
  const now = Math.floor(Date.now() / 1000)
  if (Number.isNaN(timestamp) || now - timestamp > 300) {
    return false // reject replay / stale events (>5 min)
  }

  const signedContent = `${msgId}.${msgTimestamp}.${payload.toString()}`
  const secretBytes = Buffer.from(secret.split('_')[1] || secret, 'base64')
  const signature = crypto
    .createHmac('sha256', secretBytes)
    .update(signedContent)
    .digest('base64')

  const expected = `v1,${signature}`
  const passed = (msgSignature || '').split(' ')
  return passed.some((sig) => {
    try {
      return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))
    } catch {
      return false
    }
  })
}

// Handles a verified Superwall subscription event and credits a commission
// when a referred user (coupon affiliate first, then in-app referral)
// makes a qualifying purchase.
async function handleSuperwallEvent(event) {
  const data = event?.data
  if (!data) return

  const name = data.name
  const store = data.store
  const environment = data.environment

  // Only production Google Play purchases count. Never credit trials, intro
  // offers, cancellations, refunds (negative price) or billing issues.
  if (environment === 'SANDBOX') return
  if (store !== 'PLAY_STORE' && store !== 'STRIPE') return
  if (name !== 'initial_purchase' && name !== 'renewal' && name !== 'non_renewing_purchase') return
  if (data.price === undefined || Number(data.price) <= 0) return
  if (data.periodType === 'TRIAL' || data.periodType === 'INTRO') return

  const referredUserId = data.originalAppUserId || data.appUserId
  const productId = data.productId
  const sourceEventId = data.id
  if (!referredUserId || !productId || !sourceEventId) return

  // Look up the commission rate for this plan (server-side, authoritative).
  const { data: rateRows, error: rateError } = await supabase
    .from('commission_rates')
    .select('rate_percent')
    .eq('product_id', productId)
    .maybeSingle()
  if (rateError || !rateRows) {
    console.log(`[webhook] no commission rate for product ${productId} — skipping`)
    return
  }

  // Amount in INR as billed. Webhook `price` is USD-normalized; the store
  // price in the user's currency is the source of truth for a ₹-priced app.
  const planPrice = Number(data.priceInPurchasedCurrency ?? data.price)

  // 1) Try the coupon affiliate program first. If the purchaser redeemed an
  //    affiliate coupon code in-app, the affiliate earns the commission.
  //    `credit_affiliate_commission` returns false when there is no coupon
  //    attribution for this user, in which case we fall back to the in-app
  //    referral program below.
  const { data: affiliateOk, error: affiliateError } = await supabase.rpc(
    'credit_affiliate_commission',
    {
      p_purchaser_user_id: referredUserId,
      p_product_id: productId,
      p_plan_price: planPrice,
      p_rate_percent: Number(rateRows.rate_percent),
      p_source_event_id: sourceEventId,
    }
  )
  if (affiliateError) {
    console.error('[webhook] credit_affiliate_commission failed:', affiliateError.message)
  } else if (affiliateOk) {
    console.log(`[webhook] affiliate commission credited for ${referredUserId} (${productId}): ok=${affiliateOk}`)
    return
  }

  // 2) Fall back to the in-app referral program.
  const { data: ok, error } = await supabase.rpc('credit_referral_commission', {
    p_referred_user_id: referredUserId,
    p_product_id: productId,
    p_plan_price: planPrice,
    p_rate_percent: Number(rateRows.rate_percent),
    p_source_event_id: sourceEventId,
  })
  if (error) {
    console.error('[webhook] credit_referral_commission failed:', error.message)
  } else {
    console.log(`[webhook] commission credited for ${referredUserId} (${productId}): ok=${ok}`)
  }
}

app.use(express.json())

function escapePostgrestValue(value) {
  // PostgREST reserved characters (, . ( )) in values must be double-quoted
  // https://postgrest.org/en/stable/api.html#reserved-characters
  if (/[,()]/.test(value)) {
    return `"${value.replace(/"/g, '""')}"`
  }
  return value
}

app.get('/tracks', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .order('created_at', { ascending: true })
      .limit(100)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Fetch failed' })
    }

    const items = data.map((t) => trackToJson(t, req))
    res.json({ items, limit: 100, nextOffset: null, total: items.length, hasMore: false })
  } catch (err) {
    next(err)
  }
})

app.get('/search', async (req, res, next) => {
  try {
    const q = (req.query.q || '').trim()
    const allMode = req.query.all === 'true'
    const tracksMode = req.query.tracks === 'true'
    const albumsMode = req.query.albums === 'true'
    const artistsMode = req.query.artists === 'true'
    const playlistsMode = req.query.playlists === 'true'

    if (!q && !allMode) return res.json([])

    let query = supabase.from('tracks').select('*').limit(30)

    if (q) {
      const pattern = escapePostgrestValue(`%${q}%`)
      const orConditions = [
        `title.ilike.${pattern}`,
        `artist_names_text.ilike.${pattern}`,
      ]
      query = query.or(orConditions.join(','))
    }

    const { data, error } = await query

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Search failed' })
    }

    // Audio-source match format (used by matches())
    const matchItems = data.map((t) => ({
      id: t.id,
      title: t.title,
      artists: t.artist_names,
      duration: t.duration * 1000000,
      thumbnail: t.thumbnail || null,
      externalUri: `${req.protocol}://${req.get('host')}/stream/${t.id}`,
    }))

    // Full track format (used by metadata search)
    const fullTracks = data.map((t) => trackToJson(t, req))

    if (allMode) {
      return res.json({
        tracks: fullTracks,
        albums: [],
        artists: [],
        playlists: [],
      })
    }

    if (tracksMode) {
      return res.json({ items: fullTracks, limit: 30, nextOffset: null, total: fullTracks.length, hasMore: false })
    }

    if (albumsMode || artistsMode || playlistsMode) {
      return res.json({ items: [], limit: 30, nextOffset: null, total: 0, hasMore: false })
    }

    res.json(matchItems)
  } catch (err) {
    next(err)
  }
})

app.get('/stream/:id', async (req, res, next) => {
  try {
    const { data: track, error } = await supabase
      .from('tracks')
      .select('storage_path')
      .eq('id', req.params.id)
      .single()

    if (error || !track) {
      return res.status(404).json({ error: 'Track not found' })
    }

    const ext = track.storage_path.split('.').pop().toLowerCase()
    const fmt = ext === 'm4a' ? 'mp4' : ext === 'weba' ? 'webm' : ext

    const { data: signed, error: signError } = await supabase.storage
      .from('music')
      .createSignedUrl(track.storage_path, 3600)

    if (signError || !signed) {
      return res.status(500).json({ error: 'Failed to generate stream URL' })
    }

    res.json({
      url: signed.signedUrl,
      container: fmt,
      type: 'lossy',
      codec: fmt === 'opus' ? 'opus' : fmt === 'mp3' ? 'mp3' : fmt,
      bitrate: fmt === 'opus' ? 96000 : 128000,
    })
  } catch (err) {
    next(err)
  }
})

// Same-origin audio proxy for the admin "Add Sync Lyrics" player.
// Streams the track bytes (with Range support for seeking) so playback does
// not depend on bucket CORS or direct cross-origin media loading.
// Audio is stored in Cloudflare R2 (when configured) or Supabase Storage, so
// we try R2 first and fall back to Supabase Storage for either backend.
const AUDIO_MIME = {
  mp3: 'audio/mpeg', m4a: 'audio/mp4', mp4: 'audio/mp4',
  opus: 'audio/ogg', oga: 'audio/ogg', ogg: 'audio/ogg',
  weba: 'audio/webm', webm: 'audio/webm',
  wav: 'audio/wav', flac: 'audio/flac',
}

app.get('/stream/:id/file', async (req, res, next) => {
  try {
    const { data: track, error } = await supabase
      .from('tracks')
      .select('storage_path')
      .eq('id', req.params.id)
      .single()

    if (error || !track) return res.status(404).json({ error: 'Track not found' })

    let buf = null
    if (r2) {
      try {
        const obj = await r2.send(new GetObjectCommand({ Bucket: R2_BUCKET, Key: track.storage_path }))
        if (obj.Body) buf = Buffer.from(await obj.Body.transformToByteArray())
      } catch (_) { /* fall through to Supabase Storage */ }
    }
    if (!buf) {
      try {
        const { data: file, error: dlErr } = await supabase.storage
          .from('music')
          .download(track.storage_path)
        if (!dlErr && file) buf = Buffer.from(await file.arrayBuffer())
      } catch (_) { /* ignore */ }
    }
    if (!buf) return res.status(500).json({ error: 'Failed to retrieve audio' })

    const ext = (track.storage_path.split('.').pop() || '').toLowerCase()
    const mime = AUDIO_MIME[ext] || 'application/octet-stream'

    res.set('Accept-Ranges', 'bytes')
    res.set('Cache-Control', 'no-store')
    res.set('Content-Type', mime)

    const m = req.headers.range && /^bytes=(\d+)-(\d*)$/.exec(req.headers.range)
    if (m) {
      const start = parseInt(m[1], 10)
      const end = m[2] ? parseInt(m[2], 10) : buf.length - 1
      const s = Math.max(0, start)
      const e = Math.min(buf.length - 1, end)
      if (s > e) {
        res.status(416)
        res.set('Content-Range', `bytes */${buf.length}`)
        return res.end()
      }
      res.status(206)
      res.set('Content-Range', `bytes ${s}-${e}/${buf.length}`)
      res.set('Content-Length', e - s + 1)
      return res.end(buf.subarray(s, e + 1))
    }

    res.set('Content-Length', buf.length)
    res.end(buf)
  } catch (err) {
    next(err)
  }
})

app.get('/browse/sections', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('id, title, thumbnail, duration, artist_names')
      .limit(100)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Browse failed' })
    }

    // Each track is its own section — completely independent, no grouping
    const sections = data.map((t) => ({
      id: `section-${t.id}`,
      title: t.title,
      externalUri: '',
      browseMore: false,
      items: [{
        id: `album-${t.id}`,
        name: t.title,
        externalUri: '',
        artists: (t.artist_names || []).map((name) => ({
          id: name.toLowerCase().replace(/\s+/g, '-'),
          name,
          externalUri: '',
          images: null,
        })),
        images: t.thumbnail ? [{ url: t.thumbnail, width: 300, height: 300 }] : [],
        albumType: 'single',
        releaseDate: null,
      }],
    }))

    res.json({
      items: sections,
      limit: 100,
      nextOffset: null,
      total: sections.length,
      hasMore: false,
    })
  } catch (err) {
    next(err)
  }
})

app.get('/browse/sections/:id/items', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('id, title, thumbnail, duration, artist_names')
      .limit(100)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Browse failed' })
    }

    const items = [{
      id: PLAYLIST_ID,
      name: 'Supabase Songs',
      description: `${data.length} devotional tracks`,
      externalUri: '',
      owner: DEFAULT_USER,
      images: data[0]?.thumbnail ? [{ url: data[0].thumbnail, width: 300, height: 300 }] : [],
    }]

    res.json({ items, limit: 50, nextOffset: null, total: items.length, hasMore: false })
  } catch (err) {
    next(err)
  }
})

app.get('/tracks/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .eq('id', req.params.id)
      .single()

    if (error || !data) {
      return res.status(404).json({ error: 'Track not found' })
    }

    res.json(trackToJson(data, req))
  } catch (err) {
    next(err)
  }
})

app.get('/playlists/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('id, title, thumbnail')
      .limit(100)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Failed' })
    }

    res.json({
      id: PLAYLIST_ID,
      name: 'Supabase Songs',
      description: `${data.length} devotional tracks`,
      externalUri: '',
      owner: DEFAULT_USER,
      images: data[0]?.thumbnail ? [{ url: data[0].thumbnail, width: 300, height: 300 }] : [],
    })
  } catch (err) {
    next(err)
  }
})

app.get('/playlists/:id/tracks', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .order('created_at', { ascending: true })
      .limit(100)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Failed' })
    }

    const items = data.map((t) => trackToJson(t, req))
    res.json({ items, limit: 100, nextOffset: null, total: items.length, hasMore: false })
  } catch (err) {
    next(err)
  }
})

app.get('/albums/:id', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .limit(1)

    if (error || !data?.length) {
      return res.status(404).json({ error: 'Not found' })
    }

    const t = data[0]
    const artists = (t.artist_names || []).map((name) => ({
      id: name.toLowerCase().replace(/\s+/g, '-'),
      name,
      externalUri: '',
      images: null,
    }))

    res.json({
      id: req.params.id,
      name: 'Supabase Album',
      artists,
      images: t.thumbnail ? [{ url: t.thumbnail, width: 300, height: 300 }] : [],
      releaseDate: null,
      externalUri: '',
      totalTracks: 0,
      albumType: 'album',
      recordLabel: null,
      genres: [],
    })
  } catch (err) {
    next(err)
  }
})

app.get('/albums/:id/tracks', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .limit(100)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Failed' })
    }

    const items = data.map((t) => trackToJson(t, req))
    res.json({ items, limit: 100, nextOffset: null, total: items.length, hasMore: false })
  } catch (err) {
    next(err)
  }
})

app.get('/artists/:id', async (req, res, next) => {
  res.json({
    id: req.params.id,
    name: req.params.id.replace(/-/g, ' '),
    externalUri: '',
    images: [],
    genres: null,
    followers: null,
  })
})

app.get('/artists/:id/top-tracks', async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .limit(20)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Failed' })
    }

    const items = data.map((t) => trackToJson(t, req))
    res.json({ items, limit: 100, nextOffset: null, total: items.length, hasMore: false })
  } catch (err) {
    next(err)
  }
})

// Public: admin-created albums with their assigned tracks. Used by the app's
// home "Albums" component to show admin albums, and by the album screen to
// play an album's tracks first-to-last. Each album includes its cover and the
// ordered list of assigned tracks (in insertion order).
app.get('/api/albums', async (req, res, next) => {
  try {
    const { data: albums, error: aErr } = await supabase
      .from('albums')
      .select('*')
      .order('created_at', { ascending: true })
    if (aErr) {
      console.error('[albums] fetch failed:', aErr.message)
      return res.status(500).json({ error: 'Failed to fetch albums' })
    }

    // Fetch all tracks once, then group by album_id (insertion order by row
    // order, which PostgREST returns by created_at asc by default).
    const { data: allTracks, error: tErr } = await supabase
      .from('tracks')
      .select('*')
      .order('created_at', { ascending: true })
    if (tErr) {
      console.error('[albums] tracks fetch failed:', tErr.message)
      return res.status(500).json({ error: 'Failed to fetch album tracks' })
    }

    const byAlbum = {}
    for (const t of allTracks || []) {
      if (t.album_id) {
        (byAlbum[t.album_id] = byAlbum[t.album_id] || []).push(trackToJson(t, req))
      }
    }

    const items = (albums || []).map((a) => ({
      id: a.id,
      name: a.name,
      cover_url: a.cover_url || null,
      images: a.cover_url ? [{ url: a.cover_url, width: 300, height: 300 }] : [],
      tracks: byAlbum[a.id] || [],
    }))

    res.json({ items })
  } catch (err) {
    next(err)
  }
})

app.get('/users/me', (req, res) => {
  res.json(DEFAULT_USER)
})

// ----- Admin authentication (ADMIN_TOKEN) -----
//
// The admin surface (/admin page + /api/admin/*) is protected by a shared
// secret in ADMIN_TOKEN. The browser authenticates once via
// POST /api/admin/login (timing-safe comparison), which sets a short-lived,
// HttpOnly, SameSite=Strict session cookie whose value is HMAC-SHA256 signed
// with the same secret (so it cannot be forged without the token).
//
// Fail-closed: if ADMIN_TOKEN is not configured, admin endpoints return 503
// and the /admin page shows a "not configured" message — never an open admin.
// Read live from `secrets` (populated from the vault at startup).
const ADMIN_COOKIE_NAME = 'sangeet_admin_session'
const ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60 // 8 hours
const ADMIN_COOKIE_MAX_AGE = 1000 * ADMIN_SESSION_TTL_SECONDS

// Brute-force protection: limit login attempts per IP. After 10 failed/any
// attempts within 15 minutes, the IP is throttled with a 429. This prevents
// automated token guessing against the admin login endpoint.
const adminLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  limit: 10, // max attempts per window
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Try again later.' },
})

function signAdminSession() {
  const exp = Date.now() + ADMIN_COOKIE_MAX_AGE
  const payload = `${exp}`
  const sig = crypto
    .createHmac('sha256', secrets.admin_token)
    .update(payload)
    .digest('base64url')
  return `${payload}.${sig}`
}

function verifyAdminSession(value) {
  if (!value) return false
  const [expStr, sig] = value.split('.')
  const exp = Number(expStr)
  if (!Number.isFinite(exp) || exp <= Date.now()) return false
  if (!sig) return false
  const expected = crypto
    .createHmac('sha256', secrets.admin_token)
    .update(expStr)
    .digest('base64url')
  try {
    return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))
  } catch {
    return false
  }
}

function adminSessionCookieValue(req) {
  const header = req.headers.cookie || ''
  for (const part of header.split(';')) {
    const idx = part.indexOf('=')
    if (idx === -1) continue
    const name = part.slice(0, idx).trim()
    if (name === ADMIN_COOKIE_NAME) return part.slice(idx + 1).trim()
  }
  return ''
}

// Middleware protecting /api/admin/*. The cookie must be present, valid, and
// unexpired. On failure a 401 is returned (the SPA shows the login form).
function requireAdmin(req, res, next) {
  if (!secrets.admin_token) {
    return res.status(503).json({ error: 'admin not configured' })
  }
  if (!verifyAdminSession(adminSessionCookieValue(req))) {
    return res.status(401).json({ error: 'unauthorized' })
  }
  next()
}

// Cloudflare R2 (S3-compatible) client for music uploads. Credentials come
// from the vault (secrets.*). When unset, the admin upload falls back to
// Supabase Storage (the previous behaviour).
const R2_BUCKET = process.env.R2_BUCKET_NAME || 'soulful-bhakti-music'
let r2Enabled = false
let r2 = null

function initR2Client() {
  const endpoint = secrets.r2_account_id
    ? `https://${secrets.r2_account_id}.r2.cloudflarestorage.com`
    : ''
  r2Enabled = Boolean(
    endpoint && secrets.r2_access_key_id && secrets.r2_secret_access_key
  )
  r2 = r2Enabled
    ? new S3Client({
        region: 'auto',
        endpoint,
        credentials: {
          accessKeyId: secrets.r2_access_key_id,
          secretAccessKey: secrets.r2_secret_access_key,
        },
      })
    : null
}

async function uploadAudioToR2(key, body, contentType) {
  await r2.send(
    new PutObjectCommand({
      Bucket: R2_BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
    })
  )
  return key
}

// ----- Admin CRUD -----
import multer from 'multer'
const upload = multer({
  storage: multer.memoryStorage(),
  // Bounds memory usage per upload: 110 MB covers the largest opus files
  // with headroom; oversized uploads are rejected with a 413.
  limits: { fileSize: 110 * 1024 * 1024 },
})

// Serve admin HTML. The page itself gates on the session (checks
// /api/admin/session on load and shows a login form when unauthenticated).
// All data is protected server-side by requireAdmin regardless.
app.get('/admin', (req, res) => {
  const htmlPath = path.join(__dirname, 'admin.html')
  if (fs.existsSync(htmlPath)) {
    res.sendFile(htmlPath)
  } else {
    res.status(500).send('admin.html not found')
  }
})

// Login: verifies the ADMIN_TOKEN (timing-safe) and sets a signed HttpOnly
// session cookie. Rate-limited per IP to prevent brute-force guessing. The
// browser sends `{ token }` in the JSON body. The cookie is Secure (HTTPS
// only), HttpOnly, SameSite=Strict.
app.post('/api/admin/login', adminLoginLimiter, (req, res) => {
  if (!secrets.admin_token) {
    return res.status(503).json({ error: 'admin not configured' })
  }
  const { token } = req.body || {}
  if (typeof token !== 'string' || token.length === 0) {
    return res.status(401).json({ error: 'unauthorized' })
  }
  const a = Buffer.from(token)
  const b = Buffer.from(secrets.admin_token)
  const ok = a.length === b.length && crypto.timingSafeEqual(a, b)
  if (!ok) return res.status(401).json({ error: 'unauthorized' })

  res.setHeader(
    'Set-Cookie',
    `${ADMIN_COOKIE_NAME}=${signAdminSession()}; HttpOnly; Secure; Path=/; SameSite=Strict; Max-Age=${ADMIN_SESSION_TTL_SECONDS}`
  )
  res.json({ authenticated: true })
})

// Logout: clears the session cookie.
app.post('/api/admin/logout', (req, res) => {
  res.setHeader(
    'Set-Cookie',
    `${ADMIN_COOKIE_NAME}=; HttpOnly; Secure; Path=/; SameSite=Strict; Max-Age=0`
  )
  res.json({ authenticated: false })
})

// Check current admin session state (used by the SPA on load).
app.get('/api/admin/session', (req, res) => {
  const authenticated =
    Boolean(secrets.admin_token) && verifyAdminSession(adminSessionCookieValue(req))
  res.json({ authenticated })
})

// List all tracks
app.get('/api/admin/tracks', requireAdmin, async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('tracks').select('*').order('created_at', { ascending: false })
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

// Create track
app.post('/api/admin/tracks', requireAdmin, async (req, res, next) => {
  try {
    const { title, artist_names, album, album_id, duration, thumbnail, storage_path, status, lyrics, synced_lyrics, synced_lyrics_en, synced_lyrics_hi, language } = req.body || {}
    if (typeof title !== 'string' || !title.trim()) return res.status(400).json({ error: 'title is required' })
    if (typeof storage_path !== 'string' || !storage_path.trim()) return res.status(400).json({ error: 'storage_path is required' })
    const cleanTitle = title.trim()
    const cleanArtists = Array.isArray(artist_names) && artist_names.length
      ? artist_names.map((a) => String(a).trim()).filter(Boolean)
      : ['Unknown Artist']
    const cleanDuration = Number.isFinite(Number(duration)) && Number(duration) >= 0 ? Math.floor(Number(duration)) : 0
    const cleanStatus = status === 'paid' ? 'paid' : 'free'
    const { data, error } = await supabase.from('tracks').insert({
      title: cleanTitle,
      artist_names: cleanArtists,
      artist_names_text: cleanArtists.join(', '),
      album: typeof album === 'string' && album.trim() ? album.trim() : cleanTitle,
      album_id: typeof album_id === 'string' && album_id.trim() ? album_id.trim() : null,
      duration: cleanDuration,
      thumbnail: typeof thumbnail === 'string' && thumbnail.trim() ? thumbnail.trim() : null,
      storage_path: storage_path.trim(),
      status: cleanStatus,
      lyrics: typeof lyrics === 'string' && lyrics.trim() ? lyrics : null,
      synced_lyrics: typeof synced_lyrics === 'string' && synced_lyrics.trim() ? synced_lyrics : null,
      synced_lyrics_en: typeof synced_lyrics_en === 'string' && synced_lyrics_en.trim() ? synced_lyrics_en : null,
      synced_lyrics_hi: typeof synced_lyrics_hi === 'string' && synced_lyrics_hi.trim() ? synced_lyrics_hi : null,
      language: typeof language === 'string' && language.trim() ? language.trim() : null,
    }).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json(data)
  } catch (err) { next(err) }
})

// Update track
app.put('/api/admin/tracks/:id', requireAdmin, async (req, res, next) => {
  try {
    const { title, artist_names, album, album_id, duration, thumbnail, storage_path, status, lyrics, synced_lyrics, synced_lyrics_en, synced_lyrics_hi, language } = req.body || {}
    const updates = {}
    if (title !== undefined) {
      if (typeof title !== 'string' || !title.trim()) return res.status(400).json({ error: 'title must be a non-empty string' })
      updates.title = title.trim()
    }
    if (artist_names !== undefined) {
      if (!Array.isArray(artist_names)) return res.status(400).json({ error: 'artist_names must be an array' })
      const clean = artist_names.map((a) => String(a).trim()).filter(Boolean)
      updates.artist_names = clean
      updates.artist_names_text = clean.join(', ')
    }
    if (album !== undefined) updates.album = typeof album === 'string' && album.trim() ? album.trim() : null
    if (album_id !== undefined) updates.album_id = typeof album_id === 'string' && album_id.trim() ? album_id.trim() : null
    if (duration !== undefined) {
      if (!Number.isFinite(Number(duration)) || Number(duration) < 0) return res.status(400).json({ error: 'duration must be a non-negative number' })
      updates.duration = Math.floor(Number(duration))
    }
    if (thumbnail !== undefined) updates.thumbnail = typeof thumbnail === 'string' && thumbnail.trim() ? thumbnail.trim() : null
    if (storage_path !== undefined) {
      if (typeof storage_path !== 'string' || !storage_path.trim()) return res.status(400).json({ error: 'storage_path must be a non-empty string' })
      updates.storage_path = storage_path.trim()
    }
    if (status !== undefined) updates.status = status === 'paid' ? 'paid' : 'free'
    if (lyrics !== undefined) updates.lyrics = typeof lyrics === 'string' && lyrics.trim() ? lyrics : null
    if (synced_lyrics !== undefined) updates.synced_lyrics = typeof synced_lyrics === 'string' && synced_lyrics.trim() ? synced_lyrics : null
    if (synced_lyrics_en !== undefined) updates.synced_lyrics_en = typeof synced_lyrics_en === 'string' && synced_lyrics_en.trim() ? synced_lyrics_en : null
    if (synced_lyrics_hi !== undefined) updates.synced_lyrics_hi = typeof synced_lyrics_hi === 'string' && synced_lyrics_hi.trim() ? synced_lyrics_hi : null
    if (language !== undefined) updates.language = typeof language === 'string' && language.trim() ? language.trim() : null
    if (Object.keys(updates).length === 0) return res.status(400).json({ error: 'no fields to update' })
    const { data, error } = await supabase.from('tracks').update(updates).eq('id', req.params.id).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

// Delete track
app.delete('/api/admin/tracks/:id', requireAdmin, async (req, res, next) => {
  try {
    const { error } = await supabase.from('tracks').delete().eq('id', req.params.id)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})

// List admin-created albums. Used by the admin UI and to feed the home
// "Albums" component.
app.get('/api/admin/albums', requireAdmin, async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('albums')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) return res.status(500).json({ error: error.message })
    res.json(data || [])
  } catch (err) { next(err) }
})

// Create an admin album (name + cover photo URL).
app.post('/api/admin/albums', requireAdmin, async (req, res, next) => {
  try {
    const { name, cover_url } = req.body || {}
    if (typeof name !== 'string' || !name.trim()) return res.status(400).json({ error: 'name is required' })
    const { data, error } = await supabase
      .from('albums')
      .insert({
        name: name.trim(),
        cover_url: typeof cover_url === 'string' && cover_url.trim() ? cover_url.trim() : null,
      })
      .select()
      .single()
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json(data)
  } catch (err) { next(err) }
})

// Update an admin album (name + cover photo URL).
app.put('/api/admin/albums/:id', requireAdmin, async (req, res, next) => {
  try {
    const { name, cover_url } = req.body || {}
    const updates = {}
    if (name !== undefined) {
      if (typeof name !== 'string' || !name.trim()) return res.status(400).json({ error: 'name must be a non-empty string' })
      updates.name = name.trim()
    }
    if (cover_url !== undefined) updates.cover_url = typeof cover_url === 'string' && cover_url.trim() ? cover_url.trim() : null
    if (Object.keys(updates).length === 0) return res.status(400).json({ error: 'nothing to update' })
    const { data, error } = await supabase.from('albums').update(updates).eq('id', req.params.id).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

// Delete an admin album. Tracks assigned to it keep their legacy `album` text
// (their album_id is set to null by the FK on delete set null).
app.delete('/api/admin/albums/:id', requireAdmin, async (req, res, next) => {
  try {
    const { error } = await supabase.from('albums').delete().eq('id', req.params.id)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})


// Upload file (audio -> Cloudflare R2 when configured, else Supabase Storage;
// images -> Supabase Storage thumbnails bucket).
app.post('/api/admin/upload', requireAdmin, upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' })
    const ext = req.file.originalname.split('.').pop().toLowerCase()
    const isImage = ['png', 'jpg', 'jpeg', 'webp'].includes(ext)
    const isAudio = ext === 'opus'
    if (!isImage && !isAudio) return res.status(400).json({ error: 'Allowed: .opus for audio, .png/.jpg/.jpeg/.webp for thumbnails' })
    const fileName = `${Date.now()}-${req.file.originalname}`
    const contentType = isImage ? (ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg') : 'audio/ogg'

    if (isAudio && r2Enabled) {
      // Stream to Cloudflare R2 so new songs are served from the CDN.
      const key = await uploadAudioToR2(fileName, req.file.buffer, contentType)
      return res.json({ storage_path: key })
    }

    const bucket = isImage ? 'thumbnails' : 'music'
    const { data, error } = await supabase.storage.from(bucket).upload(fileName, req.file.buffer, {
      contentType,
      upsert: false,
    })
    if (error) return res.status(500).json({ error: error.message })
    if (isImage) {
      const { data: { publicUrl } } = supabase.storage.from(bucket).getPublicUrl(fileName)
      res.json({ thumbnail_url: publicUrl })
    } else {
      res.json({ storage_path: fileName })
    }
  } catch (err) { next(err) }
})

// ----- Affiliate & Coupon Admin -----
//
// Affiliate marketing rules (enforced server-side):
//  - Coupons are attribution-only codes issued to external marketers.
//  - Affiliate commission applies ONLY to the yearly plan (soulful_yearly)
//    and is a FLAT ₹100 per successful yearly sale (see migration 007).
//  - Commission is credited exclusively from verified Superwall webhooks.

// List affiliates (with their coupon count)
app.get('/api/admin/affiliates', requireAdmin, async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('affiliates')
      .select('*, coupons:coupons(id)')
      .order('created_at', { ascending: false })
    if (error) return res.status(500).json({ error: error.message })
    res.json(data || [])
  } catch (err) { next(err) }
})

// Create an affiliate (external marketer) with an admin-decided commission
// amount per yearly sale and a QR referrer code.
app.post('/api/admin/affiliates', requireAdmin, async (req, res, next) => {
  try {
    const { name, contact_email, commission_amount, referrer_code } = req.body || {}
    if (!name || !name.trim()) return res.status(400).json({ error: 'name required' })
    const amount =
      commission_amount != null && Number(commission_amount) >= 0
        ? Number(commission_amount)
        : 0
    // Referrer code: admin-supplied (upper-cased) or auto-generated.
    let code = null
    if (referrer_code && String(referrer_code).trim()) {
      const clean = String(referrer_code).trim().toUpperCase()
      if (!/^[A-Z0-9][A-Z0-9-]{2,31}$/.test(clean)) {
        return res.status(400).json({ error: 'referrer code must be 3-32 letters, numbers or hyphens' })
      }
      code = clean
    } else {
      code = `AFF-${crypto.randomBytes(4).toString('hex').toUpperCase()}`
    }
    const { data, error } = await supabase
      .from('affiliates')
      .insert({
        name: name.trim(),
        contact_email: contact_email || null,
        commission_amount: amount,
        referrer_code: code,
      })
      .select()
      .single()
    if (error) {
      if (error.code === '23505') {
        return res.status(409).json({ error: 'that referrer code is already in use' })
      }
      return res.status(500).json({ error: error.message })
    }
    res.status(201).json(data)
  } catch (err) { next(err) }
})

// Update an affiliate (name, contact, commission amount, referrer code)
app.put('/api/admin/affiliates/:id', requireAdmin, async (req, res, next) => {
  try {
    const { name, contact_email, commission_amount, referrer_code } = req.body || {}
    const updates = {}
    if (name !== undefined) updates.name = String(name).trim()
    if (contact_email !== undefined) updates.contact_email = contact_email || null
    if (commission_amount !== undefined && Number(commission_amount) >= 0) {
      updates.commission_amount = Number(commission_amount)
    }
    if (referrer_code !== undefined) {
      const clean = String(referrer_code).trim().toUpperCase()
      if (!/^[A-Z0-9][A-Z0-9-]{2,31}$/.test(clean)) {
        return res.status(400).json({ error: 'referrer code must be 3-32 letters, numbers or hyphens' })
      }
      updates.referrer_code = clean
    }
    if (Object.keys(updates).length === 0) {
      return res.status(400).json({ error: 'nothing to update' })
    }
    const { data, error } = await supabase
      .from('affiliates')
      .update(updates)
      .eq('id', req.params.id)
      .select()
      .single()
    if (error) {
      if (error.code === '23505') {
        return res.status(409).json({ error: 'that referrer code is already in use' })
      }
      return res.status(500).json({ error: error.message })
    }
    res.json(data)
  } catch (err) { next(err) }
})

// Generate (or return) the QR code image for an affiliate's install deep
// link. The QR encodes the Google Play Store listing URL with an
// install-referrer carrying the affiliate's referrer code:
//   https://play.google.com/store/apps/details?id=com.soulfulbhakti.app&referrer=utm_source=<referrer_code>
// Scanned by a customer -> opens Play Store -> installs -> on first launch
// the app reads the referrer (Install Referrer API) to attribute the user.
// Returns a PNG image (application/png). Requires an admin session.
app.get('/api/admin/affiliates/:id/qr.png', requireAdmin, async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('affiliates')
      .select('id, name, referrer_code')
      .eq('id', req.params.id)
      .maybeSingle()
    if (error) return res.status(500).json({ error: error.message })
    if (!data || !data.referrer_code) {
      return res.status(404).json({ error: 'affiliate has no referrer code' })
    }
    const installUrl =
      'https://play.google.com/store/apps/details?id=com.soulfulbhakti.app' +
      '&referrer=utm_source=' + encodeURIComponent(data.referrer_code)
    const png = await QRCode.toBuffer(installUrl, {
      width: 320,
      margin: 1,
      errorCorrectionLevel: 'M',
    })
    res.set('Content-Type', 'image/png')
    res.set('Cache-Control', 'no-store')
    res.send(png)
  } catch (err) { next(err) }
})

// Delete an affiliate (cascades to coupons + attributions; commission rows
// are preserved for the ledger).
app.delete('/api/admin/affiliates/:id', requireAdmin, async (req, res, next) => {
  try {
    const { error } = await supabase
      .from('affiliates')
      .delete()
      .eq('id', req.params.id)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})

// List coupons (with affiliate name)
app.get('/api/admin/coupons', requireAdmin, async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('coupons')
      .select('*, affiliate:affiliates(name)')
      .order('created_at', { ascending: false })
    if (error) return res.status(500).json({ error: error.message })
    res.json(data || [])
  } catch (err) { next(err) }
})

// Create a coupon code assigned to an affiliate marketer.
// Body: { code, affiliate_id, max_redemptions?, expires_at? }
app.post('/api/admin/coupons', requireAdmin, async (req, res, next) => {
  try {
    const { code, affiliate_id, max_redemptions, expires_at } = req.body || {}
    if (typeof code !== 'string' || !code.trim()) return res.status(400).json({ error: 'code required' })
    if (typeof affiliate_id !== 'string' || !affiliate_id.trim()) return res.status(400).json({ error: 'affiliate_id required' })
    const normalized = code.trim().toUpperCase()
    if (!/^[A-Z0-9][A-Z0-9-]*$/.test(normalized)) {
      return res.status(400).json({ error: 'code must be letters, numbers or hyphens' })
    }
    let cleanMax = null
    if (max_redemptions !== undefined && max_redemptions !== null && max_redemptions !== '') {
      const n = Number(max_redemptions)
      if (!Number.isInteger(n) || n <= 0) return res.status(400).json({ error: 'max_redemptions must be a positive integer' })
      cleanMax = n
    }
    const { data, error } = await supabase
      .from('coupons')
      .insert({
        code: normalized,
        affiliate_id,
        max_redemptions: cleanMax,
        expires_at: expires_at || null,
      })
      .select('*, affiliate:affiliates(name)')
      .single()
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json(data)
  } catch (err) { next(err) }
})

// Pause/resume a coupon (status: active|paused)
app.put('/api/admin/coupons/:id', requireAdmin, async (req, res, next) => {
  try {
    const { status } = req.body || {}
    if (status !== 'active' && status !== 'paused') {
      return res.status(400).json({ error: "status must be 'active' or 'paused'" })
    }
    const { data, error } = await supabase
      .from('coupons')
      .update({ status })
      .eq('id', req.params.id)
      .select()
      .single()
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

// List affiliate commissions (earnings ledger)
app.get('/api/admin/commissions', requireAdmin, async (req, res, next) => {
  try {
    const { data, error } = await supabase
      .from('affiliate_commissions')
      .select('*, affiliate:affiliates(name)')
      .order('created_at', { ascending: false })
      .limit(500)
    if (error) return res.status(500).json({ error: error.message })
    res.json(data || [])
  } catch (err) { next(err) }
})

// ----- Playlist Routes -----
app.get('/api/playlists', async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('playlists').select('*').eq('visibility', 'public').order('created_at', { ascending: false })
    if (error && error.message.includes('relation') && error.message.includes('does not exist')) return res.json([])
    if (error) return res.status(500).json({ error: error.message })
    res.json(data || [])
  } catch (err) { next(err) }
})

app.get('/api/playlists/:id', async (req, res, next) => {
  try {
    const { data: playlist, error } = await supabase.from('playlists').select('*').eq('id', req.params.id).single()
    if (error) return res.status(404).json({ error: 'Playlist not found' })
    const { data: songs } = await supabase.from('playlist_songs').select('track_id, position').eq('playlist_id', req.params.id).order('position')
    const trackIds = (songs || []).map(s => s.track_id)
    const tracks = trackIds.length ? (await supabase.from('tracks').select('*').in('id', trackIds)).data || [] : []
    res.json({ ...playlist, tracks })
  } catch (err) { next(err) }
})

app.post('/api/playlists', async (req, res, next) => {
  try {
    const { user_id, title, description, visibility } = req.body
    if (!user_id || !title) return res.status(400).json({ error: 'user_id and title required' })
    const { data, error } = await supabase.from('playlists').insert({
      user_id, title,
      description: description || null,
      visibility: visibility || 'public',
    }).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json(data)
  } catch (err) { next(err) }
})

app.put('/api/playlists/:id', async (req, res, next) => {
  try {
    const { title, description, visibility } = req.body
    const updates = {}
    if (title !== undefined) updates.title = title
    if (description !== undefined) updates.description = description
    if (visibility !== undefined) updates.visibility = visibility
    const { data, error } = await supabase.from('playlists').update(updates).eq('id', req.params.id).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

app.post('/api/playlists/:id/songs', async (req, res, next) => {
  try {
    const { track_id } = req.body
    if (!track_id) return res.status(400).json({ error: 'track_id required' })
    const { data: existing } = await supabase.from('playlist_songs').select('max_position').eq('playlist_id', req.params.id).limit(1)
    const maxPos = existing?.[0]?.max_position ?? -1
    const { error } = await supabase.from('playlist_songs').insert({
      playlist_id: req.params.id, track_id, position: maxPos + 1,
    })
    if (error && error.message.includes('duplicate')) return res.status(409).json({ error: 'Song already in playlist' })
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json({ success: true })
  } catch (err) { next(err) }
})

app.delete('/api/playlists/:playlistId/songs/:trackId', async (req, res, next) => {
  try {
    const { error } = await supabase.from('playlist_songs').delete()
      .eq('playlist_id', req.params.playlistId).eq('track_id', req.params.trackId)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})

app.delete('/api/playlists/:id', async (req, res, next) => {
  try {
    await supabase.from('playlist_songs').delete().eq('playlist_id', req.params.id)
    const { error } = await supabase.from('playlists').delete().eq('id', req.params.id)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})

// ----- Liked Songs -----
app.get('/api/liked-songs/:userId', async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('liked_songs').select('track_id').eq('user_id', req.params.userId)
    if (error && error.message.includes('relation') && error.message.includes('does not exist')) return res.json([])
    if (error) return res.status(500).json({ error: error.message })
    const trackIds = (data || []).map(l => l.track_id)
    const tracks = trackIds.length ? (await supabase.from('tracks').select('*').in('id', trackIds)).data || [] : []
    res.json(tracks)
  } catch (err) { next(err) }
})

app.post('/api/liked-songs', async (req, res, next) => {
  try {
    const { user_id, track_id } = req.body
    if (!user_id || !track_id) return res.status(400).json({ error: 'user_id and track_id required' })
    const { error } = await supabase.from('liked_songs').insert({ user_id, track_id })
    if (error && error.message.includes('duplicate')) return res.json({ success: true })
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json({ success: true })
  } catch (err) { next(err) }
})

app.delete('/api/liked-songs/:userId/:trackId', async (req, res, next) => {
  try {
    const { error } = await supabase.from('liked_songs').delete()
      .eq('user_id', req.params.userId).eq('track_id', req.params.trackId)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})

// ----- Storage Usage (matches getStorageUsageAction.ts) -----
app.get('/api/storage-usage', async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('tracks').select('storage_path')
    if (error) return res.status(500).json({ error: error.message })
    res.json({ total_tracks: (data || []).length })
  } catch (err) { next(err) }
})

// ----- User Profiles -----
app.get('/api/user-profile/:userId', async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('user_profiles').select('*').eq('id', req.params.userId).single()
    if (error && error.message.includes('relation') && error.message.includes('does not exist')) return res.json({ id: req.params.userId })
    if (error && error.code === 'PGRST116') return res.json({ id: req.params.userId })
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

app.post('/api/user-profile', async (req, res, next) => {
  try {
    const { id, full_name, avatar_url } = req.body
    if (!id) return res.status(400).json({ error: 'id required' })
    const { data, error } = await supabase.from('user_profiles').upsert({ id, full_name, avatar_url }).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

app.use((err, req, res, next) => {
  console.error(err)
  res.status(500).json({ error: 'Internal Server Error' })
})

const port = process.env.PORT || 3000

async function start() {
  await loadSecretsFromVault()
  initR2Client()
  app.listen(port, () => {
    console.log(`Sangeet Supabase server running on port ${port} - v3`)
  })
}

start().catch((err) => {
  console.error('[startup] failed:', err)
  process.exit(1)
})
