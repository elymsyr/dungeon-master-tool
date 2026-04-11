#include "screencast_plugin.h"

#include <flutter/dart_project.h>
#include <flutter/flutter_engine.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/plugin_registrar_windows.h>

#include <string>
#include <vector>

#include "utils.h"

// --------------------------------------------------------------------------
// Constants
// --------------------------------------------------------------------------

static const char kChannelName[] =
    "com.elymsyr.dungeon_master_tool/screencast";
static const char kEventChannelName[] =
    "com.elymsyr.dungeon_master_tool/screencast/events";
static const char kRenderChannelName[] =
    "com.elymsyr.dungeon_master_tool/screencast_render";
static const wchar_t kPresentationWindowClass[] =
    L"FLUTTER_SCREENCAST_WINDOW";

bool ScreencastPlugin::window_class_registered_ = false;

// --------------------------------------------------------------------------
// Monitor enumeration helpers
// --------------------------------------------------------------------------

struct MonitorEnumData {
  std::vector<flutter::EncodableMap> displays;
};

static BOOL CALLBACK EnumMonitorProc(HMONITOR monitor, HDC /*hdc*/,
                                     LPRECT /*rect*/, LPARAM data) {
  MONITORINFOEXW info{};
  info.cbSize = sizeof(MONITORINFOEXW);
  if (!::GetMonitorInfoW(monitor, &info)) {
    return TRUE;  // skip this monitor, continue enumeration
  }

  // Skip the primary monitor (matches Android/iOS behavior).
  if (info.dwFlags & MONITORINFOF_PRIMARY) {
    return TRUE;
  }

  DEVMODEW devmode{};
  devmode.dmSize = sizeof(DEVMODEW);
  if (!::EnumDisplaySettingsW(info.szDevice, ENUM_CURRENT_SETTINGS, &devmode)) {
    return TRUE;
  }

  auto* enum_data = reinterpret_cast<MonitorEnumData*>(data);

  flutter::EncodableMap display;
  display[flutter::EncodableValue("id")] = flutter::EncodableValue(
      std::to_string(reinterpret_cast<intptr_t>(monitor)));
  display[flutter::EncodableValue("name")] =
      flutter::EncodableValue(Utf8FromUtf16(info.szDevice));
  display[flutter::EncodableValue("width")] =
      flutter::EncodableValue(static_cast<int>(devmode.dmPelsWidth));
  display[flutter::EncodableValue("height")] =
      flutter::EncodableValue(static_cast<int>(devmode.dmPelsHeight));

  enum_data->displays.push_back(std::move(display));
  return TRUE;
}

// Used by StartPresentation to find a specific HMONITOR by string ID.
struct MonitorFindData {
  std::string target_id;
  HMONITOR found = nullptr;
  RECT rect{};
};

static BOOL CALLBACK FindMonitorProc(HMONITOR monitor, HDC /*hdc*/,
                                     LPRECT /*rect*/, LPARAM data) {
  auto* find_data = reinterpret_cast<MonitorFindData*>(data);
  std::string id = std::to_string(reinterpret_cast<intptr_t>(monitor));
  if (id == find_data->target_id) {
    find_data->found = monitor;
    MONITORINFO mi{};
    mi.cbSize = sizeof(MONITORINFO);
    ::GetMonitorInfoW(monitor, &mi);
    find_data->rect = mi.rcMonitor;
    return FALSE;  // stop enumeration
  }
  return TRUE;
}

// Used by WM_DISPLAYCHANGE handler to check if a monitor still exists.
struct MonitorExistsData {
  HMONITOR target;
  bool exists = false;
};

static BOOL CALLBACK MonitorExistsProc(HMONITOR monitor, HDC /*hdc*/,
                                       LPRECT /*rect*/, LPARAM data) {
  auto* check = reinterpret_cast<MonitorExistsData*>(data);
  if (monitor == check->target) {
    check->exists = true;
    return FALSE;
  }
  return TRUE;
}

// --------------------------------------------------------------------------
// Registration
// --------------------------------------------------------------------------

void ScreencastPlugin::RegisterWithEngine(flutter::FlutterEngine* engine) {
  if (!engine) return;

  // The plugin instance is intentionally leaked — it lives for the lifetime
  // of the application, matching the Android/iOS pattern.
  auto* plugin = new ScreencastPlugin(engine);
  (void)plugin;
}

// --------------------------------------------------------------------------
// Constructor / Destructor
// --------------------------------------------------------------------------

ScreencastPlugin::ScreencastPlugin(flutter::FlutterEngine* engine) {
  auto* messenger = engine->messenger();

  // Method channel.
  method_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) { HandleMethodCall(call, std::move(result)); });

  // Event channel.
  event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          messenger, kEventChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          // OnListen
          [this](const flutter::EncodableValue* /*arguments*/,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     events)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = std::move(events);
            return nullptr;
          },
          // OnCancel
          [this](const flutter::EncodableValue* /*arguments*/)
              -> std::unique_ptr<
                  flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink_ = nullptr;
            return nullptr;
          });

  event_channel_->SetStreamHandler(std::move(handler));

  // Register for WM_DISPLAYCHANGE via the plugin registrar.
  auto registrar_ref =
      engine->GetRegistrarForPlugin("ScreencastPlugin");
  if (registrar_ref) {
    registrar_windows_ =
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar_ref);
    if (registrar_windows_) {
      window_proc_delegate_id_ =
          registrar_windows_->RegisterTopLevelWindowProcDelegate(
              [this](HWND hwnd, UINT message, WPARAM wparam,
                     LPARAM lparam) -> std::optional<LRESULT> {
                return HandleWindowProc(hwnd, message, wparam, lparam);
              });
    }
  }
}

ScreencastPlugin::~ScreencastPlugin() {
  StopPresentation();

  if (registrar_windows_ && window_proc_delegate_id_ != 0) {
    registrar_windows_->UnregisterTopLevelWindowProcDelegate(
        window_proc_delegate_id_);
  }
}

// --------------------------------------------------------------------------
// Method channel dispatch
// --------------------------------------------------------------------------

void ScreencastPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto& method = call.method_name();

  if (method == "getAvailableDisplays") {
    GetAvailableDisplays(std::move(result));
  } else if (method == "startPresentation") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) {
      result->Error("INVALID_ARG", "arguments must be a map");
      return;
    }
    auto it = args->find(flutter::EncodableValue("displayId"));
    if (it == args->end()) {
      result->Error("INVALID_ARG", "displayId required");
      return;
    }
    const auto* display_id = std::get_if<std::string>(&it->second);
    if (!display_id) {
      result->Error("INVALID_ARG", "displayId must be a string");
      return;
    }
    StartPresentation(*display_id, std::move(result));
  } else if (method == "stopPresentation") {
    StopPresentation();
    result->Success();
  } else if (method == "pushState") {
    PushState(call.arguments());
    result->Success(flutter::EncodableValue(true));
  } else if (method == "pushBattleMapPatch") {
    PushBattleMapPatch(call.arguments());
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

// --------------------------------------------------------------------------
// getAvailableDisplays
// --------------------------------------------------------------------------

void ScreencastPlugin::GetAvailableDisplays(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  MonitorEnumData data;
  ::EnumDisplayMonitors(nullptr, nullptr, EnumMonitorProc,
                        reinterpret_cast<LPARAM>(&data));

  flutter::EncodableList list;
  list.reserve(data.displays.size());
  for (auto& d : data.displays) {
    list.push_back(flutter::EncodableValue(std::move(d)));
  }
  result->Success(flutter::EncodableValue(std::move(list)));
}

// --------------------------------------------------------------------------
// startPresentation
// --------------------------------------------------------------------------

void ScreencastPlugin::StartPresentation(
    const std::string& display_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  StopPresentation();

  // Find the target monitor.
  MonitorFindData find_data;
  find_data.target_id = display_id;
  ::EnumDisplayMonitors(nullptr, nullptr, FindMonitorProc,
                        reinterpret_cast<LPARAM>(&find_data));

  if (!find_data.found) {
    result->Error("DISPLAY_NOT_FOUND",
                  "Display " + display_id + " not found");
    return;
  }

  target_monitor_ = find_data.found;
  int width = find_data.rect.right - find_data.rect.left;
  int height = find_data.rect.bottom - find_data.rect.top;

  // Register the window class once.
  if (!window_class_registered_) {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = PresentationWndProc;
    wc.hInstance = ::GetModuleHandleW(nullptr);
    wc.hCursor = ::LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground =
        reinterpret_cast<HBRUSH>(static_cast<intptr_t>(COLOR_WINDOW + 1));
    wc.lpszClassName = kPresentationWindowClass;

    if (::RegisterClassExW(&wc)) {
      window_class_registered_ = true;
    } else {
      result->Error("WINDOW_CLASS_FAILED",
                    "Failed to register presentation window class");
      return;
    }
  }

  // Create a borderless popup covering the target monitor.
  presentation_hwnd_ = ::CreateWindowExW(
      WS_EX_NOACTIVATE,         // don't steal focus
      kPresentationWindowClass,  // class
      L"Player View",            // title (not visible)
      WS_POPUP,                  // borderless
      find_data.rect.left, find_data.rect.top, width, height,
      nullptr,                              // no parent
      nullptr,                              // no menu
      ::GetModuleHandleW(nullptr), nullptr);

  if (!presentation_hwnd_) {
    result->Error("WINDOW_FAILED", "Failed to create presentation window");
    return;
  }

  // Paint the window black immediately so there's no white flash.
  {
    HDC hdc = ::GetDC(presentation_hwnd_);
    if (hdc) {
      RECT rc{0, 0, width, height};
      ::FillRect(hdc, &rc,
                 reinterpret_cast<HBRUSH>(::GetStockObject(BLACK_BRUSH)));
      ::ReleaseDC(presentation_hwnd_, hdc);
    }
  }

  // Create a DartProject for the presentation engine.
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint("screencastMain");

  // Create the FlutterViewController (this also creates and starts the engine).
  presentation_controller_ =
      std::make_unique<flutter::FlutterViewController>(width, height, project);

  if (!presentation_controller_->engine() ||
      !presentation_controller_->view()) {
    presentation_controller_.reset();
    ::DestroyWindow(presentation_hwnd_);
    presentation_hwnd_ = nullptr;
    target_monitor_ = nullptr;
    result->Error("ENGINE_FAILED",
                  "Failed to create presentation Flutter engine");
    return;
  }

  // Parent the Flutter view into the presentation window.
  HWND flutter_hwnd =
      presentation_controller_->view()->GetNativeWindow();
  ::SetParent(flutter_hwnd, presentation_hwnd_);
  ::MoveWindow(flutter_hwnd, 0, 0, width, height, TRUE);
  ::ShowWindow(flutter_hwnd, SW_SHOW);

  // Set up the render channel on the presentation engine.
  render_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          presentation_controller_->engine()->messenger(), kRenderChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  render_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 res) {
        if (call.method_name() == "engineReady") {
          presentation_ready_ = true;
          if (pending_full_state_) {
            auto buffered = std::move(pending_full_state_);
            render_channel_->InvokeMethod("applyState", std::move(buffered));
          }
          res->Success();
        } else {
          res->NotImplemented();
        }
      });

  // Show the presentation window without stealing focus.
  ::ShowWindow(presentation_hwnd_, SW_SHOWNOACTIVATE);
  ::UpdateWindow(presentation_hwnd_);

  result->Success(flutter::EncodableValue(true));
}

// --------------------------------------------------------------------------
// stopPresentation
// --------------------------------------------------------------------------

void ScreencastPlugin::StopPresentation() {
  if (render_channel_) {
    render_channel_->SetMethodCallHandler(nullptr);
    render_channel_.reset();
  }

  presentation_ready_ = false;
  pending_full_state_.reset();

  // Destroy the controller before the window so the Flutter engine shuts
  // down cleanly while its host window still exists.
  presentation_controller_.reset();

  if (presentation_hwnd_) {
    ::DestroyWindow(presentation_hwnd_);
    presentation_hwnd_ = nullptr;
  }

  target_monitor_ = nullptr;
}

// --------------------------------------------------------------------------
// pushState
// --------------------------------------------------------------------------

void ScreencastPlugin::PushState(const flutter::EncodableValue* state) {
  if (!render_channel_) return;

  if (!presentation_ready_) {
    // Buffer full-state pushes; drop patches (they're already incorporated
    // in the next full state).
    if (state) {
      const auto* map = std::get_if<flutter::EncodableMap>(state);
      if (map) {
        auto it = map->find(flutter::EncodableValue("type"));
        bool is_patch = (it != map->end()) &&
                        (std::get_if<std::string>(&it->second) != nullptr) &&
                        (std::get<std::string>(it->second) == "patch");
        if (!is_patch) {
          pending_full_state_ =
              std::make_unique<flutter::EncodableValue>(*state);
        }
      }
    }
    return;
  }

  if (state) {
    render_channel_->InvokeMethod(
        "applyState",
        std::make_unique<flutter::EncodableValue>(*state));
  }
}

// --------------------------------------------------------------------------
// pushBattleMapPatch
// --------------------------------------------------------------------------

void ScreencastPlugin::PushBattleMapPatch(
    const flutter::EncodableValue* args) {
  if (!render_channel_ || !presentation_ready_) return;

  if (args) {
    render_channel_->InvokeMethod(
        "applyBattleMapPatch",
        std::make_unique<flutter::EncodableValue>(*args));
  }
}

// --------------------------------------------------------------------------
// WM_DISPLAYCHANGE handler
// --------------------------------------------------------------------------

std::optional<LRESULT> ScreencastPlugin::HandleWindowProc(
    HWND /*hwnd*/, UINT message, WPARAM /*wparam*/, LPARAM /*lparam*/) {
  if (message != WM_DISPLAYCHANGE) return std::nullopt;

  // Only care if we have an active presentation.
  if (!target_monitor_ || !presentation_hwnd_) return std::nullopt;

  // Check whether the target monitor still exists.
  MonitorExistsData check;
  check.target = target_monitor_;
  ::EnumDisplayMonitors(nullptr, nullptr, MonitorExistsProc,
                        reinterpret_cast<LPARAM>(&check));

  if (!check.exists) {
    StopPresentation();
    if (event_sink_) {
      flutter::EncodableMap event;
      event[flutter::EncodableValue("event")] =
          flutter::EncodableValue("displayDisconnected");
      event_sink_->Success(flutter::EncodableValue(std::move(event)));
    }
  }

  // Don't consume the message — other plugins may need it too.
  return std::nullopt;
}

// --------------------------------------------------------------------------
// Presentation window WndProc
// --------------------------------------------------------------------------

LRESULT CALLBACK ScreencastPlugin::PresentationWndProc(HWND hwnd, UINT message,
                                                       WPARAM wparam,
                                                       LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND: {
      // Paint black to avoid white flashes during resize / before Flutter
      // renders its first frame.
      HDC hdc = reinterpret_cast<HDC>(wparam);
      RECT rc;
      ::GetClientRect(hwnd, &rc);
      ::FillRect(hdc, &rc,
                 reinterpret_cast<HBRUSH>(::GetStockObject(BLACK_BRUSH)));
      return 1;
    }
    default:
      break;
  }
  return ::DefWindowProcW(hwnd, message, wparam, lparam);
}
