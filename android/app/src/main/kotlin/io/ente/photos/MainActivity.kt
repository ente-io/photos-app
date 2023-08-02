package io.ente.photos

import android.appwidget.AppWidgetManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

open class MainActivity: FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val id= intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,0)
        Handler(Looper.getMainLooper()).postDelayed({
            MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger!!,"io.ente.app").invokeMethod("config",id)
        }, 0)
    }

}
