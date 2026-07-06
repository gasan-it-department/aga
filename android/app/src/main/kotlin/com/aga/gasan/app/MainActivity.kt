package com.aga.gasan.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val batteryOptimizationChannel = "aga/battery_optimization"
    private val onlineStoreWidgetChannel = "aga/online_store_widget"
    private val weatherForecastWidgetChannel = "aga/weather_forecast_widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            batteryOptimizationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }

                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(isIgnoringBatteryOptimizations())
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            onlineStoreWidgetChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateStoreWidget" -> {
                    val newOrders = call.argument<Int>("new_orders") ?: 0
                    val messages = call.argument<Int>("messages") ?: 0
                    val storeName = call.argument<String>("store_name") ?: "AGA Online Store"
                    OnlineStoreWidgetProvider.saveAndUpdate(
                        this,
                        newOrders,
                        messages,
                        storeName
                    )
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            weatherForecastWidgetChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWeatherForecastWidget" -> {
                    val temp = call.argument<Int>("temp") ?: 0
                    val feelsLike = call.argument<Int>("feels_like") ?: 0
                    val humidity = call.argument<Int>("humidity") ?: 0
                    val windSpeed = call.argument<Double>("wind_speed") ?: 0.0
                    val condition = call.argument<String>("condition") ?: "Weather"
                    val location = call.argument<String>("location") ?: "Near Gasan"
                    val forecast = call.argument<String>("forecast") ?: "Forecast updates when AGA opens."
                    WeatherForecastWidgetProvider.saveAndUpdate(
                        this,
                        temp,
                        feelsLike,
                        humidity,
                        windSpeed,
                        condition,
                        location,
                        forecast
                    )
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (isIgnoringBatteryOptimizations()) return

        val requestIntent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }

        if (requestIntent.resolveActivity(packageManager) != null) {
            startActivity(requestIntent)
            return
        }

        val settingsIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        if (settingsIntent.resolveActivity(packageManager) != null) {
            startActivity(settingsIntent)
        }
    }
}
