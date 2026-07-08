package com.prepperpad.prepper_pad

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.wifi.WifiManager
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var multicastLockHeld = false
    private var compassStream: CompassStreamHandler? = null
    private var bleMesh: BleMeshBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val sensorManager = applicationContext
            .getSystemService(Context.SENSOR_SERVICE) as SensorManager
        compassStream = CompassStreamHandler(applicationContext, sensorManager)
        bleMesh = BleMeshBridge(this)

        // UDP multicast (Prepper Mesh) requires a MulticastLock on Android;
        // without it most devices silently drop multicast datagrams.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            if (multicastLock == null) {
                                val wifi =
                                    applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                                multicastLock = wifi.createMulticastLock("prepper-mesh").apply {
                                    setReferenceCounted(false)
                                }
                            }
                            if (multicastLockHeld.not()) {
                                multicastLock?.acquire()
                                multicastLockHeld = true
                            }
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("MULTICAST_LOCK", t.message, t.stackTraceToString())
                        }
                    }
                    "release" -> {
                        try {
                            if (multicastLockHeld) {
                                multicastLock?.release()
                                multicastLockHeld = false
                            }
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("MULTICAST_LOCK", t.message, t.stackTraceToString())
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/sensors")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasCompass" -> result.success(compassStream?.hasCompass() == true)
                    "hasMagnetometer" -> result.success(compassStream?.hasMagnetometer() == true)
                    "calibrateCompass" -> {
                        compassStream?.calibrate()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // SOS channel (native fallback for future SOS escalation).
        // Returning explicit status avoids uncaught 'method not implemented' cases
        // and makes Dart side error handling deterministic.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/sos_alarm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> result.success(false)
                    "stop" -> result.success(true)
                    "trigger" -> result.success(false)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/ble_mesh")
            .setMethodCallHandler(bleMesh)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/ble_mesh/events")
            .setStreamHandler(bleMesh)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/bundled_assets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copyAsset" -> {
                        try {
                            val asset = call.argument<String>("asset")
                                ?: throw IllegalArgumentException("asset requerido")
                            val dest = call.argument<String>("dest")
                                ?: throw IllegalArgumentException("dest requerido")
                            val expectedBytes = call.argument<Number>("bytes")?.toLong()
                                ?: throw IllegalArgumentException("bytes requerido")
                            val expectedSha = call.argument<String>("sha256")
                                ?: throw IllegalArgumentException("sha256 requerido")
                            copyBundledAsset(asset, dest, expectedBytes, expectedSha)
                            result.success(true)
                        } catch (t: Throwable) {
                            result.error("COPY_ASSET_FAILED", t.message, t.stackTraceToString())
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "prepper/sensors/compass")
            .setStreamHandler(compassStream)
    }

    override fun onPause() {
        compassStream?.pause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        compassStream?.resume()
    }

    override fun onDestroy() {
        compassStream?.stop(clearSink = true)
        bleMesh?.stop()
        if (multicastLockHeld) {
            try {
                multicastLock?.release()
                multicastLockHeld = false
            } catch (_: Throwable) {
                // ignore best effort cleanup
            }
        }
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (bleMesh?.onRequestPermissionsResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun copyBundledAsset(
        asset: String,
        destPath: String,
        expectedBytes: Long,
        expectedSha256: String,
    ) {
        require(asset.startsWith("assets/bundled_library/")) { "asset fuera del bundle" }
        require(!asset.split('/').contains("..")) { "asset inseguro" }
        require(!destPath.contains("..")) { "dest inseguro" }
        val dest = File(destPath)
        dest.parentFile?.mkdirs()
        if (dest.exists() && dest.length() == expectedBytes && sha256OfFile(dest).equals(expectedSha256, ignoreCase = true)) return

        val tmp = File("${dest.absolutePath}.tmp")
        val digest = MessageDigest.getInstance("SHA-256")
        var written = 0L
        assets.open("flutter_assets/$asset").use { input ->
            FileOutputStream(tmp).use { output ->
                val buffer = ByteArray(1024 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read <= 0) break
                    digest.update(buffer, 0, read)
                    output.write(buffer, 0, read)
                    written += read.toLong()
                }
                output.fd.sync()
            }
        }
        if (written != expectedBytes) {
            tmp.delete()
            throw IllegalStateException("tamaño inesperado $written != $expectedBytes")
        }
        val actualSha = digest.digest().joinToString("") { "%02x".format(it) }
        if (!actualSha.equals(expectedSha256, ignoreCase = true)) {
            tmp.delete()
            throw IllegalStateException("checksum inválido para $asset")
        }
        replaceFilePreservingExisting(tmp, dest)
    }

    private fun replaceFilePreservingExisting(tmp: File, dest: File) {
        if (!dest.exists()) {
            if (!tmp.renameTo(dest)) {
                tmp.delete()
                throw IllegalStateException("no se pudo mover asset a destino")
            }
            return
        }

        val backup = File("${dest.absolutePath}.bak")
        if (backup.exists() && !backup.delete()) {
            tmp.delete()
            throw IllegalStateException("no se pudo limpiar backup anterior")
        }
        if (!dest.renameTo(backup)) {
            tmp.delete()
            throw IllegalStateException("no se pudo preparar reemplazo seguro")
        }
        if (tmp.renameTo(dest)) {
            backup.delete()
            return
        }

        // Best-effort rollback: never leave the user without the previously
        // installed offline asset just because a replace failed mid-copy.
        backup.renameTo(dest)
        tmp.delete()
        throw IllegalStateException("no se pudo mover asset a destino")
    }

    private fun sha256OfFile(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(1024 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }
}

private class CompassStreamHandler(
    private val context: Context,
    private val sensorManager: SensorManager,
) : EventChannel.StreamHandler, SensorEventListener {
    private var sink: EventChannel.EventSink? = null
    private val rotationVector: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val accelerometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val magnetometer: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false
    private var lastHeading: Float? = null
    private var lastAccuracy: Int = SensorManager.SENSOR_STATUS_UNRELIABLE
    private var lastEmitNanos: Long = 0L
    private var isCalibrating = false
    private var calibrationSamples = 0
    private var isStreamOpen = false
    private var isWatching = false

    // SENSOR_DELAY_UI is usually enough, but some devices still send bursts.
    // Keep the UI smooth without wasting battery or hammering the Flutter bridge.
    private val minEmitIntervalNanos = 50_000_000L // 20Hz max

    fun hasCompass(): Boolean = rotationVector != null || (accelerometer != null && magnetometer != null)

    fun hasMagnetometer(): Boolean = magnetometer != null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        if (!hasCompass()) {
            events?.error("NO_COMPASS", "No rotation-vector or accelerometer+magnetometer sensors", null)
            sink = null
            isStreamOpen = false
            return
        }

        isStreamOpen = true
        isCalibrating = false
        calibrationSamples = 0
        lastEmitNanos = 0L
        isWatching = false
        startWatching()
    }

    override fun onCancel(arguments: Any?) {
        isStreamOpen = false
        stop(clearSink = true)
    }

    fun pause() {
        stop(clearSink = false)
    }

    fun resume() {
        if (!isStreamOpen) return
        startWatching()
    }

    fun calibrate() {
        isCalibrating = true
        calibrationSamples = 0
        lastHeading = null
        lastEmitNanos = 0L
    }

    fun stop(clearSink: Boolean = true) {
        if (isWatching) {
            try {
                sensorManager.unregisterListener(this)
            } catch (_: Throwable) {
                // best effort
            }
            isWatching = false
        }
        if (clearSink) {
            sink = null
            isStreamOpen = false
        }
        hasGravity = false
        hasGeomagnetic = false
        lastHeading = null
        lastAccuracy = SensorManager.SENSOR_STATUS_UNRELIABLE
        lastEmitNanos = 0L
        isCalibrating = false
        calibrationSamples = 0
    }

    private fun startWatching() {
        if (isWatching) return
        try {
            if (rotationVector != null) {
                val ok = sensorManager.registerListener(
                    this,
                    rotationVector,
                    SensorManager.SENSOR_DELAY_UI,
                )
                if (ok) {
                    isWatching = true
                    return
                }
            }

            var registeredFallback = false
            accelerometer?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
                registeredFallback = true
            }
            magnetometer?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
                registeredFallback = true
            }
            isWatching = registeredFallback
            if (!isWatching) {
                sink?.error("SENSOR_REGISTER_FAILED", "No se pudo registrar ningún sensor", null)
                sink = null
                isStreamOpen = false
            }
        } catch (t: Throwable) {
            sink?.error("SENSOR_REGISTER_FAILED", t.message, t.stackTraceToString())
            sink = null
            isStreamOpen = false
            isWatching = false
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!isWatching || sink == null) return

        when (event.sensor.type) {
            Sensor.TYPE_ROTATION_VECTOR -> {
                val rotation = FloatArray(9)
                SensorManager.getRotationMatrixFromVector(rotation, event.values)
                emitHeading(rotation, event.accuracy, event.timestamp, "rotation_vector")
            }
            Sensor.TYPE_ACCELEROMETER -> {
                lowPass(event.values, gravity)
                hasGravity = true
                emitFallbackHeading(event.timestamp)
            }
            Sensor.TYPE_MAGNETIC_FIELD -> {
                lowPass(event.values, geomagnetic)
                hasGeomagnetic = true
                lastAccuracy = event.accuracy
                emitFallbackHeading(event.timestamp)
            }
        }
    }

    private fun emitFallbackHeading(timestampNanos: Long) {
        if (!hasGravity || !hasGeomagnetic) return
        val rotation = FloatArray(9)
        val inclination = FloatArray(9)
        val ok = SensorManager.getRotationMatrix(rotation, inclination, gravity, geomagnetic)
        if (ok) emitHeading(rotation, lastAccuracy, timestampNanos, "accelerometer_magnetometer")
    }

    private fun emitHeading(
        rotation: FloatArray,
        accuracy: Int,
        timestampNanos: Long,
        sensorType: String,
    ) {
        if (!isWatching || sink == null) return
        if (timestampNanos - lastEmitNanos < minEmitIntervalNanos) return
        val adjustedRotation = remapForDisplayRotation(rotation)
        val orientation = FloatArray(3)
        SensorManager.getOrientation(adjustedRotation, orientation)
        val rawDegrees = Math.toDegrees(orientation[0].toDouble()).toFloat()
        val normalized = normalize(rawDegrees)
        val smoothed = smoothHeading(normalized)
        lastEmitNanos = timestampNanos

        val accuracyDegrees = accuracyToDegrees(accuracy)
        val effectiveNeedsCalibration =
            if (isCalibrating) {
                calibrationSamples++
                if (calibrationSamples > 8 && accuracyDegrees <= 10.0) {
                    isCalibrating = false
                }
                accuracyDegrees > 10 || calibrationSamples < 6
            } else {
                accuracy < SensorManager.SENSOR_STATUS_ACCURACY_HIGH
            }

        sink?.success(
            mapOf(
                "heading" to smoothed.toDouble(),
                "accuracy" to accuracyDegrees,
                "sensorAccuracy" to accuracy,
                "needsCalibration" to effectiveNeedsCalibration,
                "sensorType" to sensorType,
                "timestampNanos" to timestampNanos,
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD || sensor?.type == Sensor.TYPE_ROTATION_VECTOR) {
            lastAccuracy = accuracy
        }
    }

    private fun remapForDisplayRotation(rotation: FloatArray): FloatArray {
        return try {
            @Suppress("DEPRECATION")
            val displayRotation =
                (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager)
                    .defaultDisplay
                    .rotation

            if (displayRotation == Surface.ROTATION_0) return rotation

            val remapped = FloatArray(9)
            val ok = when (displayRotation) {
                Surface.ROTATION_90 -> SensorManager.remapCoordinateSystem(
                    rotation,
                    SensorManager.AXIS_Y,
                    SensorManager.AXIS_MINUS_X,
                    remapped,
                )
                Surface.ROTATION_180 -> SensorManager.remapCoordinateSystem(
                    rotation,
                    SensorManager.AXIS_MINUS_X,
                    SensorManager.AXIS_MINUS_Y,
                    remapped,
                )
                Surface.ROTATION_270 -> SensorManager.remapCoordinateSystem(
                    rotation,
                    SensorManager.AXIS_MINUS_Y,
                    SensorManager.AXIS_X,
                    remapped,
                )
                else -> false
            }
            if (ok) remapped else rotation
        } catch (_: Throwable) {
            rotation
        }
    }

    private fun accuracyToDegrees(accuracy: Int): Double = when (accuracy) {
        SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> 5.0
        SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> 15.0
        SensorManager.SENSOR_STATUS_ACCURACY_LOW -> 30.0
        SensorManager.SENSOR_STATUS_UNRELIABLE -> 90.0
        else -> 45.0
    }

    private fun lowPass(input: FloatArray, output: FloatArray) {
        val alpha = 0.15f
        for (i in 0 until 3) {
            output[i] = output[i] + alpha * (input[i] - output[i])
        }
    }

    private fun smoothHeading(newHeading: Float): Float {
        val previous = lastHeading
        if (previous == null) {
            lastHeading = newHeading
            return newHeading
        }
        var delta = newHeading - previous
        if (delta > 180f) delta -= 360f
        if (delta < -180f) delta += 360f
        val smoothed = normalize(previous + delta * 0.25f)
        lastHeading = smoothed
        return smoothed
    }

    private fun normalize(value: Float): Float {
        var h = value % 360f
        if (h < 0f) h += 360f
        // Keep the Dart display stable: no 359.999999 noise when pointing north.
        return (h * 1000f).roundToInt() / 1000f
    }
}
