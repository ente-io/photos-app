package io.ente.photos

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.*
import android.net.Uri
import android.util.Base64
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.RemoteViews
import androidx.core.content.edit
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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
            Log.d("APPWIDGET",widgetId.toString())
            val views = RemoteViews(context.packageName, R.layout.home_screen_widget).apply {
                // Open App on Widget Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    uri = Uri.parse("homescreenwidget://configure")
                )

                setOnClickPendingIntent(R.id.edit, pendingIntent)

                widgetData.edit {
                    this.putInt("widget_id",widgetId)
                }

                val collection = widgetData.getString("${widgetId}_collection","-1")
                val type = widgetData.getInt("${widgetId}_type",0)
                val thumbnailID = widgetData.getInt("${widgetId}_thumbnail_id",0)
                val pendingIntent2 = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    uri = Uri.parse("homescreenwidget://view?type=$type&id=$thumbnailID&collection=$collection")
                )

                setOnClickPendingIntent(R.id.thumbnail, pendingIntent2)
                // Swap Title Text by calling Dart Code in the Background
                val shape = widgetData.getInt("${widgetId}_shape", 0)

                // Pending intent to update counter on button click
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
                    Uri.parse("homescreenwidget://refresh"))
                setOnClickPendingIntent(R.id.refresh, backgroundIntent)

                val thumbnailString = widgetData.getString(
                    "${widgetId}_thumbnail",
                    context.getText(R.string.default_thumbnail).toString()
                )!!
                var thumbnailBitmap: Bitmap = base64ToBitmap(thumbnailString,67392)!!
                
                // Inflate the layout to measure its dimensions
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
                        size
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

  
private fun base64ToBitmap(base64String: String, maxSizeBytes: Long): Bitmap? {
    // Remove data prefix from the Base64 string if present
    val base64Image = if (base64String.startsWith("data")) {
        base64String.substring(base64String.indexOf(",") + 1)
    } else {
        base64String
    }
    // Decode the Base64 string into a byte array
    val imageBytes = Base64.decode(base64Image, Base64.DEFAULT)

    // Decode the byte array into a Bitmap
    val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)

    // Compress the bitmap if its size exceeds the maximum allowed limit
    if (bitmap.byteCount > maxSizeBytes) {
        val compressedBitmap = compressBitmap(bitmap, maxSizeBytes)
        bitmap.recycle() // Release the original bitmap from memory
        return compressedBitmap
    }

    return bitmap
}

private fun compressBitmap(bitmap: Bitmap, maxSizeBytes: Long): Bitmap {
    var compressedBitmap = bitmap
    var quality = 100
    val stream = ByteArrayOutputStream()

    do {
        stream.reset()
        compressedBitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
        quality -= 10
    } while (stream.toByteArray().size > maxSizeBytes && quality > 0)

    val compressedImageBytes = stream.toByteArray()
    stream.close()

    return BitmapFactory.decodeByteArray(compressedImageBytes, 0, compressedImageBytes.size)
}

    private fun createCircularBitmap(bitmap: Bitmap, canvasSize: Int): Bitmap {
        // Create a circular bitmap with the given size
        val output = Bitmap.createBitmap(canvasSize, canvasSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        // Create a circular path
        val path = Path()
        val centerX = canvasSize / 2f
        val centerY = canvasSize / 2f
        val radius = canvasSize / 2f
        path.addCircle(centerX, centerY, radius, Path.Direction.CW)
        val paint = Paint();
        paint.color = Color.BLACK;
        canvas.drawPath(path,paint)

        // Calculate the positioning of the bitmap within the heart
        val bitmapWidth = bitmap.width
        val bitmapHeight = bitmap.height
        val scale = radius * 2 / bitmapWidth.coerceAtLeast(bitmapHeight)
        val scaledWidth = (bitmapWidth * scale).toInt()
        val scaledHeight = (bitmapHeight * scale).toInt()
        val left = (centerX - scaledWidth / 2f).toInt()
        val top = (centerY - scaledHeight / 2f).toInt()

        canvas.clipPath(path)
        canvas.drawBitmap(
            bitmap,
            null,
            Rect(left, top, left + scaledWidth, top + scaledHeight),
            null
        )
        return output
    }

    private fun createHeartShapedBitmap(bitmap: Bitmap, canvasSize: Int): Bitmap {
        // Create a heart-shaped bitmap with the given size
        val output = Bitmap.createBitmap(canvasSize, canvasSize, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        // Create a heart-shaped path
        val path = Path()
        val centerX = canvasSize / 2f
        val centerY = canvasSize / 2f
        val radius = canvasSize / 2f
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

        val paint = Paint();
        paint.color = Color.BLACK;
        canvas.drawPath(path,paint)

        // Calculate the positioning of the bitmap within the heart
        val bitmapWidth = bitmap.width
        val bitmapHeight = bitmap.height
        val scale = radius * 2 / bitmapWidth.coerceAtLeast(bitmapHeight)
        val scaledWidth = (bitmapWidth * scale).toInt()
        val scaledHeight = (bitmapHeight * scale).toInt()
        val left = (centerX - scaledWidth / 2f).toInt()
        val top = (centerY - scaledHeight / 2f).toInt()

        canvas.clipPath(path)
        canvas.drawBitmap(
            bitmap,
            null,
            Rect(left, top, left + scaledWidth, top + scaledHeight),
            null
        )


        return output
    }

}