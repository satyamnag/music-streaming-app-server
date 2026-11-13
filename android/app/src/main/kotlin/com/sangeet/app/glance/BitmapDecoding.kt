package com.sangeet.app.glance

import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.BitmapFactory

/**
 * Bitmap decoding with downsampling.
 *
 * Play Console: *"Your app is using BitmapFactory without downsampling … loading
 * bitmaps at full resolution may lead to excessive memory usage … make sure that
 * you use `BitmapFactory.Options.inSampleSize` to downsample the image to the
 * required display size."*
 * (<https://developer.android.com/develop/ui/compose/graphics/images/optimization>)
 *
 * The app-widget cover art is drawn in a 50dp or 100dp square, but the files it
 * decodes are full-size album covers (1024px and up). Decoding one at full
 * resolution costs ~4 MB per 1024x1024 ARGB_8888 bitmap — for a 138px target
 * that is roughly 55x more memory than the widget can ever show, and the widget
 * keeps the previous bitmap alive while it animates.
 *
 * Both entry points below read the bounds first (`inJustDecodeBounds`), compute
 * the smallest power-of-two `inSampleSize` that still covers the target, and only
 * then decode. That is the two-pass pattern the Android documentation describes.
 */

/**
 * Smallest power-of-two sample size that keeps the decoded bitmap at or above the
 * requested size, so the image is never upscaled (never blurry) and never much
 * larger than needed.
 */
internal fun calculateInSampleSize(
    options: BitmapFactory.Options,
    reqWidthPx: Int,
    reqHeightPx: Int,
): Int {
    val height = options.outHeight
    val width = options.outWidth
    var inSampleSize = 1

    if (height > 0 && width > 0 && reqWidthPx > 0 && reqHeightPx > 0) {
        if (height > reqHeightPx || width > reqWidthPx) {
            val halfHeight = height / 2
            val halfWidth = width / 2
            // Halve until the result would fall below the requested size.
            while (halfHeight / inSampleSize >= reqHeightPx &&
                halfWidth / inSampleSize >= reqWidthPx
            ) {
                inSampleSize *= 2
            }
        }
    }
    return inSampleSize
}

/** Decodes [path] downsampled to at least [reqWidthPx] x [reqHeightPx]. */
internal fun decodeSampledBitmap(
    path: String,
    reqWidthPx: Int,
    reqHeightPx: Int,
): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

    val options = BitmapFactory.Options().apply {
        inSampleSize = calculateInSampleSize(bounds, reqWidthPx, reqHeightPx)
        inPreferredConfig = Bitmap.Config.ARGB_8888
    }
    return BitmapFactory.decodeFile(path, options)
}

/** Decodes a drawable resource downsampled to at least [reqWidthPx] x [reqHeightPx]. */
internal fun decodeSampledResource(
    resources: Resources,
    id: Int,
    reqWidthPx: Int,
    reqHeightPx: Int,
): Bitmap? {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeResource(resources, id, bounds)

    val options = BitmapFactory.Options().apply {
        inSampleSize = calculateInSampleSize(bounds, reqWidthPx, reqHeightPx)
    }
    return BitmapFactory.decodeResource(resources, id, options)
}
