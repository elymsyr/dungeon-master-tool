package com.elymsyr.dungeon_master_tool

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Manages an external-display Presentation that hosts its own FlutterEngine
 * running the player projection UI.
 *
 * Platform channel: `com.elymsyr.dungeon_master_tool/screencast`
 * Event channel:    `com.elymsyr.dungeon_master_tool/screencast/events`
 */
class ScreencastPlugin private constructor(
    private val engine: FlutterEngine,
    private val activity: Activity
) : MethodChannel.MethodCallHandler, DisplayManager.DisplayListener {

    companion object {
        private const val CHANNEL = "com.elymsyr.dungeon_master_tool/screencast"
        private const val EVENT_CHANNEL = "com.elymsyr.dungeon_master_tool/screencast/events"
        private const val PRESENTATION_ENGINE_ID = "screencast_presentation_engine"

        fun registerWith(flutterEngine: FlutterEngine, activity: Activity) {
            val plugin = ScreencastPlugin(flutterEngine, activity)
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler(plugin)
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
                .setStreamHandler(plugin.eventStreamHandler)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val displayManager: DisplayManager
        get() = activity.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

    private var presentation: PlayerPresentation? = null
    private var presentationEngine: FlutterEngine? = null
    private var renderChannel: MethodChannel? = null
    private var presentationReady = false
    private var pendingFullState: Map<*, *>? = null
    private var eventSink: EventChannel.EventSink? = null
    private var listeningForDisplays = false

    // -- EventChannel StreamHandler --

    val eventStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
            startDisplayListener()
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            stopDisplayListener()
        }
    }

    // -- MethodChannel handler --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailableDisplays" -> getAvailableDisplays(result)
            "startPresentation" -> {
                val displayId = (call.argument<String>("displayId"))
                if (displayId == null) {
                    result.error("INVALID_ARG", "displayId required", null)
                } else {
                    startPresentation(displayId, result)
                }
            }
            "stopPresentation" -> {
                stopPresentation()
                result.success(null)
            }
            "pushState" -> {
                val stateJson = call.arguments as? Map<*, *>
                pushStateToPresentationEngine(stateJson)
                result.success(true)
            }
            "pushBattleMapPatch" -> {
                val args = call.arguments as? Map<*, *>
                pushBattleMapPatchToPresentationEngine(args)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // -- Display enumeration --

    private fun getAvailableDisplays(result: MethodChannel.Result) {
        val displays = displayManager.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
        val list = displays.map { d ->
            mapOf(
                "id" to d.displayId.toString(),
                "name" to (d.name ?: "External Display"),
                "width" to d.mode.physicalWidth,
                "height" to d.mode.physicalHeight
            )
        }
        result.success(list)
    }

    // -- Presentation lifecycle --

    private fun startPresentation(displayId: String, result: MethodChannel.Result) {
        stopPresentation()

        val targetDisplay = displayManager
            .getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            .firstOrNull { it.displayId.toString() == displayId }

        if (targetDisplay == null) {
            result.error("DISPLAY_NOT_FOUND", "Display $displayId not found", null)
            return
        }

        try {
            // Create a dedicated FlutterEngine for the presentation.
            val pEngine = FlutterEngine(activity)
            pEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "screencastMain"
                )
            )
            FlutterEngineCache.getInstance().put(PRESENTATION_ENGINE_ID, pEngine)
            presentationEngine = pEngine

            // Set up the render channel once and listen for the Dart-side
            // "engineReady" handshake before forwarding state.
            val rc = MethodChannel(
                pEngine.dartExecutor.binaryMessenger,
                "com.elymsyr.dungeon_master_tool/screencast_render"
            )
            rc.setMethodCallHandler { call, res ->
                when (call.method) {
                    "engineReady" -> {
                        presentationReady = true
                        val buffered = pendingFullState
                        pendingFullState = null
                        if (buffered != null) {
                            rc.invokeMethod("applyState", buffered, LoggingResult("applyState"))
                        }
                        res.success(null)
                    }
                    else -> res.notImplemented()
                }
            }
            renderChannel = rc

            val pres = PlayerPresentation(activity, targetDisplay, pEngine)
            pres.show()
            presentation = pres

            result.success(true)
        } catch (e: Exception) {
            renderChannel?.setMethodCallHandler(null)
            renderChannel = null
            presentationReady = false
            pendingFullState = null
            presentationEngine?.destroy()
            presentationEngine = null
            FlutterEngineCache.getInstance().remove(PRESENTATION_ENGINE_ID)
            result.error("PRESENTATION_FAILED", e.message, null)
        }
    }

    private fun stopPresentation() {
        presentation?.dismiss()
        presentation = null
        renderChannel?.setMethodCallHandler(null)
        renderChannel = null
        presentationReady = false
        pendingFullState = null
        presentationEngine?.destroy()
        presentationEngine = null
        FlutterEngineCache.getInstance().remove(PRESENTATION_ENGINE_ID)
    }

    // -- State push to presentation engine --

    private fun pushStateToPresentationEngine(stateJson: Map<*, *>?) {
        val rc = renderChannel ?: return
        if (!presentationReady) {
            // Only buffer full-state pushes; patches are dropped because the
            // buffered full state already contains their effects.
            val isPatch = stateJson?.get("type") == "patch"
            if (!isPatch) {
                pendingFullState = stateJson
            }
            return
        }
        handler.post {
            rc.invokeMethod("applyState", stateJson, LoggingResult("applyState"))
        }
    }

    private fun pushBattleMapPatchToPresentationEngine(args: Map<*, *>?) {
        val rc = renderChannel ?: return
        if (!presentationReady) return // Covered by the buffered full state.
        handler.post {
            rc.invokeMethod("applyBattleMapPatch", args, LoggingResult("applyBattleMapPatch"))
        }
    }

    // -- Display listener --

    private fun startDisplayListener() {
        if (listeningForDisplays) return
        displayManager.registerDisplayListener(this, handler)
        listeningForDisplays = true
    }

    private fun stopDisplayListener() {
        if (!listeningForDisplays) return
        displayManager.unregisterDisplayListener(this)
        listeningForDisplays = false
    }

    override fun onDisplayAdded(displayId: Int) {}

    override fun onDisplayChanged(displayId: Int) {}

    override fun onDisplayRemoved(displayId: Int) {
        // If the removed display is the one we're presenting on, tear down.
        val currentDisplay = presentation?.display
        if (currentDisplay != null && currentDisplay.displayId == displayId) {
            stopPresentation()
            eventSink?.success(mapOf("event" to "displayDisconnected"))
        }
    }

    // -- Helpers --

    private class LoggingResult(private val methodName: String) : MethodChannel.Result {
        override fun success(result: Any?) { /* OK */ }
        override fun error(code: String, msg: String?, details: Any?) {
            Log.e("ScreencastPlugin", "$methodName error: $code $msg")
        }
        override fun notImplemented() {
            Log.w("ScreencastPlugin", "$methodName not implemented on Dart side")
        }
    }

    // -- Inner Presentation class --

    /**
     * A [Presentation] that hosts a [FlutterView] driven by a dedicated
     * [FlutterEngine]. The engine runs the `screencastMain` entry point
     * which renders [PlayerWindowRoot].
     */
    private class PlayerPresentation(
        context: Context,
        display: Display,
        private val flutterEngine: FlutterEngine
    ) : Presentation(context, display) {

        private var flutterView: FlutterView? = null

        override fun onCreate(savedInstanceState: Bundle?) {
            super.onCreate(savedInstanceState)

            // Show black instead of white before Flutter paints its first frame.
            window?.decorView?.setBackgroundColor(android.graphics.Color.BLACK)

            // TextureView renders within the standard view hierarchy instead of
            // a separate surface, which composites correctly on external displays.
            val fv = FlutterView(context, FlutterTextureView(context))
            fv.attachToFlutterEngine(flutterEngine)
            setContentView(fv, android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            ))
            flutterView = fv
        }

        override fun dismiss() {
            flutterView?.detachFromFlutterEngine()
            flutterView = null
            super.dismiss()
        }
    }
}
