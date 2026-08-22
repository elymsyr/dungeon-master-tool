//
// Created by yangbin on 2022/1/11.
//

#include "flutter_window.h"

#include <iostream>

#include "include/desktop_multi_window/desktop_multi_window_plugin.h"
#include "desktop_multi_window_plugin_internal.h"

namespace {

WindowCreatedCallback _g_window_created_callback = nullptr;

}

gboolean on_close_clicked(GtkWidget *widget, GdkEvent *event, gpointer user_data) {
    // Hide instead of destroy. Destroying a `fl_view_new` sub-window routes
    // through FlutterEngineRemoveView on the implicit view, which the current
    // engine rejects (kInvalidArguments) and then segfaults on during the GL
    // teardown of FlutterEngineShutdown. Hiding keeps the window + engine alive
    // so the DM can show() it again on the next projection.
    gtk_widget_hide(widget);
    return TRUE;
}

FlutterWindow::FlutterWindow(
    int64_t id,
    const std::string &args,
    const std::shared_ptr<FlutterWindowCallback> &callback
) : callback_(callback), id_(id) {
  window_ = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  gtk_window_set_default_size(GTK_WINDOW(window_), 1280, 720);
  gtk_window_set_title(GTK_WINDOW(window_), "");
  gtk_window_set_position(GTK_WINDOW(window_), GTK_WIN_POS_CENTER);
  gtk_widget_show(GTK_WIDGET(window_));

  g_signal_connect(G_OBJECT(window_), "delete-event", G_CALLBACK(on_close_clicked), NULL);
  g_signal_connect(window_, "destroy", G_CALLBACK(+[](GtkWidget *, gpointer arg) {
    auto *self = static_cast<FlutterWindow *>(arg);
    if (auto callback = self->callback_.lock()) {
      callback->OnWindowClose(self->id_);
      callback->OnWindowDestroy(self->id_);
    }
  }), this);

  g_autoptr(FlDartProject)
      project = fl_dart_project_new();
  const char *entrypoint_args[] = {"multi_window", g_strdup_printf("%ld", id_), args.c_str(), nullptr};
  fl_dart_project_set_dart_entrypoint_arguments(project, const_cast<char **>(entrypoint_args));

  auto fl_view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(fl_view));
  gtk_container_add(GTK_CONTAINER(window_), GTK_WIDGET(fl_view));

  // The Flutter engine shell connects its own "delete-event" handler on the
  // toplevel window (flutter/engine PR #40033) which calls
  // fl_engine_request_app_exit -> g_application_quit whenever a window is
  // closed. For a sub-window that must hide without quitting the whole app,
  // disconnect it. Our own on_close_clicked handler above already hides just
  // this window. The window_ is realized by the gtk_container_add above, so
  // the engine handler is already connected here.
  guint handler_id = g_signal_handler_find(window_, G_SIGNAL_MATCH_DATA, 0, 0,
                                           NULL, NULL, fl_view);
  if (handler_id > 0) {
    g_signal_handler_disconnect(window_, handler_id);
  }

  if (_g_window_created_callback) {
    _g_window_created_callback(FL_PLUGIN_REGISTRY(fl_view));
  }
  g_autoptr(FlPluginRegistrar)
      desktop_multi_window_registrar =
      fl_plugin_registry_get_registrar_for_plugin(FL_PLUGIN_REGISTRY(fl_view), "DesktopMultiWindowPlugin");
  desktop_multi_window_plugin_register_with_registrar_internal(desktop_multi_window_registrar);

  window_channel_ = WindowChannel::RegisterWithRegistrar(desktop_multi_window_registrar, id_);

  gtk_widget_grab_focus(GTK_WIDGET(fl_view));
  gtk_widget_hide(GTK_WIDGET(window_));
}

WindowChannel *FlutterWindow::GetWindowChannel() {
  return window_channel_.get();
}

FlutterWindow::~FlutterWindow() = default;

void desktop_multi_window_plugin_set_window_created_callback(WindowCreatedCallback callback) {
  _g_window_created_callback = callback;
}