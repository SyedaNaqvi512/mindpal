package com.example.mindpal

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's activity. Besides hosting Flutter it carries the small bridge to
 * the home-screen widget (channel "mindpal/widget"):
 *  - setDays(days): the app saves the writing-day count for the widget and
 *    redraws it. days = 0 (or less) clears it.
 *  - takePending(): returns the mood (0 to 5) that a widget tap asked for,
 *    once, then forgets it. 0 means "open a blank new entry".
 *  - The activity calls "widgetAction" on Flutter when a tap arrives while
 *    the app is already running.
 */
class MainActivity : FlutterFragmentActivity() {

    private var channel: MethodChannel? = null
    private var pendingMood: Int = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (readWidgetIntent(intent)) {
            channel?.invokeMethod("widgetAction", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mindpal/widget")
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setDays" -> {
                    val days = call.argument<Int>("days") ?: 0
                    getSharedPreferences(MindPalWidget.PREFS, MODE_PRIVATE)
                        .edit()
                        .putInt(MindPalWidget.KEY_DAYS, if (days < 0) 0 else days)
                        .apply()
                    MindPalWidget.refreshAll(applicationContext)
                    result.success(null)
                }
                "takePending" -> {
                    val mood = pendingMood
                    pendingMood = -1
                    result.success(if (mood >= 0) mood else null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** Remembers a widget tap. Returns true when the intent carried one. */
    private fun readWidgetIntent(intent: Intent?): Boolean {
        if (intent == null || !intent.hasExtra(MindPalWidget.EXTRA_MOOD)) return false
        val mood = intent.getIntExtra(MindPalWidget.EXTRA_MOOD, -1)
        // Remove it, so that it is not used again if the activity is recreated.
        intent.removeExtra(MindPalWidget.EXTRA_MOOD)
        if (mood < 0 || mood > 5) return false
        pendingMood = mood
        return true
    }
}
