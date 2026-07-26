package org.nuvok.nuvok

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Mantiene vivo el proceso de Nuvok para que la malla siga escuchando con la
 * app en segundo plano o cerrada.
 *
 * Por qué basta con esto: en Android, mientras el proceso viva, el motor Dart
 * sigue ejecutando el mesh y la notificación de SOS que ya está cableada se
 * dispara sola. El servicio no reimplementa nada del mesh — solo impide que
 * el sistema mate el proceso.
 *
 * Sin esto, un SOS de un vecino solo llega si el usuario tiene la app abierta,
 * que es justo cuando menos falta hace.
 */
class MeshForegroundService : Service() {

    companion object {
        private const val TAG = "NuvokMeshService"
        private const val CHANNEL_ID = "nuvok_mesh_bg"
        private const val NOTIFICATION_ID = 1911
        const val ACTION_STOP = "org.nuvok.nuvok.STOP_MESH_SERVICE"

        /** Preferencia compartida con Dart (interruptor en Ajustes). */
        const val PREFS = "nuvok_mesh_prefs"
        const val KEY_ENABLED = "mesh_background_enabled"

        fun start(context: Context) {
            val intent = Intent(context, MeshForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, MeshForegroundService::class.java))
        }

        fun isEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_ENABLED, true) // por defecto ON: app de emergencias

        fun setEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(KEY_ENABLED, enabled).apply()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.i(TAG, "Detenido por el usuario desde la notificación")
            setEnabled(this, false)
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, buildNotification())
        // START_STICKY: si el sistema nos mata por presión de memoria, que nos
        // reviva. En emergencias la continuidad importa más que la elegancia.
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Malla en segundo plano",
                // LOW: presencia discreta y sin sonido. La alerta ruidosa es la
                // del SOS, no ésta.
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Mantiene Nuvok escuchando SOS cercanos"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }

        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this, 1,
            Intent(this, MeshForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Nuvok · Malla activa")
            .setContentText("Escuchando SOS cercanos, sin internet")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(openApp)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(null, "Detener", stopIntent).build()
            )
            .build()
    }
}
