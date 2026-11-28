package com.example.mindpal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * The MindPal home-screen widget: a greeting, five mood buttons and a gentle
 * count of writing days. It never shows journal text. The only data it reads
 * is a whole number (days of writing) that the app saves for it.
 *
 * Tapping a mood opens the app on a new entry with that mood chosen (1 to 5);
 * "Write" opens a blank new entry (0). The app lock still applies, because
 * the app opens as usual and the lock screen covers it.
 */
class MindPalWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, build(context))
        }
    }

    companion object {
        const val PREFS = "mindpal_widget"
        const val KEY_DAYS = "days"
        const val EXTRA_MOOD = "mindpal_widget_mood"

        private val moodButtons = intArrayOf(
            R.id.widget_mood_1,
            R.id.widget_mood_2,
            R.id.widget_mood_3,
            R.id.widget_mood_4,
            R.id.widget_mood_5,
        )

        private fun openApp(context: Context, mood: Int): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.mindpal.WIDGET_OPEN"
                // A different address per button keeps the six pending intents apart.
                data = Uri.parse("mindpal://widget/mood/$mood")
                putExtra(EXTRA_MOOD, mood)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context,
                mood,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.mindpal_widget)
            val days = context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getInt(KEY_DAYS, 0)
            val line = if (days > 0) {
                context.resources.getQuantityString(R.plurals.widget_days, days, days)
            } else {
                context.getString(R.string.widget_calm_line)
            }
            views.setTextViewText(R.id.widget_line, line)
            views.setOnClickPendingIntent(R.id.widget_write, openApp(context, 0))
            for ((index, viewId) in moodButtons.withIndex()) {
                views.setOnClickPendingIntent(viewId, openApp(context, index + 1))
            }
            return views
        }

        /** Redraws every MindPal widget on the home screen. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MindPalWidget::class.java))
            for (id in ids) {
                manager.updateAppWidget(id, build(context))
            }
        }
    }
}
