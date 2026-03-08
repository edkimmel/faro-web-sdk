package com.grafana.faro.instrumentations.lifecycle

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.SystemClock
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import com.grafana.faro.FaroInstance
import com.grafana.faro.instrumentations.Instrumentation

class AppLifecycleInstrumentation : Instrumentation {
    override val name = "faro-android:instrumentation-lifecycle"

    private var faro: FaroInstance? = null
    private var activityCallbacks: Application.ActivityLifecycleCallbacks? = null
    private var processObserver: DefaultLifecycleObserver? = null
    private val appStartTimeMs = SystemClock.elapsedRealtime()

    override fun install(faro: FaroInstance) {
        this.faro = faro
        val app = faro.application

        // Report app start time
        val startDurationMs = (SystemClock.elapsedRealtime() - appStartTimeMs).toDouble()
        faro.pushMeasurement(
            type = "app_startup",
            values = mapOf("duration_ms" to startDurationMs)
        )

        // Track process lifecycle (foreground/background)
        processObserver = object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) {
                faro.pushEvent("app_foreground", domain = "app")
            }

            override fun onStop(owner: LifecycleOwner) {
                faro.pushEvent("app_background", domain = "app")
            }
        }
        ProcessLifecycleOwner.get().lifecycle.addObserver(processObserver!!)

        // Track activity lifecycle
        activityCallbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                faro.pushEvent(
                    "activity_created",
                    attributes = mapOf("activity" to activity.javaClass.simpleName),
                    domain = "app"
                )
            }

            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {
                faro.setView(activity.javaClass.simpleName)
            }
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        }
        app.registerActivityLifecycleCallbacks(activityCallbacks!!)

        faro.pushEvent("app_start", domain = "app")
    }

    override fun uninstall() {
        activityCallbacks?.let {
            faro?.application?.unregisterActivityLifecycleCallbacks(it)
        }
        processObserver?.let {
            ProcessLifecycleOwner.get().lifecycle.removeObserver(it)
        }
        activityCallbacks = null
        processObserver = null
        faro = null
    }
}
