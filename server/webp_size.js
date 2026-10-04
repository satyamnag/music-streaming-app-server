// Minimal WebP dimension reader — no image dependency required.
//
// The admin panel accepts landscape banners STRICTLY as WebP at a fixed aspect
// ratio. Enforcing that server-side (not just in the browser) means the rule
// holds even if the API is called directly, and it needs only the file header,
// so the whole image never has to be decoded.
//
// Supports the three WebP container layouts:
//   * 'VP8 ' — lossy  (simple lossy bitstream)
//   * 'VP8L' — lossless
//   * 'VP8X' — extended (used when there is alpha/animation/metadata)
//
// Returns { width, height } or null when the buffer is not a readable WebP.

/** Reads the intrinsic size of a WebP buffer, or null if unrecognized. */
export function readWebpSize(buffer) {
  if (!buffer || buffer.length < 30) return null

  // RIFF....WEBP
  const isRiff = buffer.toString('ascii', 0, 4) === 'RIFF'
  const isWebp = buffer.toString('ascii', 8, 12) === 'WEBP'
  if (!isRiff || !isWebp) return null

  const chunk = buffer.toString('ascii', 12, 16)

  if (chunk === 'VP8 ') {
    // Lossy: after the 3-byte frame tag + 3-byte sync code (0x9d 0x01 0x2a)
    // comes a 16-bit width and 16-bit height, both 14-bit values.
    // Layout: [4]chunk [4]size [3]frameTag [3]syncCode [2]w [2]h
    const sync = buffer.subarray(23, 26)
    if (!(sync[0] === 0x9d && sync[1] === 0x01 && sync[2] === 0x2a)) return null
    const width = buffer.readUInt16LE(26) & 0x3fff
    const height = buffer.readUInt16LE(28) & 0x3fff
    return width && height ? { width, height } : null
  }

  if (chunk === 'VP8L') {
    // Lossless: [4]chunk [4]size [1]signature(0x2f) then 14-bit width-1 and
    // 14-bit height-1 packed into 4 bytes.
    if (buffer[20] !== 0x2f) return null
    const bits = buffer.readUInt32LE(21)
    const width = (bits & 0x3fff) + 1
    const height = ((bits >> 14) & 0x3fff) + 1
    return width && height ? { width, height } : null
  }

  if (chunk === 'VP8X') {
    // Extended: canvas width-1 and height-1 as 24-bit little-endian values.
    // Layout: [4]chunk [4]size [4]flags [3]width-1 [3]height-1
    const width = (buffer[24] | (buffer[25] << 8) | (buffer[26] << 16)) + 1
    const height = (buffer[27] | (buffer[28] << 8) | (buffer[29] << 16)) + 1
    return width && height ? { width, height } : null
  }

  return null
}

/**
 * Whether [size] matches [targetRatio] within [tolerance].
 *
 * A small tolerance absorbs the rounding real encoders introduce (e.g. an
 * 8:3 banner exported as 1440x540 or 1200x450 both land within 1%); it is far
 * tighter than any visibly different shape, so it cannot admit a 16:9 image.
 */
export function matchesAspectRatio(size, targetRatio, tolerance = 0.02) {
  if (!size || !size.width || !size.height) return false
  const actual = size.width / size.height
  return Math.abs(actual - targetRatio) / targetRatio <= tolerance
}

/**
 * Whether [size]'s aspect ratio falls inside [minRatio]..[maxRatio], inclusive.
 *
 * Used for the home wallpaper, which the app draws as a landscape band across
 * the top of the home screen rather than as a full-screen cover. A band crops so
 * forgivingly that pinning one exact ratio would reject artwork for no visible
 * benefit, so the rule is "landscape, within a sensible range" (1.3:1 to 3.2:1
 * — 4:3 through wider than 3:1) instead.
 */
export function matchesAspectRatioRange(size, minRatio, maxRatio) {
  if (!size || !size.width || !size.height) return false
  const actual = size.width / size.height
  return actual >= minRatio && actual <= maxRatio
}
