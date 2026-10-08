#include "platform.h"

#include <gio/gio.h>

struct PlatformState {
  GtkWindow* window;
  GApplication* application;
  gboolean quitting;
  guint32 last_notification;
};

static PlatformState* state = nullptr;

static void show_window() {
  gtk_widget_show(GTK_WIDGET(state->window));
  gtk_window_present(GTK_WINDOW(state->window));
}

static void hide_window() { gtk_widget_hide(GTK_WIDGET(state->window)); }

static gboolean on_delete(GtkWidget*, GdkEvent*, gpointer) {
  if (state->quitting) return FALSE;
  hide_window();
  return TRUE;
}

static void on_notified(GObject* source, GAsyncResult* result, gpointer) {
  g_autoptr(GError) error = nullptr;
  GVariant* reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(source),
                                                  result, &error);
  if (reply == nullptr) return;
  guint32 id = 0;
  g_variant_get(reply, "(u)", &id);
  if (state != nullptr) state->last_notification = id;
  g_variant_unref(reply);
}

static void notify(const gchar* title, const gchar* body) {
  g_autoptr(GError) error = nullptr;
  GDBusConnection* bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus == nullptr) return;
  GVariantBuilder actions;
  g_variant_builder_init(&actions, G_VARIANT_TYPE("as"));
  GVariantBuilder hints;
  g_variant_builder_init(&hints, G_VARIANT_TYPE("a{sv}"));
  g_dbus_connection_call(
      bus, "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
      "org.freedesktop.Notifications", "Notify",
      g_variant_new("(susssasa{sv}i)", "Pray", state->last_notification,
                    "ir.psdkjoon.pray", title, body, &actions, &hints, 5000),
      G_VARIANT_TYPE("(u)"), G_DBUS_CALL_FLAGS_NONE, 2000, nullptr,
      on_notified, nullptr);
  g_object_unref(bus);
}

static void window_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* name = fl_method_call_get_name(call);
  if (g_strcmp0(name, "show") == 0) {
    show_window();
  } else if (g_strcmp0(name, "hide") == 0) {
    hide_window();
  } else if (g_strcmp0(name, "toggle") == 0) {
    if (gtk_widget_get_visible(GTK_WIDGET(state->window)) &&
        gtk_window_is_active(state->window)) {
      hide_window();
    } else {
      show_window();
    }
  } else if (g_strcmp0(name, "quit") == 0) {
    state->quitting = TRUE;
    g_application_quit(state->application);
  } else if (g_strcmp0(name, "notify") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    FlValue* title = fl_value_lookup_string(args, "title");
    FlValue* body = fl_value_lookup_string(args, "body");
    if (title != nullptr && body != nullptr) {
      notify(fl_value_get_string(title), fl_value_get_string(body));
    }
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  fl_method_call_respond(call, response, nullptr);
}

void platform_register(FlBinaryMessenger* messenger, GtkWindow* window,
                       GApplication* application) {
  if (state != nullptr) return;
  state = new PlatformState();
  state->window = window;
  state->application = application;
  state->quitting = FALSE;
  state->last_notification = 0;
  g_signal_connect(window, "delete-event", G_CALLBACK(on_delete), nullptr);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      messenger, "pray/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, window_call_cb, nullptr,
                                            nullptr);
}
