import Flutter
import UIKit

/// Manages an external-screen window that hosts its own FlutterEngine
/// running the player projection UI.
///
/// Uses UIScreen notifications to detect AirPlay / HDMI / USB-C displays.
///
/// Platform channel: `com.elymsyr.dungeon_master_tool/screencast`
/// Event channel:    `com.elymsyr.dungeon_master_tool/screencast/events`
class ScreencastPlugin: NSObject, FlutterStreamHandler {
    static let channelName = "com.elymsyr.dungeon_master_tool/screencast"
    static let eventChannelName = "com.elymsyr.dungeon_master_tool/screencast/events"
    static let renderChannelName = "com.elymsyr.dungeon_master_tool/screencast_render"

    private weak var rootViewController: UIViewController?
    private var externalWindow: UIWindow?
    private var presentationEngine: FlutterEngine?
    private var renderChannel: FlutterMethodChannel?
    private var presentationReady = false
    private var pendingFullState: [String: Any]?
    private var eventSink: FlutterEventSink?

    static func register(with engine: FlutterEngine, rootViewController: UIViewController?) {
        let plugin = ScreencastPlugin()
        plugin.rootViewController = rootViewController

        let methodChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: engine.binaryMessenger
        )
        methodChannel.setMethodCallHandler(plugin.handle)

        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: engine.binaryMessenger
        )
        eventChannel.setStreamHandler(plugin)
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        startScreenNotifications()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        stopScreenNotifications()
        return nil
    }

    // MARK: - MethodChannel handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAvailableDisplays":
            getAvailableDisplays(result: result)
        case "startPresentation":
            guard let args = call.arguments as? [String: Any],
                  let displayId = args["displayId"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "displayId required", details: nil))
                return
            }
            startPresentation(displayId: displayId, result: result)
        case "stopPresentation":
            stopPresentation()
            result(nil)
        case "pushState":
            let stateJson = call.arguments as? [String: Any]
            pushStateToPresentationEngine(stateJson)
            result(true)
        case "pushBattleMapPatch":
            let args = call.arguments as? [String: Any]
            pushBattleMapPatchToPresentationEngine(args)
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Display enumeration

    private func getAvailableDisplays(result: FlutterResult) {
        var displays: [[String: Any]] = []
        for (index, screen) in UIScreen.screens.enumerated() {
            // Skip the main screen
            if screen == UIScreen.main { continue }
            displays.append([
                "id": "\(index)",
                "name": "External Display \(index)",
                "width": Int(screen.bounds.width * screen.scale),
                "height": Int(screen.bounds.height * screen.scale)
            ])
        }
        result(displays)
    }

    // MARK: - Presentation lifecycle

    private func startPresentation(displayId: String, result: FlutterResult) {
        stopPresentation()

        guard let index = Int(displayId),
              index < UIScreen.screens.count else {
            result(FlutterError(code: "DISPLAY_NOT_FOUND", message: "Display \(displayId) not found", details: nil))
            return
        }

        let targetScreen = UIScreen.screens[index]
        if targetScreen == UIScreen.main {
            result(FlutterError(code: "INVALID_DISPLAY", message: "Cannot present on main screen", details: nil))
            return
        }

        // Create a dedicated FlutterEngine for the external screen.
        let engine = FlutterEngine(name: "screencast_presentation_engine")
        engine.run(withEntrypoint: "screencastMain")
        presentationEngine = engine

        // Set up the render channel once and listen for the Dart-side
        // "engineReady" handshake before forwarding state.
        let rc = FlutterMethodChannel(
            name: ScreencastPlugin.renderChannelName,
            binaryMessenger: engine.binaryMessenger
        )
        rc.setMethodCallHandler { [weak self] call, res in
            guard let self = self else { return }
            switch call.method {
            case "engineReady":
                self.presentationReady = true
                if let buffered = self.pendingFullState {
                    self.pendingFullState = nil
                    rc.invokeMethod("applyState", arguments: buffered)
                }
                res(nil)
            default:
                res(FlutterMethodNotImplemented)
            }
        }
        renderChannel = rc

        // Create a window on the external screen.
        let window = UIWindow(frame: targetScreen.bounds)
        window.screen = targetScreen

        let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        window.rootViewController = flutterVC
        window.isHidden = false
        externalWindow = window

        result(true)
    }

    private func stopPresentation() {
        externalWindow?.isHidden = true
        externalWindow?.rootViewController = nil
        externalWindow = nil
        renderChannel?.setMethodCallHandler(nil)
        renderChannel = nil
        presentationReady = false
        pendingFullState = nil
        presentationEngine?.destroyContext()
        presentationEngine = nil
    }

    // MARK: - State push

    private func pushStateToPresentationEngine(_ stateJson: [String: Any]?) {
        guard let rc = renderChannel else { return }
        if !presentationReady {
            // Only buffer full-state pushes; patches are dropped because the
            // buffered full state already contains their effects.
            let isPatch = stateJson?["type"] as? String == "patch"
            if !isPatch {
                pendingFullState = stateJson
            }
            return
        }
        rc.invokeMethod("applyState", arguments: stateJson)
    }

    private func pushBattleMapPatchToPresentationEngine(_ args: [String: Any]?) {
        guard let rc = renderChannel else { return }
        if !presentationReady { return } // Covered by the buffered full state.
        rc.invokeMethod("applyBattleMapPatch", arguments: args)
    }

    // MARK: - Screen notifications

    private func startScreenNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidDisconnect(_:)),
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    private func stopScreenNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIScreen.didDisconnectNotification,
            object: nil
        )
    }

    @objc private func screenDidDisconnect(_ notification: Notification) {
        stopPresentation()
        eventSink?(["event": "displayDisconnected"])
    }
}
