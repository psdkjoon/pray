#include "tray.h"

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

#include <string.h>
#include <unistd.h>

static const char* kItemXml =
    "<node>"
    "  <interface name='org.kde.StatusNotifierItem'>"
    "    <method name='ContextMenu'>"
    "      <arg type='i' name='x' direction='in'/>"
    "      <arg type='i' name='y' direction='in'/>"
    "    </method>"
    "    <method name='Activate'>"
    "      <arg type='i' name='x' direction='in'/>"
    "      <arg type='i' name='y' direction='in'/>"
    "    </method>"
    "    <method name='SecondaryActivate'>"
    "      <arg type='i' name='x' direction='in'/>"
    "      <arg type='i' name='y' direction='in'/>"
    "    </method>"
    "    <method name='Scroll'>"
    "      <arg type='i' name='delta' direction='in'/>"
    "      <arg type='s' name='orientation' direction='in'/>"
    "    </method>"
    "    <property name='Category' type='s' access='read'/>"
    "    <property name='Id' type='s' access='read'/>"
    "    <property name='Title' type='s' access='read'/>"
    "    <property name='Status' type='s' access='read'/>"
    "    <property name='WindowId' type='u' access='read'/>"
    "    <property name='IconName' type='s' access='read'/>"
    "    <property name='IconPixmap' type='a(iiay)' access='read'/>"
    "    <property name='ItemIsMenu' type='b' access='read'/>"
    "    <property name='Menu' type='o' access='read'/>"
    "    <signal name='NewIcon'/>"
    "    <signal name='NewStatus'>"
    "      <arg type='s' name='status'/>"
    "    </signal>"
    "  </interface>"
    "</node>";

static const char* kMenuXml =
    "<node>"
    "  <interface name='com.canonical.dbusmenu'>"
    "    <method name='GetLayout'>"
    "      <arg type='i' name='parentId' direction='in'/>"
    "      <arg type='i' name='recursionDepth' direction='in'/>"
    "      <arg type='as' name='propertyNames' direction='in'/>"
    "      <arg type='u' name='revision' direction='out'/>"
    "      <arg type='(ia{sv}av)' name='layout' direction='out'/>"
    "    </method>"
    "    <method name='GetGroupProperties'>"
    "      <arg type='ai' name='ids' direction='in'/>"
    "      <arg type='as' name='propertyNames' direction='in'/>"
    "      <arg type='a(ia{sv})' name='properties' direction='out'/>"
    "    </method>"
    "    <method name='GetProperty'>"
    "      <arg type='i' name='id' direction='in'/>"
    "      <arg type='s' name='name' direction='in'/>"
    "      <arg type='v' name='value' direction='out'/>"
    "    </method>"
    "    <method name='Event'>"
    "      <arg type='i' name='id' direction='in'/>"
    "      <arg type='s' name='eventId' direction='in'/>"
    "      <arg type='v' name='data' direction='in'/>"
    "      <arg type='u' name='timestamp' direction='in'/>"
    "    </method>"
    "    <method name='EventGroup'>"
    "      <arg type='a(isvu)' name='events' direction='in'/>"
    "      <arg type='ai' name='idsNotFound' direction='out'/>"
    "    </method>"
    "    <method name='AboutToShow'>"
    "      <arg type='i' name='id' direction='in'/>"
    "      <arg type='b' name='needUpdate' direction='out'/>"
    "    </method>"
    "    <method name='AboutToShowGroup'>"
    "      <arg type='ai' name='ids' direction='in'/>"
    "      <arg type='ai' name='updatesNeeded' direction='out'/>"
    "      <arg type='ai' name='idsNotFound' direction='out'/>"
    "    </method>"
    "    <signal name='ItemsPropertiesUpdated'>"
    "      <arg type='a(ia{sv})' name='updatedProps'/>"
    "      <arg type='a(ias)' name='removedProps'/>"
    "    </signal>"
    "    <signal name='LayoutUpdated'>"
    "      <arg type='u' name='revision'/>"
    "      <arg type='i' name='parent'/>"
    "    </signal>"
    "    <signal name='ItemActivationRequested'>"
    "      <arg type='i' name='id'/>"
    "      <arg type='u' name='timestamp'/>"
    "    </signal>"
    "    <property name='Version' type='u' access='read'/>"
    "    <property name='TextDirection' type='s' access='read'/>"
    "    <property name='Status' type='s' access='read'/>"
    "    <property name='IconThemePath' type='as' access='read'/>"
    "  </interface>"
    "</node>";

static const char* kMenuPath = "/MenuBar";

struct TrayState {
  FlMethodChannel* channel = nullptr;
  GDBusConnection* connection = nullptr;
  GDBusNodeInfo* node_info = nullptr;
  GDBusNodeInfo* menu_info = nullptr;
  guint owner_id = 0;
  guint registration_id = 0;
  guint menu_registration_id = 0;
  guint32 menu_revision = 1;
  gchar* title = nullptr;
  GVariant* pixmaps = nullptr;
  GPtrArray* menu_entries = nullptr;
};

static TrayState* state = nullptr;

static void notify_dart(const char* method, FlValue* args) {
  if (state == nullptr || state->channel == nullptr) return;
  fl_method_channel_invoke_method(state->channel, method, args, nullptr,
                                  nullptr, nullptr);
}

static GVariant* build_pixmaps(const gchar* path) {
  GVariantBuilder array;
  g_variant_builder_init(&array, G_VARIANT_TYPE("a(iiay)"));
  const int sizes[] = {24, 48, 64};
  for (int size : sizes) {
    GdkPixbuf* pixbuf =
        gdk_pixbuf_new_from_file_at_size(path, size, size, nullptr);
    if (pixbuf == nullptr) continue;
    GdkPixbuf* rgba = gdk_pixbuf_get_has_alpha(pixbuf)
                          ? g_object_ref(pixbuf)
                          : gdk_pixbuf_add_alpha(pixbuf, FALSE, 0, 0, 0);
    const int width = gdk_pixbuf_get_width(rgba);
    const int height = gdk_pixbuf_get_height(rgba);
    const int stride = gdk_pixbuf_get_rowstride(rgba);
    const guchar* pixels = gdk_pixbuf_read_pixels(rgba);
    GByteArray* argb = g_byte_array_sized_new(width * height * 4);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        const guchar* p = pixels + y * stride + x * 4;
        const guchar out[4] = {p[3], p[0], p[1], p[2]};
        g_byte_array_append(argb, out, 4);
      }
    }
    GVariant* bytes = g_variant_new_fixed_array(G_VARIANT_TYPE_BYTE, argb->data,
                                                argb->len, 1);
    g_variant_builder_add(&array, "(ii@ay)", width, height, bytes);
    g_byte_array_free(argb, TRUE);
    g_object_unref(rgba);
    g_object_unref(pixbuf);
  }
  return g_variant_ref_sink(g_variant_builder_end(&array));
}

static GVariant* get_property(GDBusConnection*, const gchar*, const gchar*,
                              const gchar*, const gchar* property, GError**,
                              gpointer) {
  if (g_strcmp0(property, "Category") == 0)
    return g_variant_new_string("ApplicationStatus");
  if (g_strcmp0(property, "Id") == 0) return g_variant_new_string("pray");
  if (g_strcmp0(property, "Title") == 0)
    return g_variant_new_string(state->title != nullptr ? state->title : "");
  if (g_strcmp0(property, "Status") == 0) return g_variant_new_string("Active");
  if (g_strcmp0(property, "WindowId") == 0) return g_variant_new_uint32(0);
  if (g_strcmp0(property, "IconName") == 0) return g_variant_new_string("");
  if (g_strcmp0(property, "IconPixmap") == 0) {
    if (state->pixmaps != nullptr) return g_variant_ref(state->pixmaps);
    return g_variant_new_array(G_VARIANT_TYPE("(iiay)"), nullptr, 0);
  }
  if (g_strcmp0(property, "ItemIsMenu") == 0) return g_variant_new_boolean(FALSE);
  if (g_strcmp0(property, "Menu") == 0)
    return g_variant_new_object_path(kMenuPath);
  return nullptr;
}

static FlValue* entry_at(gint id) {
  if (state->menu_entries == nullptr || id < 1 ||
      static_cast<guint>(id) > state->menu_entries->len)
    return nullptr;
  return static_cast<FlValue*>(g_ptr_array_index(state->menu_entries, id - 1));
}

static GVariant* item_props(gint id) {
  GVariantBuilder props;
  g_variant_builder_init(&props, G_VARIANT_TYPE("a{sv}"));
  if (id == 0) {
    g_variant_builder_add(&props, "{sv}", "children-display",
                          g_variant_new_string("submenu"));
  } else if (FlValue* entry = entry_at(id)) {
    FlValue* separator = fl_value_lookup_string(entry, "separator");
    if (separator != nullptr && fl_value_get_bool(separator)) {
      g_variant_builder_add(&props, "{sv}", "type",
                            g_variant_new_string("separator"));
    } else {
      FlValue* label = fl_value_lookup_string(entry, "label");
      FlValue* enabled = fl_value_lookup_string(entry, "enabled");
      g_variant_builder_add(
          &props, "{sv}", "label",
          g_variant_new_string(label != nullptr ? fl_value_get_string(label)
                                                : ""));
      g_variant_builder_add(
          &props, "{sv}", "enabled",
          g_variant_new_boolean(enabled == nullptr ||
                                fl_value_get_bool(enabled)));
    }
  }
  return g_variant_builder_end(&props);
}

static GVariant* build_node(gint id) {
  GVariantBuilder children;
  g_variant_builder_init(&children, G_VARIANT_TYPE("av"));
  if (id == 0 && state->menu_entries != nullptr) {
    for (guint i = 0; i < state->menu_entries->len; i++) {
      g_variant_builder_add(&children, "v", build_node(i + 1));
    }
  }
  return g_variant_new("(i@a{sv}@av)", id, item_props(id),
                       g_variant_builder_end(&children));
}

static void menu_event(gint id, const gchar* event_id) {
  if (g_strcmp0(event_id, "clicked") != 0) return;
  FlValue* entry = entry_at(id);
  if (entry == nullptr) return;
  FlValue* key = fl_value_lookup_string(entry, "key");
  if (key == nullptr) return;
  g_autoptr(FlValue) args = fl_value_new_string(fl_value_get_string(key));
  notify_dart("menuClick", args);
}

static void handle_menu_call(GDBusConnection*, const gchar*, const gchar*,
                             const gchar*, const gchar* method_name,
                             GVariant* parameters,
                             GDBusMethodInvocation* invocation, gpointer) {
  if (g_strcmp0(method_name, "GetLayout") == 0) {
    gint parent = 0;
    g_variant_get(parameters, "(ii@as)", &parent, nullptr, nullptr);
    g_dbus_method_invocation_return_value(
        invocation,
        g_variant_new("(u@(ia{sv}av))", state->menu_revision,
                      build_node(parent == 0 || entry_at(parent) != nullptr
                                     ? parent
                                     : 0)));
  } else if (g_strcmp0(method_name, "GetGroupProperties") == 0) {
    GVariantIter* ids = nullptr;
    g_variant_get(parameters, "(aias)", &ids, nullptr);
    GVariantBuilder out;
    g_variant_builder_init(&out, G_VARIANT_TYPE("a(ia{sv})"));
    gint id;
    gboolean any = FALSE;
    while (g_variant_iter_next(ids, "i", &id)) {
      any = TRUE;
      g_variant_builder_add(&out, "(i@a{sv})", id, item_props(id));
    }
    g_variant_iter_free(ids);
    if (!any) {
      const guint count =
          state->menu_entries != nullptr ? state->menu_entries->len : 0;
      for (guint i = 0; i <= count; i++) {
        g_variant_builder_add(&out, "(i@a{sv})", static_cast<gint>(i),
                              item_props(static_cast<gint>(i)));
      }
    }
    g_dbus_method_invocation_return_value(invocation,
                                          g_variant_new("(a(ia{sv}))", &out));
  } else if (g_strcmp0(method_name, "GetProperty") == 0) {
    gint id = 0;
    const gchar* name = nullptr;
    g_variant_get(parameters, "(i&s)", &id, &name);
    g_autoptr(GVariant) props = g_variant_ref_sink(item_props(id));
    GVariant* value = g_variant_lookup_value(props, name, nullptr);
    if (value == nullptr) {
      g_dbus_method_invocation_return_dbus_error(
          invocation, "org.freedesktop.DBus.Error.InvalidArgs",
          "Unknown property");
    } else {
      g_dbus_method_invocation_return_value(invocation,
                                            g_variant_new("(v)", value));
      g_variant_unref(value);
    }
  } else if (g_strcmp0(method_name, "Event") == 0) {
    gint id = 0;
    const gchar* event_id = nullptr;
    GVariant* data = nullptr;
    guint32 timestamp = 0;
    g_variant_get(parameters, "(i&svu)", &id, &event_id, &data, &timestamp);
    menu_event(id, event_id);
    g_variant_unref(data);
    g_dbus_method_invocation_return_value(invocation, nullptr);
  } else if (g_strcmp0(method_name, "EventGroup") == 0) {
    GVariantIter* events = nullptr;
    g_variant_get(parameters, "(a(isvu))", &events);
    gint id;
    const gchar* event_id;
    GVariant* data;
    guint32 timestamp;
    while (g_variant_iter_next(events, "(i&svu)", &id, &event_id, &data,
                               &timestamp)) {
      menu_event(id, event_id);
      g_variant_unref(data);
    }
    g_variant_iter_free(events);
    g_dbus_method_invocation_return_value(invocation,
                                          g_variant_new("(ai)", nullptr));
  } else if (g_strcmp0(method_name, "AboutToShow") == 0) {
    g_dbus_method_invocation_return_value(invocation,
                                          g_variant_new("(b)", FALSE));
  } else if (g_strcmp0(method_name, "AboutToShowGroup") == 0) {
    g_dbus_method_invocation_return_value(
        invocation, g_variant_new("(aiai)", nullptr, nullptr));
  } else {
    g_dbus_method_invocation_return_dbus_error(
        invocation, "org.freedesktop.DBus.Error.UnknownMethod",
        "Unknown method");
  }
}

static GVariant* get_menu_property(GDBusConnection*, const gchar*,
                                   const gchar*, const gchar*,
                                   const gchar* property, GError**, gpointer) {
  if (g_strcmp0(property, "Version") == 0) return g_variant_new_uint32(3);
  if (g_strcmp0(property, "TextDirection") == 0)
    return g_variant_new_string("ltr");
  if (g_strcmp0(property, "Status") == 0) return g_variant_new_string("normal");
  if (g_strcmp0(property, "IconThemePath") == 0)
    return g_variant_new_array(G_VARIANT_TYPE_STRING, nullptr, 0);
  return nullptr;
}

static const GDBusInterfaceVTable kMenuVTable = {handle_menu_call,
                                                 get_menu_property, nullptr};

static void handle_method_call(GDBusConnection*, const gchar*, const gchar*,
                               const gchar*, const gchar* method_name,
                               GVariant*, GDBusMethodInvocation* invocation,
                               gpointer) {
  if (g_strcmp0(method_name, "Activate") == 0) {
    notify_dart("activate", nullptr);
  } else if (g_strcmp0(method_name, "SecondaryActivate") == 0) {
    notify_dart("activate", nullptr);
  }
  g_dbus_method_invocation_return_value(invocation, nullptr);
}

static const GDBusInterfaceVTable kVTable = {handle_method_call, get_property,
                                             nullptr};

static void on_watcher_registered(GObject* source, GAsyncResult* result,
                                  gpointer) {
  g_autoptr(GError) error = nullptr;
  GVariant* reply = g_dbus_connection_call_finish(G_DBUS_CONNECTION(source),
                                                  result, &error);
  if (reply != nullptr) g_variant_unref(reply);
}

static void on_bus_acquired(GDBusConnection* connection, const gchar*,
                            gpointer) {
  state->connection = connection;
  state->registration_id = g_dbus_connection_register_object(
      connection, "/StatusNotifierItem", state->node_info->interfaces[0],
      &kVTable, nullptr, nullptr, nullptr);
  state->menu_registration_id = g_dbus_connection_register_object(
      connection, kMenuPath, state->menu_info->interfaces[0], &kMenuVTable,
      nullptr, nullptr, nullptr);
}

static void on_name_acquired(GDBusConnection* connection, const gchar* name,
                             gpointer) {
  g_dbus_connection_call(connection, "org.kde.StatusNotifierWatcher",
                         "/StatusNotifierWatcher",
                         "org.kde.StatusNotifierWatcher",
                         "RegisterStatusNotifierItem",
                         g_variant_new("(s)", name), nullptr,
                         G_DBUS_CALL_FLAGS_NONE, -1, nullptr,
                         on_watcher_registered, nullptr);
}

static void create_tray(const gchar* icon_path, const gchar* title) {
  if (state->owner_id != 0) return;
  g_free(state->title);
  state->title = g_strdup(title);
  if (state->pixmaps != nullptr) g_variant_unref(state->pixmaps);
  state->pixmaps = build_pixmaps(icon_path);
  state->node_info = g_dbus_node_info_new_for_xml(kItemXml, nullptr);
  state->menu_info = g_dbus_node_info_new_for_xml(kMenuXml, nullptr);
  g_autofree gchar* bus_name =
      g_strdup_printf("org.kde.StatusNotifierItem-%d-1", getpid());
  state->owner_id = g_bus_own_name(G_BUS_TYPE_SESSION, bus_name,
                                   G_BUS_NAME_OWNER_FLAGS_NONE, on_bus_acquired,
                                   on_name_acquired, nullptr, nullptr, nullptr);
}

static void set_menu(FlValue* list) {
  if (state->menu_entries != nullptr) g_ptr_array_unref(state->menu_entries);
  state->menu_entries =
      g_ptr_array_new_with_free_func(reinterpret_cast<GDestroyNotify>(fl_value_unref));
  if (list != nullptr && fl_value_get_type(list) == FL_VALUE_TYPE_LIST) {
    for (size_t i = 0; i < fl_value_get_length(list); i++) {
      g_ptr_array_add(state->menu_entries,
                      fl_value_ref(fl_value_get_list_value(list, i)));
    }
  }
  state->menu_revision++;
  if (state->connection != nullptr && state->menu_registration_id != 0) {
    g_dbus_connection_emit_signal(
        state->connection, nullptr, kMenuPath, "com.canonical.dbusmenu",
        "LayoutUpdated", g_variant_new("(ui)", state->menu_revision, 0),
        nullptr);
  }
}

static void set_icon(const gchar* icon_path) {
  if (state->pixmaps != nullptr) g_variant_unref(state->pixmaps);
  state->pixmaps = build_pixmaps(icon_path);
  if (state->connection != nullptr && state->registration_id != 0) {
    g_dbus_connection_emit_signal(state->connection, nullptr,
                                  "/StatusNotifierItem",
                                  "org.kde.StatusNotifierItem", "NewIcon",
                                  nullptr, nullptr);
  }
}

static void method_call_cb(FlMethodChannel*, FlMethodCall* call, gpointer) {
  const gchar* name = fl_method_call_get_name(call);
  FlValue* args = fl_method_call_get_args(call);
  if (g_strcmp0(name, "create") == 0) {
    FlValue* icon = fl_value_lookup_string(args, "icon");
    FlValue* title = fl_value_lookup_string(args, "title");
    if (icon != nullptr && title != nullptr) {
      create_tray(fl_value_get_string(icon), fl_value_get_string(title));
    }
  } else if (g_strcmp0(name, "setMenu") == 0) {
    set_menu(args);
  } else if (g_strcmp0(name, "setIcon") == 0) {
    FlValue* icon = fl_value_lookup_string(args, "icon");
    if (icon != nullptr) set_icon(fl_value_get_string(icon));
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  fl_method_call_respond(call, response, nullptr);
}

void tray_register(FlBinaryMessenger* messenger) {
  if (state != nullptr) return;
  state = new TrayState();
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  state->channel = fl_method_channel_new(messenger, "pray/tray",
                                         FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(state->channel, method_call_cb,
                                            nullptr, nullptr);
}
