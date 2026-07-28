import { createClient } from '@supabase/supabase-js'
import express from 'express'
import cors from 'cors'

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
app.use(cors())
app.use(express.json())

app.get('/search', async (req, res, next) => {
  try {
    const q = (req.query.q || '').trim()
    if (!q) return res.json([])

    const pattern = `%${q}%`
    const orConditions = [
      `title.ilike.${pattern}`,
      `artist_names_text.ilike.${pattern}`,
    ]

    const { data, error } = await supabase
      .from('tracks')
      .select('*')
      .or(orConditions.join(','))
      .limit(30)

    if (error) {
      console.error(error)
      return res.status(500).json({ error: 'Search failed' })
    }

    res.json(
      data.map((t) => ({
        id: t.id,
        title: t.title,
        artists: t.artist_names,
        duration: t.duration * 1000000,
        thumbnail: t.thumbnail || null,
        externalUri: `${req.protocol}://${req.get('host')}/stream/${t.id}`,
      }))
    )
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

app.use((err, req, res, next) => {
  console.error(err)
  res.status(500).json({ error: 'Internal Server Error' })
})

const port = process.env.PORT || 3000
app.listen(port, () => {
  console.log(`Sangeet Supabase server running on port ${port}`)
})
