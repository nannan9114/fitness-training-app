package com.megumin.fitness_training_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.megumin.fitness_training_app/rest_timer"
        private const val OLD_NOTIFICATION_CHANNEL = "rest_timer"
        private const val NOTIFICATION_CHANNEL = "rest_timer_no_badge"
        private const val NOTIFICATION_ID = 4101
        private const val NOTIFICATION_PERMISSION_REQUEST = 4102
    }

    private var pendingStartedAt: Long? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val startedAt = call.argument<Number>("startedAt")?.toLong()
                        if (startedAt == null) {
                            result.error("invalid_started_at", "Missing rest start time", null)
                        } else {
                            startRestTimer(startedAt)
                            result.success(null)
                        }
                    }
                    "stop" -> {
                        notificationManager().cancel(NOTIFICATION_ID)
                        pendingStartedAt = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startRestTimer(startedAt: Long) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            pendingStartedAt = startedAt
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
            return
        }
        showRestTimer(startedAt)
    }

    private fun showRestTimer(startedAt: Long) {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val elapsedRealtimeStartedAt =
            SystemClock.elapsedRealtime() - (System.currentTimeMillis() - startedAt)
        val timerView = RemoteViews(packageName, R.layout.notification_rest_timer).apply {
            setChronometer(
                R.id.rest_timer_chronometer,
                elapsedRealtimeStartedAt,
                null,
                true,
            )
        }
        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL)
        builder
            .setSmallIcon(R.drawable.ic_timer_notification)
            .setCustomContentView(timerView)
            .setCustomBigContentView(timerView)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setContentIntent(pendingIntent)
            .setColor(Color.rgb(166, 90, 62))
            .setShowWhen(false)
            .setUsesChronometer(false)
            .setChronometerCountDown(false)
            .setOngoing(true)
            .setRequestPromotedOngoing(true)
            .setBadgeIconType(NotificationCompat.BADGE_ICON_NONE)
            .setOnlyAlertOnce(true)
            .setAutoCancel(false)

        notificationManager().notify(NOTIFICATION_ID, builder.build())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        notificationManager().deleteNotificationChannel(OLD_NOTIFICATION_CHANNEL)
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL,
            "组间休息计时",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "在状态栏显示当前组间休息时长"
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST &&
            grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        ) {
            pendingStartedAt?.let(::showRestTimer)
        }
        pendingStartedAt = null
    }
}
