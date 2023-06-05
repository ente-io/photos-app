package io.ente.photos

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class HomeScreenWidget : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_screen_widget).apply {
                // Open App on Widget Click
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("homeWidgetExample://titleClicked")
                )
                setOnClickPendingIntent(R.id.thumbnail, backgroundIntent)
                // Swap Title Text by calling Dart Code in the Background
                val thumbnail = widgetData.getString("thumbnail","")!!
                setImageViewBitmap(R.id.thumbnail, base64ToBitmap(thumbnail))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun base64ToBitmap(base64String: String): Bitmap? {
        // Remove data prefix from the Base64 string if present
        val base64Image = if (base64String.startsWith("data")) {
            base64String.substring(base64String.indexOf(",") + 1)
        } else {
            base64String
        }
        // Decode the Base64 string into a byte array
        val imageBytes = Base64.decode(base64Image, Base64.DEFAULT)

        // Decode the byte array into a Bitmap
        return BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
    }
}