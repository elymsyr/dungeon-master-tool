package com.elymsyr.dungeon_master_tool

import android.app.Activity
import android.app.Presentation
import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import io.flutter.FlutterInjector
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

            val pres = PlayerPresentation(activity, targetDisplay, pEngine)
            pres.show()
            presentation = pres

            result.success(true)
        } catch (e: Exception) {
            presentationEngine?.destroy()
            presentationEngine = null
            FlutterEngineCache.getInstance().remove(PRESENTATION_ENGINE_ID)
            result.error("PRESENTATION_FAILED", e.message, null)
        }
    }

    private fun stopPresentation() {
        presentation?.dismiss()
        presentation = null
        presentationEngine?.destroy()
        presentationEngine = null
        FlutterEngineCache.getInstance().remove(PRESENTATION_ENGINE_ID)
    }

    // -- State push to presentation engine --

    private fun pushStateToPresentationEngine(stateJson: Map<*, *>?) {
        val pEngine = presentationEngine ?: return
        val channel = MethodChannel(
            pEngine.dartExecutor.binaryMessenger,
            "com.elymsyr.dungeon_master_tool/screencast_render"
        )
        handler.post {
            channel.invokeMethod("applyState", stateJson)
        }
    }

    private fun pushBattleMapPatchToPresentationEngine(args: Map<*, *>?) {
        val pEngine = presentationEngine ?: return
        val channel = MethodChannel(
            pEngine.dartExecutor.binaryMessenger,
            "com.elymsyr.dungeon_master_tool/screencast_render"
        )
        handler.post {
            channel.invokeMethod("applyBattleMapPatch", args)
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

            val fv = FlutterView(context)
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
