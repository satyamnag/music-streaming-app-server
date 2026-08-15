import { createClient } from '@supabase/supabase-js'
import express from 'express'
import cors from 'cors'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'
import crypto from 'crypto'
import dotenv from 'dotenv'

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
  const secret = process.env.SUPERWALL_WEBHOOK_SECRET

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
    res.json({ items, limit: 20, nextOffset: null, total: items.length, hasMore: false })
  } catch (err) {
    next(err)
  }
})

app.get('/users/me', (req, res) => {
  res.json(DEFAULT_USER)
})

// ----- Admin CRUD -----
import multer from 'multer'
const upload = multer({ storage: multer.memoryStorage() })

// Serve admin HTML
app.get('/admin', (req, res) => {
  const htmlPath = path.join(__dirname, 'admin.html')
  if (fs.existsSync(htmlPath)) {
    res.sendFile(htmlPath)
  } else {
    res.status(500).send('admin.html not found')
  }
})

// List all tracks
app.get('/api/admin/tracks', async (req, res, next) => {
  try {
    const { data, error } = await supabase.from('tracks').select('*').order('created_at', { ascending: false })
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

// Create track
app.post('/api/admin/tracks', async (req, res, next) => {
  try {
    const { title, artist_names, album, duration, thumbnail, storage_path, status, lyrics, synced_lyrics } = req.body
    if (!title || !storage_path) return res.status(400).json({ error: 'title and storage_path required' })
    const { data, error } = await supabase.from('tracks').insert({
      title,
      artist_names: artist_names || ['Unknown Artist'],
      artist_names_text: (artist_names || ['Unknown Artist']).join(', '),
      album: album || title,
      duration: duration || 0,
      thumbnail: thumbnail || null,
      storage_path,
      status: status === 'paid' ? 'paid' : 'free',
      lyrics: lyrics || null,
      synced_lyrics: synced_lyrics || null,
    }).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json(data)
  } catch (err) { next(err) }
})

// Update track
app.put('/api/admin/tracks/:id', async (req, res, next) => {
  try {
    const { title, artist_names, album, duration, thumbnail, storage_path, status, lyrics, synced_lyrics } = req.body
    const updates = {}
    if (title !== undefined) updates.title = title
    if (artist_names !== undefined) { updates.artist_names = artist_names; updates.artist_names_text = artist_names.join(', ') }
    if (album !== undefined) updates.album = album
    if (duration !== undefined) updates.duration = duration
    if (thumbnail !== undefined) updates.thumbnail = thumbnail
    if (storage_path !== undefined) updates.storage_path = storage_path
    if (status !== undefined) updates.status = status === 'paid' ? 'paid' : 'free'
    if (lyrics !== undefined) updates.lyrics = lyrics
    if (synced_lyrics !== undefined) updates.synced_lyrics = synced_lyrics
    const { data, error } = await supabase.from('tracks').update(updates).eq('id', req.params.id).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.json(data)
  } catch (err) { next(err) }
})

// Delete track
app.delete('/api/admin/tracks/:id', async (req, res, next) => {
  try {
    const { error } = await supabase.from('tracks').delete().eq('id', req.params.id)
    if (error) return res.status(500).json({ error: error.message })
    res.json({ success: true })
  } catch (err) { next(err) }
})

// Upload file to Supabase storage (opus or image)
app.post('/api/admin/upload', upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' })
    const ext = req.file.originalname.split('.').pop().toLowerCase()
    const isImage = ['png', 'jpg', 'jpeg', 'webp'].includes(ext)
    const isAudio = ext === 'opus'
    if (!isImage && !isAudio) return res.status(400).json({ error: 'Allowed: .opus for audio, .png/.jpg/.jpeg/.webp for thumbnails' })
    const fileName = `${Date.now()}-${req.file.originalname}`
    const contentType = isImage ? (ext === 'png' ? 'image/png' : ext === 'webp' ? 'image/webp' : 'image/jpeg') : 'audio/ogg'
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
app.listen(port, () => {
  console.log(`Sangeet Supabase server running on port ${port} - v2`)
})
