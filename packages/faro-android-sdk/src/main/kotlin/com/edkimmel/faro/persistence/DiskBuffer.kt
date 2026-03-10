package com.edkimmel.faro.persistence

import com.edkimmel.faro.internal.InternalLogger
import com.edkimmel.faro.transport.TransportBody
import java.io.File
import java.util.UUID

data class DiskBufferConfig(
    val maxDiskUsageBytes: Long = 5L * 1024 * 1024, // 5MB
    val maxFileAgeMs: Long = 24L * 60 * 60 * 1000,  // 24 hours
    val crashDir: String = "faro_crashes",
    val signalsDir: String = "faro_signals"
)

internal class DiskBuffer(
    private val baseDir: File,
    private val config: DiskBufferConfig,
    private val logger: InternalLogger
) {
    private val signalsDir = File(baseDir, config.signalsDir).apply { mkdirs() }
    private val crashDir = File(baseDir, config.crashDir).apply { mkdirs() }

    fun writeSignal(body: TransportBody) {
        try {
            enforceStorageLimits()
            val fileName = "${System.currentTimeMillis()}_${UUID.randomUUID()}.json"
            val file = File(signalsDir, fileName)
            file.writeText(TransportBody.toJson(body))
            logger.debug("Signal written to disk: ${file.name}")
        } catch (e: Exception) {
            logger.error("Failed to write signal to disk", e)
        }
    }

    fun writeCrash(body: TransportBody) {
        try {
            val fileName = "crash_${System.currentTimeMillis()}_${UUID.randomUUID()}.json"
            val file = File(crashDir, fileName)
            // Write synchronously for crash scenarios
            file.writeText(TransportBody.toJson(body))
        } catch (e: Exception) {
            // Best effort - we're in a crash handler
        }
    }

    fun readPendingSignals(): List<SignalFile> {
        return readFilesFromDir(signalsDir)
    }

    fun readPendingCrashes(): List<SignalFile> {
        return readFilesFromDir(crashDir)
    }

    private fun readFilesFromDir(dir: File): List<SignalFile> {
        return dir.listFiles()
            ?.filter { it.isFile && it.extension == "json" }
            ?.sortedBy { it.name }
            ?.mapNotNull { file ->
                try {
                    val body = TransportBody.fromJson(file.readText())
                    SignalFile(file, body)
                } catch (e: Exception) {
                    logger.error("Failed to read signal file: ${file.name}", e)
                    file.delete()
                    null
                }
            } ?: emptyList()
    }

    fun deleteFile(signalFile: SignalFile) {
        try {
            signalFile.file.delete()
        } catch (e: Exception) {
            logger.error("Failed to delete signal file: ${signalFile.file.name}", e)
        }
    }

    fun enforceStorageLimits() {
        try {
            // Delete old files
            val now = System.currentTimeMillis()
            val allFiles = getAllFiles()
            for (file in allFiles) {
                if (now - file.lastModified() > config.maxFileAgeMs) {
                    file.delete()
                    logger.debug("Deleted expired signal file: ${file.name}")
                }
            }

            // Enforce total size limit
            var totalSize = getAllFiles().sumOf { it.length() }
            val sortedFiles = getAllFiles().sortedBy { it.lastModified() }
            for (file in sortedFiles) {
                if (totalSize <= config.maxDiskUsageBytes) break
                val fileSize = file.length()
                file.delete()
                totalSize -= fileSize
                logger.debug("Deleted signal file to enforce size limit: ${file.name}")
            }
        } catch (e: Exception) {
            logger.error("Error enforcing storage limits", e)
        }
    }

    private fun getAllFiles(): List<File> {
        val signalFiles = signalsDir.listFiles()?.toList() ?: emptyList()
        val crashFiles = crashDir.listFiles()?.toList() ?: emptyList()
        return signalFiles + crashFiles
    }

    fun clear() {
        signalsDir.listFiles()?.forEach { it.delete() }
        crashDir.listFiles()?.forEach { it.delete() }
    }
}
