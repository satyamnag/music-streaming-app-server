// ============================================================================
// Real-Postgres-backed Supabase client adapter (TEST ONLY)
// ============================================================================
//
// The existing integration suite runs server.js against an in-memory stub,
// which cannot prove that the SQL is correct — only a real database can.
//
// This module provides the same `supabase` client surface that server.js and
// partner_routes.mjs use (`.from(table).select/insert/update/delete`,
// `.rpc(name, params)`, `.storage.from(bucket)…`) but executes everything
// against a GENUINE PostgreSQL database over the `pg` wire protocol.
//
// It is deliberately a thin PostgREST-shaped translation layer:
//   .from('partners').select().eq('id', x).maybeSingle()
//     -> SELECT * FROM public.partners WHERE id = $1 LIMIT 1
//
// Storage is emulated with a real table (test_only_storage_objects) whose
// bytes live in a bytea column, so upload/download/remove round-trip real
// ciphertext through a real database rather than a JS Map.
//
// This is a TEST FIXTURE. It is never imported by production code.

import pg from 'pg'

const { Pool } = pg

/**
 * supabase-js's createClient(url, key, options) signature is preserved so the
 * adapter can be dropped in via a module hook. `url` is ignored: the real
 * connection comes from PARTNER_TEST_DB_URL, because server.js is handed a
 * fake SUPABASE_URL in tests.
 */
export function createClient(_url, _key, _options) {
  const connectionString = process.env.PARTNER_TEST_DB_URL
  if (!connectionString) {
    throw new Error(
      'PARTNER_TEST_DB_URL is not set — the real-database test harness needs a ' +
      'PostgreSQL connection string (e.g. postgres://postgres:pw@127.0.0.1:55432/sb_partner_test)',
    )
  }
  return createRealSupabase({ connectionString })
}

export function createRealSupabase({ connectionString }) {
  const pool = new Pool({ connectionString, max: 10 })

  // ---- identifier safety --------------------------------------------------
  // Table and column names are interpolated into SQL, so they are validated
  // against a strict allow-list pattern rather than escaped. Anything that
  // does not look like a plain identifier is rejected outright.
  function ident(name) {
    if (typeof name !== 'string' || !/^[a-z_][a-z0-9_]*$/i.test(name)) {
      throw new Error(`unsafe SQL identifier rejected: ${JSON.stringify(name)}`)
    }
    return name
  }

  // Qualified table name. The application uses both `partners` and
  // `partner_documents`; all live in `public`.
  function table(name) {
    return `public.${ident(name)}`
  }

  // ---- value binding ------------------------------------------------------
  function bind(values, value) {
    values.push(value)
    return `$${values.length}`
  }

  // -------------------------------------------------------------------------
  // Query builder
  // -------------------------------------------------------------------------
  function from(tableName) {
    const state = {
      table: tableName,
      op: 'select',
      columns: '*',
      filters: [],
      payload: null,
      limit: null,
      order: [],
      returning: true,
    }

    const api = {
      select(columns) {
        if (state.op === 'select') state.op = 'select'
        state.columns = columns && columns !== '*' ? columns : '*'
        // `.insert(...).select()` means "return the inserted rows".
        return api
      },
      insert(payload) {
        state.op = 'insert'
        state.payload = payload
        return api
      },
      update(payload) {
        state.op = 'update'
        state.payload = payload
        return api
      },
      delete() {
        state.op = 'delete'
        return api
      },
      eq(col, val) {
        state.filters.push({ kind: 'eq', col, val })
        return api
      },
      is(col, val) {
        state.filters.push({ kind: 'is', col, val })
        return api
      },
      order(col, opts) {
        state.order.push({ col, ascending: !(opts && opts.ascending === false) })
        return api
      },
      limit(n) {
        state.limit = n
        return api
      },
      maybeSingle() {
        state.limit = 1
        state.single = 'maybe'
        return execute()
      },
      single() {
        state.limit = 1
        state.single = 'strict'
        return execute()
      },
      then(resolve, reject) {
        return execute().then(resolve, reject)
      },
    }

    function whereClause(values) {
      if (!state.filters.length) return ''
      const parts = state.filters.map((f) => {
        const col = ident(f.col)
        if (f.kind === 'is' && f.val === null) return `${col} IS NULL`
        if (f.kind === 'is') return `${col} IS ${f.val === true ? 'TRUE' : 'FALSE'}`
        if (f.val === null) return `${col} IS NULL`
        return `${col} = ${bind(values, f.val)}`
      })
      return ' WHERE ' + parts.join(' AND ')
    }

    async function execute() {
      const values = []
      let sql
      let expectRows = true

      try {
        if (state.op === 'select') {
          const cols = state.columns === '*' ? '*' : state.columns
          sql = `SELECT ${cols} FROM ${table(state.table)}${whereClause(values)}`
          if (state.order.length) {
            sql += ' ORDER BY ' + state.order
              .map((o) => `${ident(o.col)} ${o.ascending ? 'ASC' : 'DESC'}`)
              .join(', ')
          }
          if (state.limit) sql += ` LIMIT ${Number(state.limit)}`
        } else if (state.op === 'insert') {
          const rows = Array.isArray(state.payload) ? state.payload : [state.payload]
          if (!rows.length) return { data: state.single ? null : [], error: null }
          const cols = Object.keys(rows[0])
          cols.forEach(ident)
          // Build a multi-row VALUES list so a batch insert is one round trip.
          const tuples = rows.map((row) => {
            const placeholders = cols.map((c) => bind(values, row[c] === undefined ? null : row[c]))
            return `(${placeholders.join(', ')})`
          })
          sql = `INSERT INTO ${table(state.table)} (${cols.join(', ')}) VALUES ${tuples.join(', ')} RETURNING *`
        } else if (state.op === 'update') {
          const entries = Object.entries(state.payload)
          entries.forEach(([k]) => ident(k))
          const sets = entries.map(([k, v]) => `${k} = ${bind(values, v)}`)
          sql = `UPDATE ${table(state.table)} SET ${sets.join(', ')}`
            + `${whereClause(values)} RETURNING *`
        } else {
          sql = `DELETE FROM ${table(state.table)}${whereClause(values)} RETURNING *`
        }

        const res = await pool.query(sql, values)
        let data = res.rows

        if (state.single === 'strict') {
          if (data.length === 0) {
            return { data: null, error: { code: 'PGRST116', message: 'no rows returned' } }
          }
          data = data[0]
        } else if (state.single === 'maybe') {
          data = data.length ? data[0] : null
        }
        return { data, error: null }
      } catch (err) {
        // Surface PostgreSQL errors in the shape PostgREST/supabase-js uses,
        // because the application branches on `error.code` (e.g. '23505').
        return {
          data: null,
          error: {
            code: err.code,
            message: err.message,
            details: err.detail,
            hint: err.hint,
          },
        }
      }
    }

    return api
  }

  // -------------------------------------------------------------------------
  // RPC: calls the real SQL functions
  //
  // RETURN-SHAPE FIDELITY MATTERS HERE.
  // supabase-js does NOT always return an array:
  //   * SETOF / TABLE returns  -> an array of row objects
  //   * a scalar return        -> the bare value
  //   * VOID                   -> null
  //
  // The application depends on this. `get_secret` returns `text` and the server
  // does `if (data) secrets[key] = data`. Returning `[{get_secret:'x'}]` would
  // make the server treat the ARRAY as the secret, silently breaking the admin
  // token and the document-encryption key.
  //
  // The distinction is made from the function's DECLARED return type, not from
  // the number of columns in the result — because `partner_get_self` returns
  // `SETOF partners`, which is a single-column-looking result only if you
  // guess. The catalog is the authority.
  // -------------------------------------------------------------------------
  const rpcShapeCache = new Map()

  async function rpcShape(name) {
    if (rpcShapeCache.has(name)) return rpcShapeCache.get(name)
    const res = await pool.query(
      `select t.typtype, t.typname, p.proretset
         from pg_proc p
         join pg_namespace n on n.oid = p.pronamespace
         join pg_type t on t.oid = p.prorettype
        where n.nspname = 'public' and p.proname = $1
        limit 1`,
      [name],
    )
    let shape = 'table'
    if (res.rows.length) {
      const { typtype, typname, proretset } = res.rows[0]
      if (typname === 'void') shape = 'void'
      else if (proretset) shape = 'table'                    // SETOF x / TABLE(...)
      else if (typtype === 'b' || typtype === 'd') shape = 'scalar' // base/domain type
      else shape = 'composite_single'                        // returns one composite row
    }
    rpcShapeCache.set(name, shape)
    return shape
  }

  async function rpc(name, params = {}) {
    try {
      ident(name)
      const keys = Object.keys(params)
      keys.forEach(ident)
      const values = []
      const args = keys.map((k) => `${k} => ${bind(values, params[k])}`)
      const sql = `SELECT * FROM public.${name}(${args.join(', ')})`
      const res = await pool.query(sql, values)

      const shape = await rpcShape(name)

      if (shape === 'void') return { data: null, error: null }

      if (shape === 'scalar') {
        if (res.rows.length === 0) return { data: null, error: null }
        const only = Object.keys(res.rows[0])[0]
        return { data: res.rows[0][only] ?? null, error: null }
      }

      // Table / SETOF / composite-single: an array of rows, as supabase-js
      // returns for a set-returning function.
      return { data: res.rows, error: null }
    } catch (err) {
      return {
        data: null,
        error: { code: err.code, message: err.message, details: err.detail, hint: err.hint },
      }
    }
  }

  // -------------------------------------------------------------------------
  // Storage: emulated with a real table holding real bytes
  // -------------------------------------------------------------------------
  const storage = {
    from(bucket) {
      return {
        async upload(key, body, opts = {}) {
          try {
            const buf = Buffer.isBuffer(body) ? body : Buffer.from(body)
            const contentType = opts.contentType || 'application/octet-stream'
            // upsert:false must fail on an existing key, like real storage.
            const sql = opts.upsert
              ? `INSERT INTO public.test_only_storage_objects (bucket_id, name, data, content_type)
                 VALUES ($1,$2,$3,$4)
                 ON CONFLICT (bucket_id, name)
                 DO UPDATE SET data = EXCLUDED.data, content_type = EXCLUDED.content_type
                 RETURNING name`
              : `INSERT INTO public.test_only_storage_objects (bucket_id, name, data, content_type)
                 VALUES ($1,$2,$3,$4)
                 RETURNING name`
            const res = await pool.query(sql, [bucket, key, buf, contentType])
            return { data: { path: res.rows[0].name }, error: null }
          } catch (err) {
            return { data: null, error: { code: err.code, message: err.message } }
          }
        },

        async download(key) {
          try {
            const res = await pool.query(
              'SELECT data, content_type FROM public.test_only_storage_objects WHERE bucket_id = $1 AND name = $2',
              [bucket, key],
            )
            if (!res.rows.length) {
              return { data: null, error: { message: 'Object not found' } }
            }
            const row = res.rows[0]
            return { data: new Blob([row.data]), error: null }
          } catch (err) {
            return { data: null, error: { message: err.message } }
          }
        },

        async remove(keys) {
          try {
            const list = Array.isArray(keys) ? keys : [keys]
            const res = await pool.query(
              'DELETE FROM public.test_only_storage_objects WHERE bucket_id = $1 AND name = ANY($2::text[]) RETURNING name',
              [bucket, list],
            )
            return { data: res.rows, error: null }
          } catch (err) {
            return { data: null, error: { message: err.message } }
          }
        },

        getPublicUrl(key) {
          return { data: { publicUrl: `https://test.invalid/${bucket}/${key}` } }
        },
      }
    },
  }

  return {
    from,
    rpc,
    storage,
    // Exposed so tests can run raw SQL when they need to.
    __pool: pool,
  }
}
