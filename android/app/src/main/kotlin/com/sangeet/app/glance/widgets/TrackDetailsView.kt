package com.sangeet.app.glance.widgets

import android.graphics.Bitmap
import android.net.Uri
import android.util.Log
import kotlin.math.roundToInt
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.appwidget.cornerRadius
import androidx.glance.layout.Alignment
import androidx.glance.layout.Row
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Spacer
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.sangeet.app.glance.Breakpoints
import com.sangeet.app.glance.decodeSampledBitmap
import com.sangeet.app.glance.decodeSampledResource
import com.sangeet.app.glance.models.Track

@Composable
fun TrackDetailsView(activeTrack: Track?) {
    val context = LocalContext.current

    val size = LocalSize.current

    val artistStr = activeTrack?.artists?.map { it.name }?.joinToString(", ") ?: "<No Artist>"
    val imgLocalPath = activeTrack?.album?.images?.get(0)?.path;
    val title = activeTrack?.name ?: "<No Track>"

    // The cover is drawn in a 50dp or 100dp square, so decode it at that size in
    // pixels instead of pulling a full-resolution (often 1024px+) cover into
    // memory - Play Console flags BitmapFactory calls that skip inSampleSize.
    val targetDp = if (size.height < 200.dp) 50.dp else 100.dp
    val targetPx = (targetDp.value * context.resources.displayMetrics.density)
        .roundToInt()
        .coerceAtLeast(1)

    val fallbackIcon =
        decodeSampledResource(
            context.resources,
            android.R.drawable.ic_delete,
            targetPx,
            targetPx,
        ) ?: Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)

    val cover =
        imgLocalPath?.let { decodeSampledBitmap(it, targetPx, targetPx) } ?: fallbackIcon

    Image(
        provider = ImageProvider(cover),
        contentDescription = "Album Art",
        modifier = GlanceModifier.cornerRadius(8.dp)
            .size(targetDp),
        contentScale = ContentScale.Fit
    )
    Spacer(modifier = GlanceModifier.size(6.dp))
    Column {
        Text(
            text = title,
            style = TextStyle(
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = GlanceTheme.colors.onBackground
            ),
        )
        if (size != Breakpoints.SMALL_SQUARE) {
            Spacer(modifier = GlanceModifier.size(6.dp))
            Text(
                text = artistStr,
                style = TextStyle(
                    fontSize = 14.sp,
                    color = GlanceTheme.colors.onBackground
                ),
            )
        }
    }
}