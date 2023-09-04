package io.ente.photos


import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.*
import android.net.Uri
import android.util.Base64
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.RemoteViews
import androidx.core.content.edit
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.ByteArrayOutputStream

class HomeScreenWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_screen_widget).apply {

                widgetData.edit {
                    this.putInt("widget_id",widgetId)
                    this.putInt("widget_size",appWidgetIds.size)
                }

                val collection = widgetData.getString("${widgetId}_collection","")
                val type = widgetData.getInt("${widgetId}_type",0)
                val thumbnailID = widgetData.getInt("${widgetId}_thumbnail_id",0)
                val isRemote = widgetData.getBoolean("${widgetId}_remote",false)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    uri = Uri.parse("homescreenwidget://view?type=$type&id=$thumbnailID&collection=$collection&remote=$isRemote")
                )

                setOnClickPendingIntent(R.id.thumbnail, pendingIntent)

                val shape = widgetData.getInt("${widgetId}_shape", 0)

                val thumbnailString = widgetData.getString(
                    "${widgetId}_thumbnail",
                    context.getText(R.string.default_thumbnail).toString()
                )!!

                var thumbnailBitmap: Bitmap = base64ToBitmap(thumbnailString)!!

                val inflater: LayoutInflater =
                    context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
                    
                val layoutView: ViewGroup = inflater.inflate(layoutId, null) as ViewGroup
                layoutView.layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT
                )

                val measuredWidthSpec: Int =
                    View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
                val measuredHeightSpec: Int =
                    View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED)
                layoutView.measure(measuredWidthSpec, measuredHeightSpec)

                val width: Int = layoutView.measuredWidth
                val height: Int = layoutView.measuredHeight

                val size = width.coerceAtLeast(height)
                if (shape == 1) {
                    thumbnailBitmap = createCircularBitmap(
                        thumbnailBitmap,

                    )
                } else if (shape == 2) {
                    thumbnailBitmap = createHeartShapedBitmap(
                        thumbnailBitmap,
                        size
                    )
                }

                setImageViewBitmap(R.id.thumbnail, thumbnailBitmap)

            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }


private fun base64ToBitmap(base64String: String): Bitmap? {
    val base64Image = if (base64String.startsWith("data")) {
        base64String.substring(base64String.indexOf(",") + 1)
    } else {
        base64String
    }
    val imageBytes = Base64.decode(base64Image, Base64.DEFAULT)

    val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

    if (bitmap.byteCount > maxSizeBytes) {
        val compressedBitmap = compressBitmap(bitmap)
        bitmap.recycle()
        return compressedBitmap
    }

    return bitmap
}

private fun compressBitmap(bitmap: Bitmap): Bitmap {
    var quality = 100
    val stream = ByteArrayOutputStream()

    do {
        stream.reset()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
        quality -= 2
    } while (stream.toByteArray().size > maxSizeBytes && quality > 0)

    val compressedImageBytes = stream.toByteArray()
    stream.close()

    return BitmapFactory.decodeByteArray(compressedImageBytes, 0, compressedImageBytes.size)
}

    private fun createCircularBitmap(bitmap: Bitmap): Bitmap {
        val size = bitmap.width.coerceAtLeast(bitmap.height).coerceAtMost(1000)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)

        val canvas = Canvas(output)
        val paint = Paint()

        val shader = BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())

        paint.isAntiAlias = true
        paint.shader = shader
        canvas.drawRoundRect(rect, size.toFloat() / 2, size.toFloat() / 2, paint)

        return output
    }

    private fun createHeartShapedBitmap(bitmap: Bitmap, canvasSize: Int): Bitmap {
        val size = bitmap.width.coerceAtLeast(bitmap.height).coerceAtMost(1000)
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)

        val canvas = Canvas(output)
        val path = Path()

        val centerX = size / 2f
        val centerY = size / 2f
        val radius = size / 2f
        path.moveTo(centerX, centerY + radius * 0.15f)
        path.cubicTo(
            0f, -0.25f,
            centerX - radius * 1.25f, centerY + radius * 0.6f,
            centerX, centerY + radius
        )
        path.moveTo(centerX, centerY + radius * 0.15f)
        path.cubicTo(
            centerX + radius, 1 * 0.25f,
            centerX + radius * 1.25f, centerY + radius * 0.6f,
            centerX, centerY + radius
        )
        path.close()

        val paint = Paint()
        paint.isAntiAlias = true
        paint.color = Color.BLACK

        canvas.drawPath(path, paint)

        val bitmapWidth = bitmap.width
        val bitmapHeight = bitmap.height
        val scale = radius * 2 / size

        val matrix = Matrix()
        matrix.postScale(scale, scale)
        val scaledBitmap = Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmapWidth,
            bitmapHeight,
            matrix,
            true
        )

        val left = (centerX - scaledBitmap.width / 2f).toInt()
        val top = (centerY - scaledBitmap.height / 2f).toInt()

        canvas.clipPath(path)
        canvas.drawBitmap(scaledBitmap, left.toFloat(), top.toFloat(), null)

        return output
    }

    companion object {
        const val maxSizeBytes: Long = 6739200
    }
}