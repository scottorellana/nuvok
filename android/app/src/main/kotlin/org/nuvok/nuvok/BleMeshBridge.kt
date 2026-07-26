package org.nuvok.nuvok

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Android-native BLE bridge for Nuvok Mesh.
 *
 * flutter_blue_plus can scan/connect as a central, but it cannot make this app
 * advertise a GATT service. Phone-to-phone BLE needs both halves: each device
 * advertises + serves a writable characteristic, and also scans/connects to the
 * peer's service. This bridge exposes that full-duplex radio path to Dart.
 */
class BleMeshBridge(
    private val activity: FlutterActivity,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val REQUEST_CODE = 7742
        private val SERVICE_UUID: UUID = UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
        private val TX_UUID: UUID = UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")
        private val RX_UUID: UUID = UUID.fromString("0000ffe2-0000-1000-8000-00805f9b34fb")
        // Client Characteristic Configuration Descriptor: without it a central
        // (e.g. an iPhone) cannot enable notifications on RX and its connect
        // fails outright.
        private val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var pendingStartResult: MethodChannel.Result? = null

    private val bluetoothManager: BluetoothManager?
        get() = activity.applicationContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager

    private var gattServer: BluetoothGattServer? = null
    private var serverRx: BluetoothGattCharacteristic? = null
    private var advertising = false
    private var scanning = false

    // Política de energía (la fija Dart con setPowerMode). Por defecto
    // "balanced": nunca arrancamos a máxima potencia sin saber la batería.
    private var powerMode = "balanced"
    private var dutyOnMs = 3000
    private var dutyOffMs = 2000
    private var dutyRunnable = Runnable {}
    private val peers = ConcurrentHashMap<String, PeerState>()

    // Centrals subscribed to our RX characteristic. This is the return path
    // to devices we cannot connect back to as a central (an iPhone doesn't
    // advertise a connectable address): we answer them with notifications.
    private val subscribedCentrals = ConcurrentHashMap<String, BluetoothDevice>()

    // Estado del adaptador en vivo (usuario apaga/enciende BT con la app
    // abierta) → eventos {type:'state'} para TransportHealth en Dart, Y
    // auto-recuperación: al volver STATE_ON las radios se relanzan solas —
    // un ciclo del adaptador invalida scanner/advertiser/GATT server, y el
    // asistente le pide al usuario exactamente "enciende Bluetooth", así que
    // obedecerlo TIENE que revivir el mesh sin reiniciar la app.
    private val btStateReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(c: Context?, i: android.content.Intent?) {
            when (i?.getIntExtra(android.bluetooth.BluetoothAdapter.EXTRA_STATE, -1)) {
                android.bluetooth.BluetoothAdapter.STATE_ON -> {
                    emit(mapOf("type" to "state", "value" to "on"))
                    if (radiosWanted && hasRuntimePermissions()) {
                        main.post { startRadios() }
                    }
                }
                android.bluetooth.BluetoothAdapter.STATE_OFF -> {
                    emit(mapOf("type" to "state", "value" to "off"))
                    // Los objetos de radio quedaron inválidos; resetear los
                    // flags para que startRadios() no haga early-return con
                    // estado fantasma cuando el adaptador vuelva.
                    resetRadiosAfterAdapterOff()
                }
            }
        }
    }
    private var btReceiverRegistered = false

    // True desde que el mesh pidió radios y hasta stop(): el receiver lo usa
    // para saber si debe relanzarlas cuando el usuario enciende Bluetooth.
    @Volatile private var radiosWanted = false

    private fun registerBtReceiverOnce() {
        if (btReceiverRegistered) return
        activity.registerReceiver(
            btStateReceiver,
            android.content.IntentFilter(
                android.bluetooth.BluetoothAdapter.ACTION_STATE_CHANGED,
            ),
        )
        btReceiverRegistered = true
    }

    @SuppressLint("MissingPermission")
    private fun resetRadiosAfterAdapterOff() {
        scanning = false
        advertising = false
        try {
            gattServer?.close()
        } catch (_: Throwable) {}
        gattServer = null
        serverRx = null
        for (state in peers.values) {
            try {
                state.gatt?.close()
            } catch (_: Throwable) {}
        }
        peers.clear()
        subscribedCentrals.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(result)
            "stop" -> {
                stop()
                result.success(true)
            }
            "setPowerMode" -> {
                applyPowerMode(
                    call.argument<String>("mode") ?: "balanced",
                    call.argument<Int>("onMs") ?: 3000,
                    call.argument<Int>("offMs") ?: 2000,
                )
                result.success(true)
            }
            "connect" -> {
                val id = call.argument<String>("id")
                result.success(if (id.isNullOrBlank()) false else connect(id))
            }
            "disconnect" -> {
                call.argument<String>("id")?.let { disconnect(it) }
                result.success(true)
            }
            "send" -> {
                val id = call.argument<String>("id")
                val bytes = call.argument<ByteArray>("bytes")
                result.success(if (id.isNullOrBlank() || bytes == null) false else queueSend(id, bytes))
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun start(result: MethodChannel.Result) {
        radiosWanted = true
        if (!hasBleHardware()) {
            // Distinguir "no hay adaptador" (irreparable) de "está apagado"
            // (accionable): el asistente da instrucciones distintas.
            val adapter = bluetoothManager?.adapter
            // Registrar el receiver AUNQUE Bluetooth esté apagado: si no,
            // encenderlo después no emite ningún evento y el paso del
            // asistente nunca se limpia.
            if (adapter != null) registerBtReceiverOnce()
            emit(mapOf("type" to "state",
                "value" to if (adapter == null) "unsupported" else "off"))
            result.success(false)
            return
        }
        registerBtReceiverOnce()
        if (!hasRuntimePermissions()) {
            pendingStartResult = result
            ActivityCompat.requestPermissions(activity, missingRuntimePermissions(), REQUEST_CODE)
            return
        }
        result.success(startRadios())
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        if (!granted) emit(mapOf("type" to "state", "value" to "unauthorized"))
        val result = pendingStartResult
        pendingStartResult = null
        result?.success(if (granted) startRadios() else false)
        return true
    }

    private fun hasBleHardware(): Boolean {
        val adapter = bluetoothManager?.adapter ?: return false
        return adapter.isEnabled
    }

    private fun requiredRuntimePermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun missingRuntimePermissions(): Array<String> = requiredRuntimePermissions()
        .filter { ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED }
        .toTypedArray()

    private fun hasRuntimePermissions(): Boolean = missingRuntimePermissions().isEmpty()

    @SuppressLint("MissingPermission")
    private fun startRadios(): Boolean {
        val manager = bluetoothManager ?: return false
        val adapter = manager.adapter ?: return false
        if (!adapter.isEnabled) return false

        startGattServer(manager)
        startAdvertising(adapter)
        startScanning(adapter)
        emit(mapOf("type" to "state", "value" to "on"))
        registerBtReceiverOnce()
        // Scanner-only still helps if another device is advertising. GATT server
        // without advertiser is useful once a peer already knows our address.
        return gattServer != null || advertising || scanning
    }

    @SuppressLint("MissingPermission")
    private fun startGattServer(manager: BluetoothManager) {
        if (gattServer != null) return
        val server = manager.openGattServer(activity.applicationContext, serverCallback) ?: return
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val tx = BluetoothGattCharacteristic(
            TX_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
        )
        val rx = BluetoothGattCharacteristic(
            RX_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
        )
        rx.addDescriptor(
            android.bluetooth.BluetoothGattDescriptor(
                CCCD_UUID,
                android.bluetooth.BluetoothGattDescriptor.PERMISSION_READ or
                    android.bluetooth.BluetoothGattDescriptor.PERMISSION_WRITE,
            ),
        )
        service.addCharacteristic(tx)
        service.addCharacteristic(rx)
        server.addService(service)
        serverRx = rx
        gattServer = server
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising(adapter: android.bluetooth.BluetoothAdapter) {
        if (advertising) return
        val advertiser = adapter.bluetoothLeAdvertiser ?: return
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()
        try {
            advertiser.startAdvertising(settings, data, advertiseCallback)
            advertising = true
        } catch (_: Throwable) {
            advertising = false
        }
    }

    @SuppressLint("MissingPermission")
    private fun startScanning(adapter: android.bluetooth.BluetoothAdapter) {
        if (scanning) return
        val scanner = adapter.bluetoothLeScanner ?: return
        val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build()
        val settings = ScanSettings.Builder()
            .setScanMode(androidScanMode())
            .build()
        try {
            scanner.startScan(listOf(filter), settings, scanCallback)
            scanning = true
            scheduleDutyCycle(adapter)
        } catch (_: Throwable) {
            scanning = false
        }
    }

    /** Modo de escaneo según la política de energía que fija Dart. */
    private fun androidScanMode(): Int = when (powerMode) {
        "performance" -> ScanSettings.SCAN_MODE_LOW_LATENCY
        "balanced" -> ScanSettings.SCAN_MODE_BALANCED
        else -> ScanSettings.SCAN_MODE_LOW_POWER // saver / critical
    }

    /**
     * Ciclo de escucha: apaga la radio [dutyOffMs] y la reenciende, para no
     * fundir la batería escaneando sin parar. offMs = 0 → escucha continua
     * (rendimiento o SOS activo).
     */
    @SuppressLint("MissingPermission")
    private fun scheduleDutyCycle(adapter: android.bluetooth.BluetoothAdapter) {
        main.removeCallbacks(dutyRunnable)
        if (dutyOffMs <= 0) return // continuo: nada que programar
        dutyRunnable = Runnable {
            if (!radiosWanted) return@Runnable
            try {
                if (scanning) {
                    adapter.bluetoothLeScanner?.stopScan(scanCallback)
                    scanning = false
                    // Vuelve a encender tras la pausa.
                    main.postDelayed({
                        if (radiosWanted && !scanning) startScanning(adapter)
                    }, dutyOffMs.toLong())
                }
            } catch (_: Throwable) {}
        }
        main.postDelayed(dutyRunnable, dutyOnMs.toLong())
    }

    /** Aplica un modo de energía nuevo: reinicia el escaneo con los ajustes. */
    @SuppressLint("MissingPermission")
    fun applyPowerMode(mode: String, onMs: Int, offMs: Int) {
        powerMode = mode
        dutyOnMs = onMs.coerceAtLeast(500)
        dutyOffMs = offMs.coerceAtLeast(0)
        val adapter = bluetoothManager?.adapter ?: return
        if (!radiosWanted) return
        try {
            main.removeCallbacks(dutyRunnable)
            if (scanning) {
                adapter.bluetoothLeScanner?.stopScan(scanCallback)
                scanning = false
            }
            startScanning(adapter)
        } catch (_: Throwable) {}
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        val adapter = bluetoothManager?.adapter
        try {
            adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (_: Throwable) {}
        try {
            adapter?.bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
        } catch (_: Throwable) {}
        scanning = false
        advertising = false

        for (state in peers.values) {
            try {
                state.gatt?.disconnect()
                state.gatt?.close()
            } catch (_: Throwable) {}
        }
        peers.clear()
        subscribedCentrals.clear()
        try {
            gattServer?.close()
        } catch (_: Throwable) {}
        gattServer = null
        serverRx = null
        if (btReceiverRegistered) {
            runCatching { activity.unregisterReceiver(btStateReceiver) }
            btReceiverRegistered = false
        }
        radiosWanted = false
    }

    @SuppressLint("MissingPermission")
    private fun connect(id: String): Boolean {
        if (!hasRuntimePermissions()) return false
        val adapter = bluetoothManager?.adapter ?: return false
        val state = peers.getOrPut(id) { PeerState(id) }
        if (state.gatt != null) return true
        val device = try {
            adapter.getRemoteDevice(id)
        } catch (_: Throwable) {
            return false
        }
        state.device = device
        state.gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            device.connectGatt(activity.applicationContext, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            device.connectGatt(activity.applicationContext, false, gattCallback)
        }
        return state.gatt != null
    }

    @SuppressLint("MissingPermission")
    private fun disconnect(id: String) {
        val state = peers.remove(id) ?: return
        try {
            state.gatt?.disconnect()
            state.gatt?.close()
        } catch (_: Throwable) {}
    }

    private fun queueSend(id: String, bytes: ByteArray): Boolean {
        // Return path #1: a central subscribed to our RX (an iPhone/Mac that
        // connected to us) — answer via notification. Centrals like iPhones
        // use private addresses and cannot be connected back to as a central,
        // so without this path Android→Apple data would silently die.
        val central = subscribedCentrals[id]
        val rx = serverRx
        if (central != null && rx != null) {
            notifyCentral(central, rx, bytes)
            return true
        }
        // Return path #2: our own central connection to their GATT server.
        val state = peers[id] ?: return false
        synchronized(state) {
            state.queue.add(bytes.copyOf())
        }
        drainWrites(state)
        return true
    }

    @SuppressLint("MissingPermission")
    private fun notifyCentral(
        central: BluetoothDevice,
        rx: BluetoothGattCharacteristic,
        bytes: ByteArray,
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gattServer?.notifyCharacteristicChanged(central, rx, false, bytes)
            } else {
                @Suppress("DEPRECATION")
                rx.value = bytes
                @Suppress("DEPRECATION")
                gattServer?.notifyCharacteristicChanged(central, rx, false)
            }
        } catch (_: Throwable) {}
    }

    @SuppressLint("MissingPermission")
    private fun drainWrites(state: PeerState) {
        val gatt = state.gatt ?: return
        val tx = state.tx ?: return
        val next: ByteArray
        synchronized(state) {
            if (state.writing) return
            next = state.queue.poll() ?: return
            state.writing = true
        }
        val started = try {
            tx.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeCharacteristic(tx, next, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) == BluetoothGatt.GATT_SUCCESS
            } else {
                @Suppress("DEPRECATION")
                tx.value = next
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(tx)
            }
        } catch (_: Throwable) {
            false
        }
        if (!started) {
            synchronized(state) { state.writing = false }
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartFailure(errorCode: Int) {
            advertising = false
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            notePeer(result.device)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>) {
            results.forEach { notePeer(it.device) }
        }
    }

    private fun notePeer(device: BluetoothDevice) {
        val id = device.address ?: return
        peers.getOrPut(id) { PeerState(id) }.device = device
        emit(mapOf("type" to "peer", "id" to id))
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            val id = gatt.device.address ?: return
            val state = peers.getOrPut(id) { PeerState(id) }
            state.gatt = gatt
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        gatt.requestMtu(247)
                    }
                    gatt.discoverServices()
                } catch (_: Throwable) {}
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                synchronized(state) {
                    state.tx = null
                    state.writing = false
                    state.queue.clear()
                }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            try {
                gatt.discoverServices()
            } catch (_: Throwable) {}
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            val id = gatt.device.address ?: return
            val state = peers.getOrPut(id) { PeerState(id) }
            val service = gatt.getService(SERVICE_UUID)
            val tx = service?.getCharacteristic(TX_UUID)
            if (tx != null) {
                state.tx = tx
                drainWrites(state)
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            val id = gatt.device.address ?: return
            val state = peers[id] ?: return
            synchronized(state) { state.writing = false }
            drainWrites(state)
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                notePeer(device)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                device.address?.let { subscribedCentrals.remove(it) }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: android.bluetooth.BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            // A central writing the CCCD is subscribing to (or leaving) our RX
            // notifications — remember it so send() can answer via notify.
            if (descriptor.uuid == CCCD_UUID) {
                val id = device.address
                val enabling = value != null && value.isNotEmpty() && value[0].toInt() != 0
                if (id != null) {
                    if (enabling) {
                        subscribedCentrals[id] = device
                        notePeer(device)
                    } else {
                        subscribedCentrals.remove(id)
                    }
                }
            }
            if (responseNeeded) {
                try {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                } catch (_: Throwable) {}
            }
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            if (characteristic.uuid == TX_UUID && offset == 0 && value != null) {
                emit(mapOf("type" to "data", "id" to device.address, "bytes" to value.copyOf()))
            }
            if (responseNeeded) {
                try {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
                } catch (_: Throwable) {}
            }
        }
    }

    private fun emit(event: Map<String, Any>) {
        main.post { sink?.success(event) }
    }

    private class PeerState(val id: String) {
        var device: BluetoothDevice? = null
        var gatt: BluetoothGatt? = null
        var tx: BluetoothGattCharacteristic? = null
        var writing: Boolean = false
        val queue: ArrayDeque<ByteArray> = ArrayDeque()
    }
}
