package com.example.music_daw_player

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

private const val METHOD_CHANNEL_NAME = "music_daw_player/audio_engine"
private const val EVENT_CHANNEL_NAME = "music_daw_player/audio_engine/events"
private const val PICK_OUTPUT_DIRECTORY_REQUEST_CODE = 2701

private object Freeverb3Native {
    init {
        System.loadLibrary("music_daw_audio")
    }

    external fun create(sampleRate: Int): Long
    external fun release(handle: Long)
    external fun reset(handle: Long)
    external fun setParameters(
        handle: Long,
        amount: Float,
        roomSize: Float,
        decay: Float,
        damp: Float,
        preDelayMs: Float,
        width: Float,
    )
    external fun process(handle: Long, input: FloatArray, output: FloatArray, frames: Int)
}

private object LameMp3Native {
    init {
        System.loadLibrary("music_daw_audio")
    }

    external fun create(sampleRate: Int, channels: Int, bitRateKbps: Int): Long
    external fun encode(handle: Long, pcm: ShortArray, frames: Int): ByteArray
    external fun flush(handle: Long): ByteArray
    external fun release(handle: Long)
}

class MainActivity : FlutterActivity() {
    private lateinit var audioEngine: AndroidAudioEngine
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var positionEmitter: Runnable? = null
    private var pendingOutputDirectoryResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioEngine = AndroidAudioEngine(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME,
        ).setMethodCallHandler(::handleMethodCall)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_NAME,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    startPositionEmitter()
                }

                override fun onCancel(arguments: Any?) {
                    stopPositionEmitter()
                    eventSink = null
                }
            },
        )
    }

    override fun onDestroy() {
        stopPositionEmitter()
        if (::audioEngine.isInitialized) {
            audioEngine.release()
        }
        super.onDestroy()
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "loadTrack" -> {
                    val id = call.argument<String>("id").orEmpty()
                    val filePath = call.argument<String>("filePath").orEmpty()
                    runAudioJob(result) {
                        audioEngine.loadTrack(id = id, sourcePath = filePath)
                    }
                }

                "removeTrack" -> {
                    audioEngine.removeTrack(call.argument<String>("id").orEmpty())
                    result.success(null)
                }

                "play" -> {
                    audioEngine.play()
                    result.success(null)
                }

                "pause" -> {
                    audioEngine.pause()
                    result.success(null)
                }

                "seek" -> {
                    audioEngine.seek(call.argument<Int>("positionMs") ?: 0)
                    result.success(null)
                }

                "setSpeed" -> {
                    audioEngine.setSpeed(call.argument<Double>("speed") ?: 1.0)
                    result.success(null)
                }

                "setTrackVolume" -> {
                    audioEngine.setTrackVolume(
                        id = call.argument<String>("id").orEmpty(),
                        volume = call.argument<Double>("volume") ?: 1.0,
                    )
                    result.success(null)
                }

                "setTrackPan" -> {
                    audioEngine.setTrackPan(
                        id = call.argument<String>("id").orEmpty(),
                        pan = call.argument<Double>("pan") ?: 0.0,
                    )
                    result.success(null)
                }

                "setTrackReverb" -> {
                    audioEngine.setTrackReverb(
                        id = call.argument<String>("id").orEmpty(),
                        reverb = call.argument<Double>("reverb") ?: 0.0,
                    )
                    result.success(null)
                }

                "setTrackReverbSettings" -> {
                    audioEngine.setTrackReverbSettings(
                        id = call.argument<String>("id").orEmpty(),
                        mix = call.argument<Double>("mix") ?: 0.48,
                        roomSize = call.argument<Double>("roomSize") ?: 0.58,
                        decay = call.argument<Double>("decay") ?: 0.62,
                        damp = call.argument<Double>("damp") ?: 0.42,
                        preDelayMs = call.argument<Double>("preDelayMs") ?: 32.0,
                        width = call.argument<Double>("width") ?: 0.78,
                    )
                    result.success(null)
                }

                "setTrackMute" -> {
                    audioEngine.setTrackMute(
                        id = call.argument<String>("id").orEmpty(),
                        muted = call.argument<Boolean>("muted") ?: false,
                    )
                    result.success(null)
                }

                "setTrackStart" -> {
                    audioEngine.setTrackStart(
                        id = call.argument<String>("id").orEmpty(),
                        startMs = call.argument<Int>("startMs") ?: 0,
                    )
                    result.success(null)
                }

                "setTrackRegion" -> {
                    audioEngine.setTrackRegion(
                        id = call.argument<String>("id").orEmpty(),
                        startMs = call.argument<Int>("startMs") ?: 0,
                        sourceOffsetMs = call.argument<Int>("sourceOffsetMs") ?: 0,
                        durationMs = call.argument<Int>("durationMs") ?: 0,
                    )
                    result.success(null)
                }

                "mixTracks" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    val outputDirectory =
                        call.argument<String>("outputDirectory").orEmpty()
                    val outputFileName =
                        call.argument<String>("outputFileName").orEmpty()
                    runAudioJob(result) {
                        audioEngine.mixTracks(
                            ids = ids,
                            outputDirectory = outputDirectory,
                            outputFileName = outputFileName,
                        )
                    }
                }

                "separateVocalBacking" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    val outputDirectory =
                        call.argument<String>("outputDirectory").orEmpty()
                    val outputBaseName =
                        call.argument<String>("outputBaseName").orEmpty()
                    runAudioJob(result) {
                        audioEngine.separateVocalBacking(
                            ids = ids,
                            outputDirectory = outputDirectory,
                            outputBaseName = outputBaseName,
                        )
                    }
                }

                "writeSessionFile" -> {
                    val directoryUri = call.argument<String>("directoryUri").orEmpty()
                    val fileName = call.argument<String>("fileName").orEmpty()
                    val contents = call.argument<String>("contents").orEmpty()
                    runAudioJob(result) {
                        audioEngine.writeSessionFile(
                            directoryUri = directoryUri,
                            fileName = fileName,
                            contents = contents,
                        )
                    }
                }

                "readSessionFile" -> {
                    val directoryUri = call.argument<String>("directoryUri").orEmpty()
                    val fileName = call.argument<String>("fileName").orEmpty()
                    runAudioJob(result) {
                        audioEngine.readSessionFile(
                            directoryUri = directoryUri,
                            fileName = fileName,
                        )
                    }
                }

                "pickOutputDirectory" -> {
                    pickOutputDirectory(result)
                }

                "startRecording" -> {
                    ensureRecordPermission()
                    result.success(audioEngine.startRecording())
                }

                "stopRecording" -> {
                    result.success(audioEngine.stopRecording())
                }

                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("audio_engine_error", error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PICK_OUTPUT_DIRECTORY_REQUEST_CODE) {
            val pendingResult = pendingOutputDirectoryResult
            pendingOutputDirectoryResult = null
            val uri = data?.data
            if (resultCode == RESULT_OK && uri != null) {
                val grantFlags = data.flags and (
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                runCatching {
                    contentResolver.takePersistableUriPermission(uri, grantFlags)
                }
                pendingResult?.success(uri.toString())
            } else {
                pendingResult?.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun pickOutputDirectory(result: MethodChannel.Result) {
        if (pendingOutputDirectoryResult != null) {
            result.error("picker_busy", "A folder picker is already open.", null)
            return
        }
        pendingOutputDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, PICK_OUTPUT_DIRECTORY_REQUEST_CODE)
    }

    private fun runAudioJob(
        result: MethodChannel.Result,
        job: () -> Map<String, Any>,
    ) {
        thread(
            start = true,
            name = "music-daw-player-offline-render",
            isDaemon = true,
        ) {
            try {
                val payload = job()
                mainHandler.post { result.success(payload) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("audio_engine_error", error.message, null)
                }
            }
        }
    }

    private fun ensureRecordPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 2001)
        error("Microphone permission is required. Please allow it and tap record again.")
    }

    private fun startPositionEmitter() {
        stopPositionEmitter()
        val runnable = object : Runnable {
            override fun run() {
                eventSink?.success(audioEngine.positionSnapshot())
                mainHandler.postDelayed(this, 50)
            }
        }
        positionEmitter = runnable
        mainHandler.post(runnable)
    }

    private fun stopPositionEmitter() {
        positionEmitter?.let(mainHandler::removeCallbacks)
        positionEmitter = null
    }
}

private class AndroidAudioEngine(
    private val context: Context,
) {
    private val stateLock = Any()
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val mixSampleRate = 44_100
    private val outputChannelCount = 2
    private val outputFrameBlock = 1_024

    private val tracks = linkedMapOf<String, DecodedTrack>()

    @Volatile
    private var released = false

    @Volatile
    private var playing = false

    @Volatile
    private var playbackThread: Thread? = null

    private var playbackSpeed = 1.0
    private var positionFrames = 0.0
    private var positionRevision = 0L
    private var audioTrack: AudioTrack = buildAudioTrack()
    private var audioFocusRequest: AudioFocusRequest? = null
    private var noisyReceiverRegistered = false
    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var recordingStartedAtMs = 0L

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                pause()
            }
        }
    }

    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
            -> pause()
        }
    }

    fun loadTrack(id: String, sourcePath: String): Map<String, Any> {
        require(id.isNotBlank()) { "Track id is required." }
        require(sourcePath.isNotBlank()) { "Audio file path is required." }

        val decodedTrack = decodeTrack(sourcePath, id)
        synchronized(stateLock) {
            tracks.put(id, decodedTrack)?.release()
        }
        return mapOf(
            "durationMs" to decodedTrack.durationMs,
            "waveformPeaks" to decodedTrack.waveformPeaks,
        )
    }

    fun removeTrack(id: String) {
        var removedTrack: DecodedTrack? = null
        synchronized(stateLock) {
            removedTrack = tracks.remove(id)
            if (tracks.isEmpty()) {
                positionFrames = 0.0
                positionRevision += 1
                playing = false
            } else {
                val clampedPosition = min(positionFrames, maxFrameCountUnsafe().toDouble())
                if (clampedPosition != positionFrames) {
                    positionRevision += 1
                }
                positionFrames = clampedPosition
            }
        }
        removedTrack?.release()
        if (tracks.isEmpty()) {
            stopAudioHardware()
        }
    }

    fun play() {
        synchronized(stateLock) {
            if (tracks.isEmpty()) {
                return
            }
        }

        if (!requestAudioFocus()) {
            return
        }

        ensurePlaybackThread()
        registerNoisyReceiver()
        if (audioTrack.playState != AudioTrack.PLAYSTATE_PLAYING) {
            audioTrack.play()
        }
        playing = true
    }

    fun pause() {
        playing = false
        stopAudioHardware()
    }

    fun seek(positionMs: Int) {
        synchronized(stateLock) {
            positionFrames = (positionMs.coerceAtLeast(0) / 1000.0) * mixSampleRate
            positionFrames = min(positionFrames, maxFrameCountUnsafe().toDouble())
            positionRevision += 1
            resetReverbsUnsafe()
        }
        refreshAudioHardware()
    }

    fun setSpeed(speed: Double) {
        synchronized(stateLock) {
            playbackSpeed = speed.coerceIn(0.5, 2.0)
        }
    }

    fun setTrackVolume(id: String, volume: Double) {
        synchronized(stateLock) {
            tracks[id]?.volume = volume.toFloat().coerceIn(0f, 1f)
        }
    }

    fun setTrackPan(id: String, pan: Double) {
        synchronized(stateLock) {
            tracks[id]?.pan = pan.toFloat().coerceIn(-1f, 1f)
        }
    }

    fun setTrackReverb(id: String, reverb: Double) {
        synchronized(stateLock) {
            tracks[id]?.reverb = reverb.toFloat().coerceIn(0f, 1f)
        }
    }

    fun setTrackReverbSettings(
        id: String,
        mix: Double,
        roomSize: Double,
        decay: Double,
        damp: Double,
        preDelayMs: Double,
        width: Double,
    ) {
        synchronized(stateLock) {
            tracks[id]?.let { track ->
                track.setReverbSettings(
                    mix = mix.toFloat(),
                    roomSize = roomSize.toFloat(),
                    decay = decay.toFloat(),
                    damp = damp.toFloat(),
                    preDelayMs = preDelayMs.toFloat(),
                    width = width.toFloat(),
                )
            }
        }
    }

    fun setTrackMute(id: String, muted: Boolean) {
        synchronized(stateLock) {
            tracks[id]?.muted = muted
        }
    }

    fun setTrackStart(id: String, startMs: Int) {
        synchronized(stateLock) {
            tracks[id]?.startFrame = (startMs.coerceAtLeast(0) / 1000.0) * mixSampleRate
            val clampedPosition = min(positionFrames, maxFrameCountUnsafe().toDouble())
            if (clampedPosition != positionFrames) {
                positionRevision += 1
            }
            positionFrames = clampedPosition
            tracks[id]?.resetReverb()
        }
    }

    fun setTrackRegion(id: String, startMs: Int, sourceOffsetMs: Int, durationMs: Int) {
        synchronized(stateLock) {
            tracks[id]?.let { track ->
                track.startFrame = (startMs.coerceAtLeast(0) / 1000.0) * mixSampleRate
                track.sourceOffsetFrame =
                    (sourceOffsetMs.coerceAtLeast(0) / 1000.0) * mixSampleRate
                val requestedFrames =
                    (durationMs.coerceAtLeast(0) / 1000.0) * mixSampleRate
                val availableFrames = max(
                    0.0,
                    track.frameCount.toDouble() - track.sourceOffsetFrame,
                )
                track.clipFrameCount = min(requestedFrames, availableFrames)
                track.resetReverb()
            }
            val clampedPosition = min(positionFrames, maxFrameCountUnsafe().toDouble())
            if (clampedPosition != positionFrames) {
                positionRevision += 1
            }
            positionFrames = clampedPosition
        }
    }

    fun startRecording(): Map<String, Any> {
        synchronized(stateLock) {
            check(mediaRecorder == null) { "Recording is already running." }
        }

        val outputDirectory = File(context.filesDir, "recordings").apply {
            mkdirs()
        }
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val outputFile = File(outputDirectory, "recording_$timestamp.m4a")
        val recorder = buildMediaRecorder(outputFile)

        recorder.prepare()
        recorder.start()

        synchronized(stateLock) {
            mediaRecorder = recorder
            recordingFile = outputFile
            recordingStartedAtMs = System.currentTimeMillis()
        }

        return mapOf("filePath" to outputFile.absolutePath)
    }

    fun stopRecording(): Map<String, Any> {
        val recorder: MediaRecorder
        val outputFile: File
        val startedAt: Long
        synchronized(stateLock) {
            recorder = mediaRecorder ?: error("Recording is not running.")
            outputFile = recordingFile ?: error("Recording file is unavailable.")
            startedAt = recordingStartedAtMs
            mediaRecorder = null
            recordingFile = null
            recordingStartedAtMs = 0L
        }

        try {
            recorder.stop()
        } catch (error: RuntimeException) {
            outputFile.delete()
            throw IllegalStateException("Recording was too short to save.", error)
        } finally {
            recorder.reset()
            recorder.release()
        }

        val durationMs = (System.currentTimeMillis() - startedAt).coerceAtLeast(0L)
        return mapOf(
            "filePath" to outputFile.absolutePath,
            "durationMs" to durationMs,
        )
    }

    fun mixTracks(
        ids: List<String>,
        outputDirectory: String,
        outputFileName: String,
    ): Map<String, Any> {
        val selected = selectedTracks(ids)
        val outputTarget = openOutputTarget(
            directoryName = "mixes",
            prefix = "mix",
            outputDirectory = outputDirectory,
            requestedFileName = outputFileName,
        )
        var frameCount = 0
        outputTarget.use { target ->
            frameCount = renderTracksToMp3(selected, target.stream)
        }
        return mapOf(
            "filePath" to outputTarget.displayPath,
            "durationMs" to ((frameCount / mixSampleRate.toDouble()) * 1000.0).toInt(),
        )
    }

    fun separateVocalBacking(
        ids: List<String>,
        outputDirectory: String,
        outputBaseName: String,
    ): Map<String, Any> {
        val selected = selectedTracks(ids)
        val safeBaseName = sanitizeFileName(outputBaseName, "split")
            .replace(Regex("""(?i)\.mp3$"""), "")
        val vocalsTarget = openOutputTarget(
            directoryName = "separated",
            prefix = "vocals",
            outputDirectory = outputDirectory,
            requestedFileName = "${safeBaseName}_vocals.mp3",
        )
        val backingTarget = openOutputTarget(
            directoryName = "separated",
            prefix = "backing",
            outputDirectory = outputDirectory,
            requestedFileName = "${safeBaseName}_backing.mp3",
        )
        vocalsTarget.use { vocals ->
            backingTarget.use { backing ->
                renderSeparatedTracksToMp3(
                    selected = selected,
                    vocalsStream = vocals.stream,
                    backingStream = backing.stream,
                )
            }
        }
        return mapOf(
            "vocalsFilePath" to vocalsTarget.displayPath,
            "backingFilePath" to backingTarget.displayPath,
        )
    }

    fun writeSessionFile(
        directoryUri: String,
        fileName: String,
        contents: String,
    ): Map<String, Any> {
        require(directoryUri.isNotBlank()) { "Session folder is required." }
        require(fileName.isNotBlank()) { "Session file name is required." }

        val target = openSessionOutputTarget(
            directoryUri = directoryUri,
            fileName = fileName,
        )
        target.use { output ->
            output.stream.write(contents.toByteArray(Charsets.UTF_8))
            output.stream.flush()
        }
        return mapOf("filePath" to target.displayPath)
    }

    fun readSessionFile(directoryUri: String, fileName: String): Map<String, Any> {
        require(directoryUri.isNotBlank()) { "Session folder is required." }
        require(fileName.isNotBlank()) { "Session file name is required." }

        val fileUri = resolveSessionFileUri(
            directoryUri = directoryUri,
            fileName = fileName,
        ) ?: error("No $fileName found in that folder.")
        val contents = context.contentResolver.openInputStream(fileUri)
            ?.buffered()
            ?.reader(Charsets.UTF_8)
            ?.use { reader -> reader.readText() }
            ?: error("Could not open $fileName for reading.")
        return mapOf(
            "filePath" to fileUri.toString(),
            "contents" to contents,
        )
    }

    fun positionSnapshot(): Map<String, Any> {
        synchronized(stateLock) {
            val recordingLevel = mediaRecorder?.let { recorder ->
                runCatching {
                    (recorder.maxAmplitude / 32767.0).coerceIn(0.0, 1.0)
                }.getOrDefault(0.0)
            } ?: 0.0
            return mapOf(
                "positionMs" to ((positionFrames / mixSampleRate) * 1000.0).toInt(),
                "durationMs" to currentDurationMsUnsafe(),
                "isPlaying" to playing,
                "recordingLevel" to recordingLevel,
            )
        }
    }

    fun release() {
        released = true
        playing = false
        runCatching {
            mediaRecorder?.stop()
        }
        mediaRecorder?.release()
        mediaRecorder = null
        stopAudioHardware()
        playbackThread?.interrupt()
        synchronized(stateLock) {
            tracks.values.forEach { track -> track.release() }
            tracks.clear()
        }
        if (audioTrack.state == AudioTrack.STATE_INITIALIZED) {
            audioTrack.release()
        }
        unregisterNoisyReceiver()
    }

    private fun ensurePlaybackThread() {
        if (playbackThread?.isAlive == true) {
            return
        }
        playbackThread = thread(
            start = true,
            name = "music-daw-player-audio",
            isDaemon = true,
        ) {
            val mixBuffer = FloatArray(outputFrameBlock * outputChannelCount)
            val trackInputBuffer = FloatArray(outputFrameBlock * outputChannelCount)
            val trackOutputBuffer = FloatArray(outputFrameBlock * outputChannelCount)
            while (!released) {
                if (!playing) {
                    Thread.sleep(16)
                    continue
                }

                val snapshot: List<DecodedTrack>
                val localSpeed: Double
                val startFrame: Double
                val arrangementFrames: Double
                val renderRevision: Long

                synchronized(stateLock) {
                    snapshot = tracks.values.toList()
                    localSpeed = playbackSpeed
                    startFrame = positionFrames
                    arrangementFrames = maxFrameCountUnsafe().toDouble()
                    renderRevision = positionRevision
                }

                if (snapshot.isEmpty() || arrangementFrames <= 0.0) {
                    pause()
                    continue
                }

                mixBuffer.fill(0f)
                val remainingTimelineFrames = max(0.0, arrangementFrames - startFrame)
                val renderFrameCount = min(
                    outputFrameBlock,
                    ceil(remainingTimelineFrames / localSpeed).toInt(),
                )
                val consumedFrames = min(
                    remainingTimelineFrames,
                    renderFrameCount * localSpeed,
                )
                var reachedEnd = renderFrameCount < outputFrameBlock ||
                    startFrame + consumedFrames >= arrangementFrames

                if (renderFrameCount <= 0) {
                    reachedEnd = true
                } else {
                    snapshot.forEach { track ->
                        if (track.muted) {
                            return@forEach
                        }
                        track.renderBlock(
                            blockStartFrame = startFrame,
                            speed = localSpeed,
                            frameCount = renderFrameCount,
                            inputBuffer = trackInputBuffer,
                            outputBuffer = trackOutputBuffer,
                        )
                        val (leftGain, rightGain) = gainsFor(track.volume, track.pan)
                        for (frameIndex in 0 until renderFrameCount) {
                            val writeIndex = frameIndex * outputChannelCount
                            mixBuffer[writeIndex] += trackOutputBuffer[writeIndex] * leftGain
                            mixBuffer[writeIndex + 1] +=
                                trackOutputBuffer[writeIndex + 1] * rightGain
                        }
                    }

                    for (frameIndex in 0 until renderFrameCount) {
                        val writeIndex = frameIndex * outputChannelCount
                        mixBuffer[writeIndex] = mixBuffer[writeIndex].coerceIn(-1f, 1f)
                        mixBuffer[writeIndex + 1] =
                            mixBuffer[writeIndex + 1].coerceIn(-1f, 1f)
                    }
                }

                val writeResult = audioTrack.write(
                    mixBuffer,
                    0,
                    mixBuffer.size,
                    AudioTrack.WRITE_BLOCKING,
                )

                synchronized(stateLock) {
                    if (renderRevision == positionRevision) {
                        positionFrames = min(arrangementFrames, startFrame + consumedFrames)
                        if (positionFrames >= arrangementFrames) {
                            playing = false
                            reachedEnd = true
                        }
                    } else {
                        reachedEnd = false
                    }
                }

                if (writeResult < 0) {
                    rebuildAudioTrack()
                }

                if (reachedEnd) {
                    stopAudioHardware()
                }
            }
        }
    }

    private fun refreshAudioHardware() {
        if (audioTrack.state != AudioTrack.STATE_INITIALIZED) {
            rebuildAudioTrack()
            return
        }
        if (audioTrack.playState == AudioTrack.PLAYSTATE_PLAYING ||
            audioTrack.playState == AudioTrack.PLAYSTATE_PAUSED
        ) {
            audioTrack.pause()
            audioTrack.flush()
            if (playing) {
                audioTrack.play()
            }
        }
    }

    private fun stopAudioHardware() {
        if (audioTrack.state == AudioTrack.STATE_INITIALIZED &&
            (audioTrack.playState == AudioTrack.PLAYSTATE_PLAYING ||
                audioTrack.playState == AudioTrack.PLAYSTATE_PAUSED)
        ) {
            audioTrack.pause()
            audioTrack.flush()
        }
        abandonAudioFocus()
        unregisterNoisyReceiver()
    }

    private fun buildAudioTrack(): AudioTrack {
        val minBufferSize = AudioTrack.getMinBufferSize(
            mixSampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_FLOAT,
        )
        val desiredBuffer = outputFrameBlock * outputChannelCount * 4 * 4
        val bufferSize = if (minBufferSize > 0) max(minBufferSize, desiredBuffer) else desiredBuffer

        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(mixSampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build(),
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setBufferSizeInBytes(bufferSize)
            .build()
    }

    private fun buildMediaRecorder(outputFile: File): MediaRecorder {
        val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        return recorder.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(mixSampleRate)
            setAudioEncodingBitRate(128_000)
            setOutputFile(outputFile.absolutePath)
        }
    }

    private fun rebuildAudioTrack() {
        stopAudioHardware()
        if (audioTrack.state == AudioTrack.STATE_INITIALIZED) {
            audioTrack.release()
        }
        audioTrack = buildAudioTrack()
        if (playing) {
            audioTrack.play()
        }
    }

    private fun requestAudioFocus(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = audioFocusRequest
                ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build(),
                    )
                    .setOnAudioFocusChangeListener(audioFocusChangeListener)
                    .build()
                    .also { audioFocusRequest = it }
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                audioFocusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let(audioManager::abandonAudioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        }
    }

    private fun registerNoisyReceiver() {
        if (noisyReceiverRegistered) {
            return
        }
        val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            context.registerReceiver(noisyReceiver, filter)
        }
        noisyReceiverRegistered = true
    }

    private fun unregisterNoisyReceiver() {
        if (!noisyReceiverRegistered) {
            return
        }
        runCatching { context.unregisterReceiver(noisyReceiver) }
        noisyReceiverRegistered = false
    }

    private fun selectedTracks(ids: List<String>): List<DecodedTrack> {
        require(ids.isNotEmpty()) { "No tracks were selected." }
        synchronized(stateLock) {
            val selected = ids.mapNotNull { id -> tracks[id] }
            require(selected.isNotEmpty()) { "Selected tracks are unavailable." }
            return selected
        }
    }

    private fun renderTracksToMp3(
        selected: List<DecodedTrack>,
        outputStream: java.io.OutputStream,
    ): Int {
        val frameCount = renderFrameCount(selected)
        Mp3Encoder(
            sampleRate = mixSampleRate,
            channelCount = outputChannelCount,
            bitRateKbps = 192,
        ).use { encoder ->
            renderTracksByBlock(selected) { mixedBlock, blockFrames ->
                encoder.encodeBlock(
                    stream = outputStream,
                    samples = mixedBlock,
                    frameCount = blockFrames,
                )
            }
            encoder.flush(outputStream)
        }
        return frameCount
    }

    private fun renderSeparatedTracksToMp3(
        selected: List<DecodedTrack>,
        vocalsStream: java.io.OutputStream,
        backingStream: java.io.OutputStream,
    ) {
        val frameCount = renderFrameCount(selected)
        Mp3Encoder(
            sampleRate = mixSampleRate,
            channelCount = outputChannelCount,
            bitRateKbps = 192,
        ).use { vocalsEncoder ->
            Mp3Encoder(
                sampleRate = mixSampleRate,
                channelCount = outputChannelCount,
                bitRateKbps = 192,
            ).use { backingEncoder ->
                val vocalsBlock = FloatArray(outputFrameBlock * outputChannelCount)
                val backingBlock = FloatArray(outputFrameBlock * outputChannelCount)
                val separator = VocalBackingSeparator(mixSampleRate)
                renderTracksByBlock(selected) { mixedBlock, blockFrames ->
                    separator.process(
                        input = mixedBlock,
                        vocals = vocalsBlock,
                        backing = backingBlock,
                        frameCount = blockFrames,
                    )
                    vocalsEncoder.encodeBlock(
                        stream = vocalsStream,
                        samples = vocalsBlock,
                        frameCount = blockFrames,
                    )
                    backingEncoder.encodeBlock(
                        stream = backingStream,
                        samples = backingBlock,
                        frameCount = blockFrames,
                    )
                }
                vocalsEncoder.flush(vocalsStream)
                backingEncoder.flush(backingStream)
            }
        }
    }

    private fun renderTracksByBlock(
        selected: List<DecodedTrack>,
        onBlock: (FloatArray, Int) -> Unit,
    ) {
        val frameCount = selected.maxOfOrNull { track ->
            ceil(track.startFrame + track.clipFrameCount).toInt()
        } ?: 0
        require(frameCount > 0) { "Selected tracks do not contain audio." }

        val mixedBlock = FloatArray(outputFrameBlock * outputChannelCount)
        val trackInputBuffer = FloatArray(outputFrameBlock * outputChannelCount)
        val trackOutputBuffer = FloatArray(outputFrameBlock * outputChannelCount)

        selected.forEach { track -> track.resetReverb() }
        var blockStart = 0
        while (blockStart < frameCount) {
            val blockFrames = min(outputFrameBlock, frameCount - blockStart)
            mixedBlock.fill(0f, 0, blockFrames * outputChannelCount)
            selected.forEach { track ->
                if (track.muted) {
                    return@forEach
                }
                track.renderBlock(
                    blockStartFrame = blockStart.toDouble(),
                    speed = 1.0,
                    frameCount = blockFrames,
                    inputBuffer = trackInputBuffer,
                    outputBuffer = trackOutputBuffer,
                )
                val (leftGain, rightGain) = gainsFor(track.volume, track.pan)
                for (frameIndex in 0 until blockFrames) {
                    val sourceIndex = frameIndex * outputChannelCount
                    mixedBlock[sourceIndex] += trackOutputBuffer[sourceIndex] * leftGain
                    mixedBlock[sourceIndex + 1] += trackOutputBuffer[sourceIndex + 1] * rightGain
                }
            }
            for (frameIndex in 0 until blockFrames) {
                val targetIndex = frameIndex * outputChannelCount
                mixedBlock[targetIndex] = mixedBlock[targetIndex].coerceIn(-1f, 1f)
                mixedBlock[targetIndex + 1] = mixedBlock[targetIndex + 1].coerceIn(-1f, 1f)
            }
            onBlock(mixedBlock, blockFrames)
            blockStart += blockFrames
        }
        selected.forEach { track -> track.resetReverb() }
    }

    private fun renderFrameCount(selected: List<DecodedTrack>): Int {
        val frameCount = selected.maxOfOrNull { track ->
            ceil(track.startFrame + track.clipFrameCount).toInt()
        } ?: 0
        require(frameCount > 0) { "Selected tracks do not contain audio." }
        return frameCount
    }

    private fun openSessionOutputTarget(
        directoryUri: String,
        fileName: String,
    ): AudioOutputTarget {
        if (directoryUri.startsWith("content://")) {
            val treeUri = Uri.parse(directoryUri)
            val fileUri = resolveSessionFileUri(
                directoryUri = directoryUri,
                fileName = fileName,
            ) ?: run {
                val directoryDocumentUri = directoryDocumentUri(treeUri)
                DocumentsContract.createDocument(
                    context.contentResolver,
                    directoryDocumentUri,
                    "application/json",
                    fileName,
                ) ?: error("Could not create $fileName in the selected folder.")
            }
            val stream = context.contentResolver.openOutputStream(fileUri, "wt")
                ?: error("Could not open $fileName for writing.")
            return AudioOutputTarget(
                stream = stream.buffered(),
                displayPath = fileUri.toString(),
            )
        }

        val directory = File(directoryUri).apply { mkdirs() }
        val file = File(directory, fileName)
        return AudioOutputTarget(
            stream = file.outputStream().buffered(),
            displayPath = file.absolutePath,
        )
    }

    private fun resolveSessionFileUri(directoryUri: String, fileName: String): Uri? {
        if (!directoryUri.startsWith("content://")) {
            val file = File(directoryUri, fileName)
            return if (file.exists()) Uri.fromFile(file) else null
        }

        val treeUri = Uri.parse(directoryUri)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        )
        context.contentResolver.query(
            childrenUri,
            projection,
            null,
            null,
            null,
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameColumn = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            while (cursor.moveToNext()) {
                if (cursor.getString(nameColumn) == fileName) {
                    val documentId = cursor.getString(idColumn)
                    return DocumentsContract.buildDocumentUriUsingTree(
                        treeUri,
                        documentId,
                    )
                }
            }
        }
        return null
    }

    private fun directoryDocumentUri(treeUri: Uri): Uri {
        return DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
    }

    private fun openOutputTarget(
        directoryName: String,
        prefix: String,
        outputDirectory: String,
        requestedFileName: String = "",
    ): AudioOutputTarget {
        val fileName = ensureExtension(
            sanitizeFileName(requestedFileName, timestampedAudioFileName(prefix)),
            "mp3",
        )
        if (outputDirectory.startsWith("content://")) {
            val treeUri = Uri.parse(outputDirectory)
            val directoryUri = DocumentsContract.buildDocumentUriUsingTree(
                treeUri,
                DocumentsContract.getTreeDocumentId(treeUri),
            )
            val fileUri = DocumentsContract.createDocument(
                context.contentResolver,
                directoryUri,
                "audio/mpeg",
                fileName,
            ) ?: error("Could not create $fileName in the selected folder.")
            val stream = context.contentResolver.openOutputStream(fileUri, "w")
                ?: error("Could not open $fileName for writing.")
            return AudioOutputTarget(
                stream = stream.buffered(),
                displayPath = fileUri.toString(),
            )
        }

        val outputFile = outputAudioFile(
            directoryName = directoryName,
            fileName = fileName,
            outputDirectory = outputDirectory,
        )
        return AudioOutputTarget(
            stream = outputFile.outputStream().buffered(),
            displayPath = outputFile.absolutePath,
        )
    }

    private fun outputAudioFile(
        directoryName: String,
        fileName: String,
        outputDirectory: String,
    ): File {
        val baseDirectory = if (outputDirectory.isBlank()) {
            File(context.filesDir, directoryName)
        } else {
            File(outputDirectory)
        }.apply {
            mkdirs()
        }
        return File(baseDirectory, fileName)
    }

    private fun timestampedAudioFileName(prefix: String): String {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
        return "${prefix}_$timestamp.mp3"
    }

    private fun sanitizeFileName(value: String, fallback: String): String {
        val withoutPath = value
            .substringAfterLast('/')
            .substringAfterLast('\\')
            .trim()
        val sanitized = withoutPath
            .replace(Regex("""[<>:"/\\|?*\u0000-\u001F]"""), "_")
            .replace(Regex("""\s+"""), " ")
            .trim(' ', '.')
        return sanitized.ifBlank { fallback }
    }

    private fun ensureExtension(fileName: String, extension: String): String {
        val normalizedExtension = extension.removePrefix(".")
        return if (fileName.endsWith(".$normalizedExtension", ignoreCase = true)) {
            fileName
        } else {
            "$fileName.$normalizedExtension"
        }
    }

    private fun writeWavHeader(
        stream: java.io.OutputStream,
        frameCount: Int,
        sampleRate: Int,
    ) {
        val channelCount = outputChannelCount
        val bitsPerSample = 16
        val byteRate = sampleRate * channelCount * bitsPerSample / 8
        val blockAlign = channelCount * bitsPerSample / 8
        val dataSize = frameCount * channelCount * bitsPerSample / 8

        writeAscii(stream, "RIFF")
        writeIntLe(stream, 36 + dataSize)
        writeAscii(stream, "WAVE")
        writeAscii(stream, "fmt ")
        writeIntLe(stream, 16)
        writeShortLe(stream, 1)
        writeShortLe(stream, channelCount)
        writeIntLe(stream, sampleRate)
        writeIntLe(stream, byteRate)
        writeShortLe(stream, blockAlign)
        writeShortLe(stream, bitsPerSample)
        writeAscii(stream, "data")
        writeIntLe(stream, dataSize)
    }

    private fun writePcmBlock(
        stream: java.io.OutputStream,
        samples: FloatArray,
        frameCount: Int,
    ) {
        val byteCount = frameCount * outputChannelCount * 2
        val bytes = ByteArray(byteCount)
        var byteIndex = 0
        for (index in 0 until frameCount * outputChannelCount) {
            val pcm = (samples[index].coerceIn(-1f, 1f) * 32767f).toInt()
            bytes[byteIndex] = (pcm and 0xFF).toByte()
            bytes[byteIndex + 1] = ((pcm ushr 8) and 0xFF).toByte()
            byteIndex += 2
        }
        stream.write(bytes)
    }

    private fun writeAscii(stream: java.io.OutputStream, value: String) {
        stream.write(value.toByteArray(Charsets.US_ASCII))
    }

    private fun writeIntLe(stream: java.io.OutputStream, value: Int) {
        stream.write(value and 0xFF)
        stream.write((value ushr 8) and 0xFF)
        stream.write((value ushr 16) and 0xFF)
        stream.write((value ushr 24) and 0xFF)
    }

    private fun writeShortLe(stream: java.io.OutputStream, value: Int) {
        stream.write(value and 0xFF)
        stream.write((value ushr 8) and 0xFF)
    }

    private fun currentDurationMsUnsafe(): Int {
        return tracks.values.maxOfOrNull { track ->
            (((track.startFrame + track.clipFrameCount) / mixSampleRate.toDouble()) * 1000.0).toInt()
        } ?: 0
    }

    private fun maxFrameCountUnsafe(): Int {
        return tracks.values.maxOfOrNull { track ->
            (track.startFrame + track.clipFrameCount).toInt()
        } ?: 0
    }

    private fun resetReverbsUnsafe() {
        tracks.values.forEach { track -> track.resetReverb() }
    }

    private fun gainsFor(volume: Float, pan: Float): Pair<Float, Float> {
        val normalized = ((pan.coerceIn(-1f, 1f) + 1f) / 2f)
        val leftGain = volume * cos(normalized * (Math.PI / 2.0)).toFloat()
        val rightGain = volume * sin(normalized * (Math.PI / 2.0)).toFloat()
        return leftGain to rightGain
    }

    private fun decodeTrack(sourcePath: String, id: String): DecodedTrack {
        val extractor = MediaExtractor()
        val uri = Uri.parse(sourcePath)
        if (uri.scheme != null) {
            extractor.setDataSource(context, uri, emptyMap())
        } else {
            extractor.setDataSource(sourcePath)
        }

        val audioTrackIndex = (0 until extractor.trackCount).firstOrNull { index ->
            extractor.getTrackFormat(index)
                .getString(MediaFormat.KEY_MIME)
                ?.startsWith("audio/") == true
        } ?: error("No audio track found in selected file.")

        extractor.selectTrack(audioTrackIndex)
        val inputFormat = extractor.getTrackFormat(audioTrackIndex)
        val mimeType = inputFormat.getString(MediaFormat.KEY_MIME)
            ?: error("Unable to identify audio codec.")
        val decoder = MediaCodec.createDecoderByType(mimeType)
        decoder.configure(inputFormat, null, null, 0)
        decoder.start()

        val pcmOutput = ByteArrayOutputStream()
        val bufferInfo = MediaCodec.BufferInfo()

        var inputDone = false
        var outputDone = false
        var pcmEncoding = AudioFormat.ENCODING_PCM_16BIT
        var sourceSampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        var sourceChannelCount = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

        while (!outputDone) {
            if (!inputDone) {
                val inputIndex = decoder.dequeueInputBuffer(10_000)
                if (inputIndex >= 0) {
                    val inputBuffer = decoder.getInputBuffer(inputIndex)
                        ?: error("Decoder input buffer unavailable.")
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)
                    if (sampleSize < 0) {
                        decoder.queueInputBuffer(
                            inputIndex,
                            0,
                            0,
                            0L,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                        )
                        inputDone = true
                    } else {
                        decoder.queueInputBuffer(
                            inputIndex,
                            0,
                            sampleSize,
                            extractor.sampleTime,
                            0,
                        )
                        extractor.advance()
                    }
                }
            }

            when (val outputIndex = decoder.dequeueOutputBuffer(bufferInfo, 10_000)) {
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    val outputFormat = decoder.outputFormat
                    sourceSampleRate = outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    sourceChannelCount = outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                        outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)
                    ) {
                        pcmEncoding = outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    }
                }

                MediaCodec.INFO_TRY_AGAIN_LATER -> Unit

                else -> if (outputIndex >= 0) {
                    val outputBuffer = decoder.getOutputBuffer(outputIndex)
                        ?: error("Decoder output buffer unavailable.")
                    if (bufferInfo.size > 0) {
                        outputBuffer.position(bufferInfo.offset)
                        outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                        val chunk = ByteArray(bufferInfo.size)
                        outputBuffer.get(chunk)
                        pcmOutput.write(chunk)
                    }
                    decoder.releaseOutputBuffer(outputIndex, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                }
            }
        }

        decoder.stop()
        decoder.release()
        extractor.release()

        val stereoSamples = pcmToStereoFloatArray(
            data = pcmOutput.toByteArray(),
            pcmEncoding = pcmEncoding,
            channelCount = sourceChannelCount,
        )
        val resampledSamples = if (sourceSampleRate != mixSampleRate) {
            resampleStereo(
                source = stereoSamples,
                sourceSampleRate = sourceSampleRate,
                targetSampleRate = mixSampleRate,
            )
        } else {
            stereoSamples
        }

        return DecodedTrack(
            id = id,
            sourcePath = sourcePath,
            frameCount = resampledSamples.size / 2,
            samples = resampledSamples,
            waveformPeaks = buildWaveformPeaks(resampledSamples),
            durationMs = ((resampledSamples.size / 2) / mixSampleRate.toDouble() * 1000.0).toInt(),
            sampleRate = mixSampleRate,
        )
    }

    private fun pcmToStereoFloatArray(
        data: ByteArray,
        pcmEncoding: Int,
        channelCount: Int,
    ): FloatArray {
        val bytesPerSample = when (pcmEncoding) {
            AudioFormat.ENCODING_PCM_FLOAT -> 4
            AudioFormat.ENCODING_PCM_8BIT -> 1
            else -> 2
        }
        val safeChannelCount = channelCount.coerceAtLeast(1)
        val frameCount = data.size / (bytesPerSample * safeChannelCount)
        val output = FloatArray(frameCount * 2)
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)

        repeat(frameCount) { frame ->
            val leftSample: Float
            val rightSample: Float
            if (safeChannelCount == 1) {
                val monoSample = readPcmSample(buffer, pcmEncoding)
                leftSample = monoSample
                rightSample = monoSample
            } else {
                leftSample = readPcmSample(buffer, pcmEncoding)
                rightSample = readPcmSample(buffer, pcmEncoding)
                repeat(safeChannelCount - 2) {
                    readPcmSample(buffer, pcmEncoding)
                }
            }

            val targetIndex = frame * 2
            output[targetIndex] = leftSample
            output[targetIndex + 1] = rightSample
        }

        return output
    }

    private fun readPcmSample(buffer: ByteBuffer, pcmEncoding: Int): Float {
        return when (pcmEncoding) {
            AudioFormat.ENCODING_PCM_FLOAT -> buffer.float
            AudioFormat.ENCODING_PCM_8BIT -> (buffer.get().toInt() - 128) / 128f
            else -> buffer.short / 32768f
        }
    }

    private fun resampleStereo(
        source: FloatArray,
        sourceSampleRate: Int,
        targetSampleRate: Int,
    ): FloatArray {
        if (sourceSampleRate == targetSampleRate) {
            return source
        }

        val sourceFrameCount = source.size / 2
        val targetFrameCount = ceil(
            sourceFrameCount * (targetSampleRate / sourceSampleRate.toDouble()),
        ).toInt()
        val output = FloatArray(targetFrameCount * 2)

        for (frame in 0 until targetFrameCount) {
            val sourcePosition = frame * (sourceSampleRate / targetSampleRate.toDouble())
            val leftSample = interpolateChannel(source, sourceFrameCount, sourcePosition, 0)
            val rightSample = interpolateChannel(source, sourceFrameCount, sourcePosition, 1)
            val targetIndex = frame * 2
            output[targetIndex] = leftSample
            output[targetIndex + 1] = rightSample
        }

        return output
    }

    private fun buildWaveformPeaks(samples: FloatArray): List<Double> {
        val frameCount = samples.size / 2
        if (frameCount == 0) {
            return emptyList()
        }

        val targetPeakCount = min(2_000, max(200, frameCount / 256))
        val samplesPerPeak = max(1, frameCount / targetPeakCount)
        val peaks = ArrayList<Double>(targetPeakCount)

        var frameIndex = 0
        while (frameIndex < frameCount) {
            var maxMagnitude = 0f
            val endFrame = min(frameCount, frameIndex + samplesPerPeak)
            for (cursor in frameIndex until endFrame) {
                val left = kotlin.math.abs(samples[cursor * 2])
                val right = kotlin.math.abs(samples[cursor * 2 + 1])
                maxMagnitude = max(maxMagnitude, max(left, right))
            }
            peaks.add(maxMagnitude.coerceIn(0f, 1f).toDouble())
            frameIndex = endFrame
        }

        return peaks
    }

    private fun interpolateChannel(
        samples: FloatArray,
        frameCount: Int,
        position: Double,
        channelOffset: Int,
    ): Float {
        if (frameCount == 0) {
            return 0f
        }
        if (position <= 0) {
            return samples[channelOffset]
        }
        if (position >= frameCount - 1) {
            val tailIndex = ((frameCount - 1) * 2) + channelOffset
            return samples[tailIndex]
        }

        val baseFrame = floor(position).toInt()
        val nextFrame = min(frameCount - 1, baseFrame + 1)
        val fraction = (position - baseFrame).toFloat()
        val baseSample = samples[(baseFrame * 2) + channelOffset]
        val nextSample = samples[(nextFrame * 2) + channelOffset]
        return baseSample + (nextSample - baseSample) * fraction
    }
}

private class Mp3Encoder(
    sampleRate: Int,
    private val channelCount: Int,
    bitRateKbps: Int,
) : java.io.Closeable {
    private val handle = LameMp3Native.create(sampleRate, channelCount, bitRateKbps)
    private var closed = false

    fun encodeBlock(
        stream: java.io.OutputStream,
        samples: FloatArray,
        frameCount: Int,
    ) {
        if (closed || frameCount <= 0) {
            return
        }
        val sampleCount = frameCount * channelCount
        val pcm = ShortArray(sampleCount)
        for (index in 0 until sampleCount) {
            pcm[index] = (samples[index].coerceIn(-1f, 1f) * 32767f)
                .toInt()
                .coerceIn(-32768, 32767)
                .toShort()
        }
        val encoded = LameMp3Native.encode(handle, pcm, frameCount)
        if (encoded.isNotEmpty()) {
            stream.write(encoded)
        }
    }

    fun flush(stream: java.io.OutputStream) {
        if (closed) {
            return
        }
        val encoded = LameMp3Native.flush(handle)
        if (encoded.isNotEmpty()) {
            stream.write(encoded)
        }
    }

    override fun close() {
        if (closed) {
            return
        }
        closed = true
        LameMp3Native.release(handle)
    }
}

private class VocalBackingSeparator(sampleRate: Int) {
    private val centerBand = VocalBandFilter(sampleRate)
    private val sideBand = VocalBandFilter(sampleRate)
    private var vocalGate = 0f

    fun process(
        input: FloatArray,
        vocals: FloatArray,
        backing: FloatArray,
        frameCount: Int,
    ) {
        for (frame in 0 until frameCount) {
            val index = frame * 2
            val left = input[index].coerceIn(-1f, 1f)
            val right = input[index + 1].coerceIn(-1f, 1f)
            val center = (left + right) * 0.5f
            val side = (left - right) * 0.5f

            val centerVocalBand = centerBand.process(center)
            val sideVocalBand = sideBand.process(side)
            val centerEnergy = abs(centerVocalBand)
            val sideEnergy = abs(sideVocalBand)
            val centerDominance = (
                centerEnergy / (centerEnergy + sideEnergy * 1.8f + 0.0006f)
                ).coerceIn(0f, 1f)
            val gateTarget = ((centerDominance - 0.42f) / 0.44f).coerceIn(0f, 1f)
            vocalGate += (gateTarget - vocalGate) * 0.14f

            // Quick Split is not a neural stem separator. This version is intentionally
            // more aggressive: it isolates center vocal-band energy for vocals and
            // suppresses the same band from the backing stem.
            val vocalEstimate = centerVocalBand * (0.35f + vocalGate * 0.95f)
            val backingRemoval = centerVocalBand * (0.95f + vocalGate * 0.55f)
            val sideReinforcement = sideVocalBand * 0.12f

            val vocalOutput = (vocalEstimate * 1.7f).coerceIn(-1f, 1f)
            vocals[index] = vocalOutput
            vocals[index + 1] = vocalOutput
            backing[index] = (left - backingRemoval + sideReinforcement).coerceIn(-1f, 1f)
            backing[index + 1] = (right - backingRemoval - sideReinforcement).coerceIn(-1f, 1f)
        }
    }
}

private class VocalBandFilter(sampleRate: Int) {
    private val lowPassAlpha = onePoleLowPassAlpha(sampleRate, 7_800f)
    private val highPassAlpha = onePoleHighPassAlpha(sampleRate, 105f)
    private var lowPassStateA = 0f
    private var lowPassStateB = 0f
    private var highPassPreviousInputA = 0f
    private var highPassPreviousOutputA = 0f
    private var highPassPreviousInputB = 0f
    private var highPassPreviousOutputB = 0f

    fun process(sample: Float): Float {
        lowPassStateA += lowPassAlpha * (sample - lowPassStateA)
        lowPassStateB += lowPassAlpha * (lowPassStateA - lowPassStateB)
        val highPassedA = highPassAlpha * (
            highPassPreviousOutputA + lowPassStateB - highPassPreviousInputA
            )
        highPassPreviousInputA = lowPassStateB
        highPassPreviousOutputA = highPassedA

        val highPassedB = highPassAlpha * (
            highPassPreviousOutputB + highPassedA - highPassPreviousInputB
            )
        highPassPreviousInputB = highPassedA
        highPassPreviousOutputB = highPassedB
        return highPassedB
    }

    private fun onePoleLowPassAlpha(sampleRate: Int, cutoffHz: Float): Float {
        return (1.0 - exp(-2.0 * Math.PI * cutoffHz / sampleRate))
            .toFloat()
            .coerceIn(0.0001f, 1f)
    }

    private fun onePoleHighPassAlpha(sampleRate: Int, cutoffHz: Float): Float {
        val dt = 1.0 / sampleRate
        val rc = 1.0 / (2.0 * Math.PI * cutoffHz)
        return (rc / (rc + dt)).toFloat().coerceIn(0.0001f, 1f)
    }
}

private class AudioOutputTarget(
    val stream: java.io.OutputStream,
    val displayPath: String,
) : java.io.Closeable {
    override fun close() {
        stream.close()
    }
}

private data class DecodedTrack(
    val id: String,
    val sourcePath: String,
    val frameCount: Int,
    val samples: FloatArray,
    val waveformPeaks: List<Double>,
    val durationMs: Int,
    val sampleRate: Int,
    var volume: Float = 1f,
    var pan: Float = 0f,
    var reverb: Float = 0f,
    var reverbMix: Float = 0.48f,
    var reverbRoomSize: Float = 0.58f,
    var reverbDecay: Float = 0.62f,
    var reverbDamp: Float = 0.42f,
    var reverbPreDelayMs: Float = 32f,
    var reverbWidth: Float = 0.78f,
    var muted: Boolean = false,
    var startFrame: Double = 0.0,
    var sourceOffsetFrame: Double = 0.0,
    var clipFrameCount: Double = frameCount.toDouble(),
) {
    private var reverbHandle: Long = Freeverb3Native.create(sampleRate)
    private var released = false

    @Synchronized
    fun release() {
        if (released) {
            return
        }
        Freeverb3Native.release(reverbHandle)
        released = true
    }

    @Synchronized
    fun resetReverb() {
        if (!released) {
            Freeverb3Native.reset(reverbHandle)
        }
    }

    @Synchronized
    fun setReverbSettings(
        mix: Float,
        roomSize: Float,
        decay: Float,
        damp: Float,
        preDelayMs: Float,
        width: Float,
    ) {
        reverbMix = mix.coerceIn(0f, 1f)
        reverbRoomSize = roomSize.coerceIn(0f, 1f)
        reverbDecay = decay.coerceIn(0f, 1f)
        reverbDamp = damp.coerceIn(0f, 1f)
        reverbPreDelayMs = preDelayMs.coerceIn(0f, 120f)
        reverbWidth = width.coerceIn(0f, 1f)
    }

    @Synchronized
    fun renderBlock(
        blockStartFrame: Double,
        speed: Double,
        frameCount: Int,
        inputBuffer: FloatArray,
        outputBuffer: FloatArray,
    ) {
        if (released || frameCount <= 0) {
            for (frameIndex in 0 until frameCount.coerceAtLeast(0)) {
                val writeIndex = frameIndex * 2
                outputBuffer[writeIndex] = 0f
                outputBuffer[writeIndex + 1] = 0f
            }
            return
        }

        for (frameIndex in 0 until frameCount) {
            val dry = sampleAt(blockStartFrame + (frameIndex * speed))
            val writeIndex = frameIndex * 2
            inputBuffer[writeIndex] = dry.first
            inputBuffer[writeIndex + 1] = dry.second
        }

        val amount = (reverb * reverbMix).coerceIn(0f, 1f)
        Freeverb3Native.setParameters(
            handle = reverbHandle,
            amount = amount,
            roomSize = reverbRoomSize,
            decay = reverbDecay,
            damp = reverbDamp,
            preDelayMs = reverbPreDelayMs,
            width = reverbWidth,
        )
        Freeverb3Native.process(
            handle = reverbHandle,
            input = inputBuffer,
            output = outputBuffer,
            frames = frameCount,
        )
    }

    private fun sampleAt(frame: Double): Pair<Float, Float> {
        val localFrame = frame - startFrame
        if (frameCount == 0) {
            return 0f to 0f
        }
        if (localFrame < 0.0 || localFrame >= clipFrameCount) {
            return 0f to 0f
        }
        val sourceFrame = sourceOffsetFrame + localFrame
        if (sourceFrame < 0.0 || sourceFrame >= frameCount) {
            return 0f to 0f
        }
        val left = interpolate(sourceFrame, 0)
        val right = interpolate(sourceFrame, 1)
        return left to right
    }

    private fun interpolate(frame: Double, channelOffset: Int): Float {
        if (frame <= 0) {
            return samples[channelOffset]
        }
        if (frame >= frameCount - 1) {
            return samples[((frameCount - 1) * 2) + channelOffset]
        }
        val baseFrame = floor(frame).toInt()
        val nextFrame = min(frameCount - 1, baseFrame + 1)
        val fraction = (frame - baseFrame).toFloat()
        val baseValue = samples[(baseFrame * 2) + channelOffset]
        val nextValue = samples[(nextFrame * 2) + channelOffset]
        return baseValue + (nextValue - baseValue) * fraction
    }
}
