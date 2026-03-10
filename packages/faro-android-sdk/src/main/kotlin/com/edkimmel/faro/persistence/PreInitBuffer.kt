package com.edkimmel.faro.persistence

import com.edkimmel.faro.internal.Clock
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

/**
 * Configuration for the pre-initialization buffer.
 */
data class PreInitBufferConfig(
    /** Maximum disk usage for pre-init buffered signals. */
    val maxDiskUsageBytes: Long = 1L * 1024 * 1024,
    /** Maximum age of buffered signals before they are discarded (default: 72 hours). */
    val maxFileAgeMs: Long = 72L * 60 * 60 * 1000,
    /** Directory name within the Faro cache directory. */
    val dirName: String = "faro_pre_init"
)

/**
 * A lightweight, static disk buffer for capturing signals before the SDK is initialized.
 *
 * Signals are written as individual JSON files to a known directory. When the SDK
 * initializes, it reads these files, replays them through the normal pipeline, and
 * deletes them.
 *
 * This is intentionally simple — no session, user, or device meta is attached at
 * write time. Meta is attached during replay when the full SDK context is available.
 */
internal class PreInitBuffer private constructor() {

    companion object {
        @Volatile
        private var instance: PreInitBuffer? = null

        fun getInstance(): PreInitBuffer {
            return instance ?: synchronized(this) {
                instance ?: PreInitBuffer().also { instance = it }
            }
        }
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = false
        explicitNulls = false
    }

    private var config = PreInitBufferConfig()
    private var bufferDir: File? = null

    fun configure(cacheDir: File, config: PreInitBufferConfig = PreInitBufferConfig()) {
        synchronized(this) {
            this.config = config
            this.bufferDir = File(File(cacheDir, "faro"), config.dirName).apply { mkdirs() }
        }
    }

    private fun ensureDir(): File? = bufferDir

    // ---- Write methods ----

    fun bufferLog(message: String, level: String, context: Map<String, String>? = null) {
        val entry = PreInitEntry(
            signalType = "log",
            timestamp = Clock.nowTimestamp(),
            log = PreInitLogData(message = message, level = level, context = context)
        )
        writeEntry(entry)
    }

    fun bufferError(
        type: String,
        value: String,
        stacktrace: PreInitStacktrace? = null,
        context: Map<String, String>? = null
    ) {
        val entry = PreInitEntry(
            signalType = "exception",
            timestamp = Clock.nowTimestamp(),
            exception = PreInitExceptionData(
                type = type, value = value, stacktrace = stacktrace, context = context
            )
        )
        writeEntry(entry)
    }

    fun bufferMeasurement(type: String, values: Map<String, Double>, context: Map<String, String>? = null) {
        val entry = PreInitEntry(
            signalType = "measurement",
            timestamp = Clock.nowTimestamp(),
            measurement = PreInitMeasurementData(type = type, values = values, context = context)
        )
        writeEntry(entry)
    }

    fun bufferEvent(name: String, attributes: Map<String, String>? = null, domain: String? = null) {
        val entry = PreInitEntry(
            signalType = "event",
            timestamp = Clock.nowTimestamp(),
            event = PreInitEventData(name = name, domain = domain, attributes = attributes)
        )
        writeEntry(entry)
    }

    // ---- Read and replay ----

    fun readPendingEntries(): List<PreInitEntry> {
        val dir = ensureDir() ?: return emptyList()
        enforceStorageLimits()

        return dir.listFiles()
            ?.filter { it.isFile && it.extension == "json" }
            ?.sortedBy { it.name }
            ?.mapNotNull { file ->
                try {
                    json.decodeFromString<PreInitEntry>(file.readText())
                } catch (_: Exception) {
                    file.delete()
                    null
                }
            } ?: emptyList()
    }

    fun clear() {
        val dir = ensureDir() ?: return
        dir.listFiles()?.forEach { it.delete() }
    }

    fun isEmpty(): Boolean {
        val dir = ensureDir() ?: return true
        return (dir.listFiles()?.size ?: 0) == 0
    }

    // ---- Private ----

    private fun writeEntry(entry: PreInitEntry) {
        val dir = ensureDir() ?: return
        try {
            enforceStorageLimits()
            val fileName = "${System.currentTimeMillis()}_${UUID.randomUUID()}.json"
            val file = File(dir, fileName)
            file.writeText(json.encodeToString(entry))
        } catch (_: Exception) {
            // Best effort — no logger available pre-init
        }
    }

    private fun enforceStorageLimits() {
        val dir = ensureDir() ?: return

        try {
            val now = System.currentTimeMillis()
            val allFiles = dir.listFiles()?.toList() ?: return

            // Delete expired files
            for (file in allFiles) {
                if (now - file.lastModified() > config.maxFileAgeMs) {
                    file.delete()
                }
            }

            // Enforce size limit
            val remaining = dir.listFiles()?.sortedBy { it.name } ?: return
            var totalSize = remaining.sumOf { it.length() }

            if (totalSize > config.maxDiskUsageBytes) {
                for (file in remaining) {
                    if (totalSize <= config.maxDiskUsageBytes) break
                    val fileSize = file.length()
                    file.delete()
                    totalSize -= fileSize
                }
            }
        } catch (_: Exception) {
            // Best effort
        }
    }
}

// ---- Pre-init entry models ----

@Serializable
internal data class PreInitEntry(
    val signalType: String,
    val timestamp: String,
    val log: PreInitLogData? = null,
    val exception: PreInitExceptionData? = null,
    val measurement: PreInitMeasurementData? = null,
    val event: PreInitEventData? = null
)

@Serializable
internal data class PreInitLogData(
    val message: String,
    val level: String,
    val context: Map<String, String>? = null
)

@Serializable
internal data class PreInitExceptionData(
    val type: String,
    val value: String,
    val stacktrace: PreInitStacktrace? = null,
    val context: Map<String, String>? = null
)

@Serializable
internal data class PreInitStacktrace(
    val frames: List<PreInitStackFrame>
)

@Serializable
internal data class PreInitStackFrame(
    val filename: String,
    val function: String,
    val colno: Int? = null,
    val lineno: Int? = null
)

@Serializable
internal data class PreInitMeasurementData(
    val type: String,
    val values: Map<String, Double>,
    val context: Map<String, String>? = null
)

@Serializable
internal data class PreInitEventData(
    val name: String,
    val domain: String? = null,
    val attributes: Map<String, String>? = null
)
