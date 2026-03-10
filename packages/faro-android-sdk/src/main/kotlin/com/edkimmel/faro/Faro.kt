package com.edkimmel.faro

import android.app.Application
import com.edkimmel.faro.internal.InternalLogger

/**
 * Faro Android SDK - Singleton entry point.
 *
 * Initialize once in your Application.onCreate():
 * ```kotlin
 * Faro.initialize(
 *     application = this,
 *     config = FaroConfig(
 *         collectorUrl = "https://your-collector.example.com/collect",
 *         app = MetaApp(name = "MyApp", version = "1.0.0")
 *     )
 * )
 * ```
 *
 * Then access from anywhere:
 * ```kotlin
 * Faro.getInstance()?.pushLog("Something happened")
 * Faro.getInstance()?.pushError(exception)
 * ```
 */
object Faro {
    @Volatile
    private var instance: FaroInstance? = null

    /**
     * Initialize the Faro SDK. Should be called once, typically in Application.onCreate().
     *
     * @param application The Android Application instance
     * @param config The Faro configuration
     * @return The initialized FaroInstance
     * @throws IllegalStateException if Faro is already initialized
     */
    fun initialize(application: Application, config: FaroConfig): FaroInstance {
        synchronized(this) {
            instance?.let { existing ->
                val logger = InternalLogger(config.internalLoggerLevel)
                logger.warn("Faro is already initialized. Returning existing instance.")
                return existing
            }

            val logger = InternalLogger(config.internalLoggerLevel)
            val faroInstance = FaroInstance(application, config, logger)
            faroInstance.start()
            // Only set instance after start() succeeds
            instance = faroInstance
            return faroInstance
        }
    }

    /**
     * Get the initialized Faro instance, if available.
     *
     * @return The FaroInstance, or null if not yet initialized
     */
    fun getInstance(): FaroInstance? {
        return instance
    }

    /**
     * Check if Faro has been initialized.
     */
    fun isInitialized(): Boolean = instance != null

    /**
     * Shutdown and reset the Faro SDK. Primarily for testing.
     */
    fun reset() {
        synchronized(this) {
            instance?.shutdown()
            instance = null
        }
    }
}
