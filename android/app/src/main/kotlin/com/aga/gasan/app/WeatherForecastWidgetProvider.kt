package com.aga.gasan.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class WeatherForecastWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, WeatherForecastWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
        }

        fun saveAndUpdate(
            context: Context,
            temp: Int,
            feelsLike: Int,
            humidity: Int,
            windSpeed: Double,
            condition: String,
            location: String,
            forecast: String
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong("flutter.weather_widget_temp", temp.toLong())
                .putLong("flutter.weather_widget_feels_like", feelsLike.toLong())
                .putLong("flutter.weather_widget_humidity", humidity.toLong())
                .putFloat("flutter.weather_widget_wind_speed", windSpeed.toFloat())
                .putString("flutter.weather_widget_condition", condition)
                .putString("flutter.weather_widget_location", location)
                .putString("flutter.weather_widget_forecast", forecast)
                .apply()
            updateAll(context)
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val temp = prefs.getLong("flutter.weather_widget_temp", Long.MIN_VALUE)
            val feelsLike = prefs.getLong("flutter.weather_widget_feels_like", Long.MIN_VALUE)
            val humidity = prefs.getLong("flutter.weather_widget_humidity", Long.MIN_VALUE)
            val windSpeed = prefs.getFloat("flutter.weather_widget_wind_speed", -1f)
            val condition = prefs.getString("flutter.weather_widget_condition", "Weather")
                ?.takeIf { it.isNotBlank() } ?: "Weather"
            val location = prefs.getString("flutter.weather_widget_location", "Near Gasan")
                ?.takeIf { it.isNotBlank() } ?: "Near Gasan"
            val forecast = prefs.getString(
                "flutter.weather_widget_forecast",
                "Forecast updates when AGA opens."
            )?.takeIf { it.isNotBlank() } ?: "Forecast updates when AGA opens."

            val views = RemoteViews(context.packageName, R.layout.weather_forecast_widget)
            views.setTextViewText(
                R.id.weather_widget_temp,
                if (temp == Long.MIN_VALUE) "--°" else "${temp}°"
            )
            views.setTextViewText(R.id.weather_widget_location, location)
            views.setTextViewText(R.id.weather_widget_condition, condition)
            views.setTextViewText(R.id.weather_widget_forecast, forecast.replaceFirstChar { it.uppercase() })
            views.setTextViewText(
                R.id.weather_widget_metrics,
                "Feels ${if (feelsLike == Long.MIN_VALUE) "--" else feelsLike}° · Humidity ${if (humidity == Long.MIN_VALUE) "--" else humidity}% · Wind ${if (windSpeed < 0) "--" else String.format("%.1f", windSpeed)} m/s"
            )
            views.setOnClickPendingIntent(R.id.weather_widget_root, openAppIntent(context))
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun openAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_weather_forecast", true)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getActivity(context, 4907, intent, flags)
        }
    }
}
