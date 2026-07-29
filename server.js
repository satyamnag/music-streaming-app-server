import { createClient } from '@supabase/supabase-js'
import express from 'express'
import cors from 'cors'
import path from 'path'
import { fileURLToPath } from 'url'
import fs from 'fs'
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

    const playlistItems = [{
      id: PLAYLIST_ID,
      name: 'Supabase Songs',
      description: `${data.length} devotional tracks`,
      externalUri: '',
      owner: DEFAULT_USER,
      images: data[0]?.thumbnail ? [{ url: data[0].thumbnail, width: 300, height: 300 }] : [],
    }]

    res.json({
      items: [{
        id: 'sections-supabase',
        title: 'Supabase Songs',
        externalUri: '',
        browseMore: false,
        items: playlistItems,
      }],
      limit: 50,
      nextOffset: null,
      total: 1,
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
    const { title, artist_names, album, duration, thumbnail, storage_path } = req.body
    if (!title || !storage_path) return res.status(400).json({ error: 'title and storage_path required' })
    const { data, error } = await supabase.from('tracks').insert({
      title,
      artist_names: artist_names || ['Unknown Artist'],
      artist_names_text: (artist_names || ['Unknown Artist']).join(', '),
      album: album || title,
      duration: duration || 0,
      thumbnail: thumbnail || null,
      storage_path,
    }).select().single()
    if (error) return res.status(500).json({ error: error.message })
    res.status(201).json(data)
  } catch (err) { next(err) }
})

// Update track
app.put('/api/admin/tracks/:id', async (req, res, next) => {
  try {
    const { title, artist_names, album, duration, thumbnail, storage_path } = req.body
    const updates = {}
    if (title !== undefined) updates.title = title
    if (artist_names !== undefined) { updates.artist_names = artist_names; updates.artist_names_text = artist_names.join(', ') }
    if (album !== undefined) updates.album = album
    if (duration !== undefined) updates.duration = duration
    if (thumbnail !== undefined) updates.thumbnail = thumbnail
    if (storage_path !== undefined) updates.storage_path = storage_path
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

// Upload opus file to Supabase storage
app.post('/api/admin/upload', upload.single('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' })
    const ext = req.file.originalname.split('.').pop().toLowerCase()
    if (ext !== 'opus') return res.status(400).json({ error: 'Only .opus files are allowed' })
    const fileName = `${Date.now()}-${req.file.originalname}`
    const { data, error } = await supabase.storage.from('music').upload(fileName, req.file.buffer, {
      contentType: 'audio/ogg',
      upsert: false,
    })
    if (error) return res.status(500).json({ error: error.message })
    res.json({ storage_path: fileName })
  } catch (err) { next(err) }
})

app.use((err, req, res, next) => {
  console.error(err)
  res.status(500).json({ error: 'Internal Server Error' })
})

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`Sangeet Supabase server running on port ${port}`)
})
