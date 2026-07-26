package org.nuvok.nuvok

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Tras reiniciar el teléfono, vuelve a levantar la malla — pero SOLO si el
 * usuario dejó activado el interruptor de segundo plano.
 *
 * Importa porque los reinicios ocurren justo en el peor momento: batería que
 * se agotó, actualización del sistema de madrugada. Sin esto, el teléfono
 * queda sordo a los SOS hasta que alguien recuerde abrir la app.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }
        if (!MeshForegroundService.isEnabled(context)) {
            Log.i("NuvokBoot", "Segundo plano desactivado por el usuario — no se inicia")
            return
        }
        Log.i("NuvokBoot", "Reinicio detectado: levantando la malla")
        MeshForegroundService.start(context)
    }
}
