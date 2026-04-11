#ifndef RUNNER_SCREENCAST_PLUGIN_H_
#define RUNNER_SCREENCAST_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <memory>
#include <string>

namespace flutter {
class FlutterEngine;
class FlutterViewController;
class PluginRegistrarWindows;
}  // namespace flutter

// Windows implementation of the screencast platform channel.
//
// Enumerates external monitors via EnumDisplayMonitors, creates a borderless
// popup window on the target monitor hosting a dedicated FlutterViewController
// running the "screencastMain" entry point, and forwards projection state
// from the main engine to the presentation engine via a render channel.
//
// Platform channel:  com.elymsyr.dungeon_master_tool/screencast
// Event channel:     com.elymsyr.dungeon_master_tool/screencast/events
// Render channel:    com.elymsyr.dungeon_master_tool/screencast_render
class ScreencastPlugin {
 public:
  // Registers the plugin with the given engine. Must be called after the
  // engine is fully initialized (after RegisterPlugins in FlutterWindow).
  static void RegisterWithEngine(flutter::FlutterEngine* engine);

  ~ScreencastPlugin();

  // Prevent copying.
  ScreencastPlugin(const ScreencastPlugin&) = delete;
  ScreencastPlugin& operator=(const ScreencastPlugin&) = delete;

 private:
  explicit ScreencastPlugin(flutter::FlutterEngine* engine);

  // Method channel handler.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Method implementations.
  void GetAvailableDisplays(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartPresentation(
      const std::string& display_id,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopPresentation();
  void PushState(const flutter::EncodableValue* state);
  void PushBattleMapPatch(const flutter::EncodableValue* args);

  // WM_DISPLAYCHANGE handler registered via PluginRegistrarWindows.
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam);

  // WndProc for the presentation popup window.
  static LRESULT CALLBACK PresentationWndProc(HWND hwnd, UINT message,
                                              WPARAM wparam, LPARAM lparam);

  // Channels on the main engine.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // Windows registrar for WM_DISPLAYCHANGE delegate.
  flutter::PluginRegistrarWindows* registrar_windows_ = nullptr;
  int window_proc_delegate_id_ = 0;

  // Presentation state.
  HWND presentation_hwnd_ = nullptr;
  std::unique_ptr<flutter::FlutterViewController> presentation_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      render_channel_;
  bool presentation_ready_ = false;
  std::unique_ptr<flutter::EncodableValue> pending_full_state_;
  HMONITOR target_monitor_ = nullptr;

  // Whether the presentation window class has been registered.
  static bool window_class_registered_;
};

#endif  // RUNNER_SCREENCAST_PLUGIN_H_
