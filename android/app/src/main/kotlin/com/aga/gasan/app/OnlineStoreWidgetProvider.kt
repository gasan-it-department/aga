package com.aga.gasan.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

class OnlineStoreWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val ORDERS_KEY = "flutter.online_store_widget_new_orders"
        private const val MESSAGES_KEY = "flutter.online_store_widget_messages"
        private const val STORE_NAME_KEY = "flutter.online_store_widget_store_name"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, OnlineStoreWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach {
                updateWidget(context, manager, it)
            }
        }

        fun saveAndUpdate(
            context: Context,
            newOrders: Int,
            messages: Int,
            storeName: String
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putLong(ORDERS_KEY, newOrders.toLong())
                .putLong(MESSAGES_KEY, messages.toLong())
                .putString(STORE_NAME_KEY, storeName)
                .apply()
            updateAll(context)
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val orders = prefs.getLong(ORDERS_KEY, 0L)
            val messages = prefs.getLong(MESSAGES_KEY, 0L)
            val storeName = prefs.getString(STORE_NAME_KEY, "AGA Online Store")
                ?.takeIf { it.isNotBlank() }
                ?: "AGA Online Store"

            val views = RemoteViews(context.packageName, R.layout.online_store_widget)
            views.setTextViewText(R.id.widget_store_name, storeName)
            views.setTextViewText(R.id.widget_new_orders, orders.toString())
            views.setTextViewText(R.id.widget_messages, messages.toString())
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun openAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_seller_store", true)
            }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            return PendingIntent.getActivity(context, 4905, intent, flags)
        }
    }
}
