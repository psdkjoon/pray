#include "pray_platform.h"

#include <commdlg.h>
#include <shellapi.h>

#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <map>
#include <optional>
#include <utility>

#include "utils.h"

namespace {

constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT_PTR kTrayRetryTimer = 1;
constexpr UINT_PTR kQuitTimer = 2;
constexpr int kMaxTrayRetries = 30;

constexpr wchar_t kShowWindowMessageName[] = L"PrayShowWindow";
constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kStartupApprovedKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\"
    L"Run";
constexpr wchar_t kAutostartValue[] = L"Pray";

constexpr int kMinWidth = 380;
constexpr int kMinHeight = 520;

using EncodableMap = flutter::EncodableMap;
using EncodableList = flutter::EncodableList;
using EncodableValue = flutter::EncodableValue;

std::wstring WideFromUtf8(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = ::MultiByteToWideChar(
      CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.data(), static_cast<int>(utf8.size()),
                        &wide[0], length);
  return wide;
}

// Copies |source| into a fixed-size buffer, always null-terminated.
template <size_t N>
void CopyToBuffer(wchar_t (&destination)[N], const std::wstring& source) {
  size_t count = source.size() < N - 1 ? source.size() : N - 1;
  for (size_t i = 0; i < count; i++) {
    destination[i] = source[i];
  }
  destination[count] = L'\0';
}

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(std::string(key)));
  return it == map.end() ? nullptr : &it->second;
}

const EncodableMap* AsMap(const EncodableValue* value) {
  return value == nullptr ? nullptr : std::get_if<EncodableMap>(value);
}

std::optional<std::string> AsString(const EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* text = std::get_if<std::string>(value)) {
    return *text;
  }
  return std::nullopt;
}

std::optional<int64_t> AsInt(const EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (const auto* narrow = std::get_if<int32_t>(value)) {
    return static_cast<int64_t>(*narrow);
  }
  if (const auto* wide_int = std::get_if<int64_t>(value)) {
    return *wide_int;
  }
  return std::nullopt;
}

bool AsBool(const EncodableValue* value, bool fallback) {
  if (value != nullptr) {
    if (const auto* flag = std::get_if<bool>(value)) {
      return *flag;
    }
  }
  return fallback;
}

std::wstring ModulePath() {
  std::wstring path(32768, L'\0');
  const DWORD length = ::GetModuleFileNameW(
      nullptr, &path[0], static_cast<DWORD>(path.size()));
  path.resize(length);
  return path;
}

bool StartsWithIgnoreCase(const std::string& text, const char* prefix) {
  for (size_t i = 0; prefix[i] != '\0'; i++) {
    if (i >= text.size()) {
      return false;
    }
    char a = text[i];
    char b = prefix[i];
    if (a >= 'A' && a <= 'Z') a = static_cast<char>(a - 'A' + 'a');
    if (a != b) {
      return false;
    }
  }
  return true;
}

bool SetAutostart(bool enabled) {
  if (!enabled) {
    const LONG status =
        ::RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kAutostartValue);
    return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
  }
  const std::wstring command = L"\"" + ModulePath() + L"\" --tray";
  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                        KEY_SET_VALUE, nullptr, &key,
                        nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const LONG status = ::RegSetValueExW(
      key, kAutostartValue, 0, REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  ::RegCloseKey(key);
  if (status != ERROR_SUCCESS) {
    return false;
  }
  // If the entry was switched off in Task Manager, switch it back on.
  ::RegDeleteKeyValueW(HKEY_CURRENT_USER, kStartupApprovedKey, kAutostartValue);
  return true;
}

bool GetAutostart() {
  DWORD size = 0;
  if (::RegGetValueW(HKEY_CURRENT_USER, kRunKey, kAutostartValue, RRF_RT_REG_SZ,
                     nullptr, nullptr, &size) != ERROR_SUCCESS) {
    return false;
  }
  // Task Manager's Startup tab records "disabled" as an odd first byte.
  BYTE approved[16] = {};
  DWORD approved_size = sizeof(approved);
  if (::RegGetValueW(HKEY_CURRENT_USER, kStartupApprovedKey, kAutostartValue,
                     RRF_RT_REG_BINARY, nullptr, approved,
                     &approved_size) == ERROR_SUCCESS &&
      approved_size > 0 && (approved[0] & 1) != 0) {
    return false;
  }
  return true;
}

std::optional<std::wstring> RunFileDialog(HWND owner, bool save,
                                          const std::wstring& initial_name,
                                          const std::wstring& initial_dir) {
  std::vector<wchar_t> buffer(32768, L'\0');
  for (size_t i = 0; i < initial_name.size() && i + 1 < buffer.size(); i++) {
    buffer[i] = initial_name[i];
  }

  OPENFILENAMEW dialog = {};
  dialog.lStructSize = sizeof(dialog);
  dialog.hwndOwner = owner;
  dialog.lpstrFile = buffer.data();
  dialog.nMaxFile = static_cast<DWORD>(buffer.size());
  dialog.lpstrFilter =
      L"Pray files (*.pray)\0*.pray\0All files (*.*)\0*.*\0";
  dialog.nFilterIndex = 1;
  if (!initial_dir.empty()) {
    dialog.lpstrInitialDir = initial_dir.c_str();
  }
  dialog.Flags = OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR |
                 OFN_HIDEREADONLY;
  BOOL chosen = FALSE;
  if (save) {
    dialog.Flags |= OFN_OVERWRITEPROMPT;
    chosen = ::GetSaveFileNameW(&dialog);
  } else {
    dialog.Flags |= OFN_FILEMUSTEXIST;
    chosen = ::GetOpenFileNameW(&dialog);
  }
  if (!chosen) {
    return std::nullopt;
  }
  return std::wstring(buffer.data());
}

}  // namespace

PrayPlatform::PrayPlatform(HWND window, flutter::BinaryMessenger* messenger)
    : window_(window) {
  taskbar_created_message_ = ::RegisterWindowMessageW(L"TaskbarCreated");

  const flutter::StandardMethodCodec& codec =
      flutter::StandardMethodCodec::GetInstance();
  window_channel_ = std::make_unique<Channel>(messenger, "pray/window", &codec);
  tray_channel_ = std::make_unique<Channel>(messenger, "pray/tray", &codec);
  system_channel_ = std::make_unique<Channel>(messenger, "pray/system", &codec);

  window_channel_->SetMethodCallHandler(
      [this](const Call& call, std::unique_ptr<Result> result) {
        OnWindowCall(call, std::move(result));
      });
  tray_channel_->SetMethodCallHandler(
      [this](const Call& call, std::unique_ptr<Result> result) {
        OnTrayCall(call, std::move(result));
      });
  system_channel_->SetMethodCallHandler(
      [this](const Call& call, std::unique_ptr<Result> result) {
        OnSystemCall(call, std::move(result));
      });
}

PrayPlatform::~PrayPlatform() {
  window_channel_->SetMethodCallHandler(nullptr);
  tray_channel_->SetMethodCallHandler(nullptr);
  system_channel_->SetMethodCallHandler(nullptr);
  if (window_ != nullptr) {
    ::KillTimer(window_, kTrayRetryTimer);
    ::KillTimer(window_, kQuitTimer);
  }
  RemoveTrayIcon();
  if (icon_ != nullptr) {
    ::DestroyIcon(icon_);
    icon_ = nullptr;
  }
}

// static
UINT PrayPlatform::ShowWindowMessage() {
  static const UINT message = ::RegisterWindowMessageW(kShowWindowMessageName);
  return message;
}

bool PrayPlatform::HandleMessage(HWND window, UINT message, WPARAM wparam,
                                 LPARAM lparam, LRESULT* result) {
  if (message == ShowWindowMessage()) {
    ShowWindowNow();
    *result = 0;
    return true;
  }
  if (taskbar_created_message_ != 0 && message == taskbar_created_message_) {
    // Explorer restarted: its tray is empty again.
    tray_added_ = false;
    tray_retries_ = 0;
    AddTrayIcon();
    *result = 0;
    return true;
  }

  switch (message) {
    case kTrayMessage:
      switch (LOWORD(lparam)) {
        case WM_LBUTTONUP:
          tray_channel_->InvokeMethod("activate", nullptr);
          break;
        case WM_RBUTTONUP:
          ShowTrayMenu();
          break;
        default:
          break;
      }
      *result = 0;
      return true;

    case WM_TIMER:
      if (wparam == kTrayRetryTimer) {
        // The taskbar may not exist yet right after login; keep trying.
        tray_retries_++;
        if (AddTrayIcon() || tray_retries_ >= kMaxTrayRetries) {
          ::KillTimer(window_, kTrayRetryTimer);
        }
        *result = 0;
        return true;
      }
      if (wparam == kQuitTimer) {
        // Safety net: the Dart side did not finish the exit in time.
        ::KillTimer(window_, kQuitTimer);
        ::ExitProcess(0);
      }
      return false;

    case WM_CLOSE:
      if (quitting_) {
        return false;
      }
      if (tray_added_) {
        HideWindowNow();
      } else {
        // Without a tray icon there would be no way to bring the window back.
        ::ShowWindow(window_, SW_MINIMIZE);
      }
      *result = 0;
      return true;

    case WM_QUERYENDSESSION:
      *result = TRUE;
      return true;

    case WM_GETMINMAXINFO: {
      MINMAXINFO* info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = ::GetDpiForWindow(window);
      RECT frame = {0, 0, ::MulDiv(kMinWidth, static_cast<int>(dpi), 96),
                    ::MulDiv(kMinHeight, static_cast<int>(dpi), 96)};
      ::AdjustWindowRectExForDpi(&frame, WS_OVERLAPPEDWINDOW, FALSE, 0, dpi);
      info->ptMinTrackSize.x = frame.right - frame.left;
      info->ptMinTrackSize.y = frame.bottom - frame.top;
      *result = 0;
      return true;
    }

    case WM_DESTROY:
      RemoveTrayIcon();
      return false;

    default:
      return false;
  }
}

void PrayPlatform::ShowWindowNow() {
  if (::IsIconic(window_)) {
    ::ShowWindow(window_, SW_RESTORE);
  } else {
    ::ShowWindow(window_, SW_SHOW);
  }
  ::SetForegroundWindow(window_);
}

void PrayPlatform::HideWindowNow() { ::ShowWindow(window_, SW_HIDE); }

void PrayPlatform::ToggleWindow() {
  // Clicking the tray icon moves focus to the taskbar, so "is the foreground
  // window" cannot be used here; visible means hide, anything else means show.
  if (::IsWindowVisible(window_) && !::IsIconic(window_)) {
    HideWindowNow();
  } else {
    ShowWindowNow();
  }
}

void PrayPlatform::Quit() {
  quitting_ = true;
  RemoveTrayIcon();
  ::SetTimer(window_, kQuitTimer, 4000, nullptr);
  ::PostMessageW(window_, WM_CLOSE, 0, 0);
}

bool PrayPlatform::AddTrayIcon() {
  if (icon_ == nullptr) {
    return false;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = 1;
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kTrayMessage;
  data.hIcon = icon_;
  CopyToBuffer(data.szTip, title_);
  if (::Shell_NotifyIconW(NIM_MODIFY, &data) ||
      ::Shell_NotifyIconW(NIM_ADD, &data)) {
    tray_added_ = true;
    return true;
  }
  tray_added_ = false;
  return false;
}

void PrayPlatform::RemoveTrayIcon() {
  if (!tray_added_ || window_ == nullptr) {
    return;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = 1;
  ::Shell_NotifyIconW(NIM_DELETE, &data);
  tray_added_ = false;
}

void PrayPlatform::UpdateTrayIcon() {
  if (!tray_added_) {
    return;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = 1;
  data.uFlags = NIF_ICON | NIF_TIP;
  data.hIcon = icon_;
  CopyToBuffer(data.szTip, title_);
  ::Shell_NotifyIconW(NIM_MODIFY, &data);
}

void PrayPlatform::ShowBalloon(const std::wstring& title,
                               const std::wstring& body) {
  if (!tray_added_) {
    return;
  }
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = 1;
  data.uFlags = NIF_INFO;
  data.dwInfoFlags = NIIF_INFO;
  CopyToBuffer(data.szInfoTitle, title);
  CopyToBuffer(data.szInfo, body);
  ::Shell_NotifyIconW(NIM_MODIFY, &data);
}

void PrayPlatform::ShowTrayMenu() {
  HMENU menu = ::CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }
  for (size_t i = 0; i < menu_.size(); i++) {
    const MenuEntry& entry = menu_[i];
    if (entry.separator) {
      ::AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    } else {
      const UINT flags = MF_STRING | (entry.enabled ? MF_ENABLED : MF_GRAYED);
      ::AppendMenuW(menu, flags, static_cast<UINT_PTR>(i + 1),
                    entry.label.c_str());
    }
  }

  POINT cursor = {};
  ::GetCursorPos(&cursor);
  // Required so the menu closes when the user clicks elsewhere.
  ::SetForegroundWindow(window_);
  const UINT command = static_cast<UINT>(::TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON, cursor.x, cursor.y,
      0, window_, nullptr));
  ::PostMessageW(window_, WM_NULL, 0, 0);
  ::DestroyMenu(menu);

  if (command >= 1 && command <= menu_.size()) {
    tray_channel_->InvokeMethod(
        "menuClick", std::make_unique<EncodableValue>(menu_[command - 1].key));
  }
}

bool PrayPlatform::SetIconFromPixels(const EncodableValue* width_value,
                                     const EncodableValue* height_value,
                                     const EncodableValue* rgba_value) {
  const auto width = AsInt(width_value);
  const auto height = AsInt(height_value);
  if (!width || !height || rgba_value == nullptr || *width <= 0 ||
      *height <= 0 || *width > 256 || *height > 256) {
    return false;
  }
  const auto* rgba = std::get_if<std::vector<uint8_t>>(rgba_value);
  const size_t pixel_count =
      static_cast<size_t>(*width) * static_cast<size_t>(*height);
  if (rgba == nullptr || rgba->size() < pixel_count * 4) {
    return false;
  }

  BITMAPV5HEADER header = {};
  header.bV5Size = sizeof(header);
  header.bV5Width = static_cast<LONG>(*width);
  header.bV5Height = -static_cast<LONG>(*height);  // top-down
  header.bV5Planes = 1;
  header.bV5BitCount = 32;
  header.bV5Compression = BI_BITFIELDS;
  header.bV5RedMask = 0x00FF0000;
  header.bV5GreenMask = 0x0000FF00;
  header.bV5BlueMask = 0x000000FF;
  header.bV5AlphaMask = 0xFF000000;

  void* bits = nullptr;
  HDC screen = ::GetDC(nullptr);
  HBITMAP color = ::CreateDIBSection(screen,
                                     reinterpret_cast<BITMAPINFO*>(&header),
                                     DIB_RGB_COLORS, &bits, nullptr, 0);
  ::ReleaseDC(nullptr, screen);
  if (color == nullptr || bits == nullptr) {
    if (color != nullptr) {
      ::DeleteObject(color);
    }
    return false;
  }
  HBITMAP mask = ::CreateBitmap(static_cast<int>(*width),
                                static_cast<int>(*height), 1, 1, nullptr);
  if (mask == nullptr) {
    ::DeleteObject(color);
    return false;
  }

  // Straight (non-premultiplied) RGBA in, 0xAARRGGBB out.
  uint32_t* target = static_cast<uint32_t*>(bits);
  for (size_t i = 0; i < pixel_count; i++) {
    const uint8_t* source = rgba->data() + i * 4;
    target[i] = (static_cast<uint32_t>(source[3]) << 24) |
                (static_cast<uint32_t>(source[0]) << 16) |
                (static_cast<uint32_t>(source[1]) << 8) |
                static_cast<uint32_t>(source[2]);
  }

  ICONINFO info = {};
  info.fIcon = TRUE;
  info.hbmMask = mask;
  info.hbmColor = color;
  HICON icon = ::CreateIconIndirect(&info);
  ::DeleteObject(color);
  ::DeleteObject(mask);
  if (icon == nullptr) {
    return false;
  }

  HICON previous = icon_;
  icon_ = icon;
  if (tray_added_) {
    UpdateTrayIcon();
  }
  if (previous != nullptr) {
    ::DestroyIcon(previous);
  }
  return true;
}

void PrayPlatform::OnWindowCall(const Call& call,
                                std::unique_ptr<Result> result) {
  const std::string& name = call.method_name();
  if (name == "show") {
    ShowWindowNow();
  } else if (name == "hide") {
    HideWindowNow();
  } else if (name == "toggle") {
    ToggleWindow();
  } else if (name == "quit") {
    Quit();
  } else if (name == "notify") {
    const EncodableMap* args = AsMap(call.arguments());
    if (args != nullptr) {
      const auto title = AsString(Find(*args, "title"));
      const auto body = AsString(Find(*args, "body"));
      if (title && body) {
        ShowBalloon(WideFromUtf8(*title), WideFromUtf8(*body));
      }
    }
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}

void PrayPlatform::OnTrayCall(const Call& call,
                              std::unique_ptr<Result> result) {
  const std::string& name = call.method_name();
  if (name == "create") {
    const EncodableMap* args = AsMap(call.arguments());
    if (args == nullptr || !SetIconFromPixels(Find(*args, "width"),
                                             Find(*args, "height"),
                                             Find(*args, "rgba"))) {
      result->Error("bad-args", "The tray icon pixels are missing or invalid.");
      return;
    }
    if (const auto title = AsString(Find(*args, "title"))) {
      title_ = WideFromUtf8(*title);
    }
    tray_retries_ = 0;
    if (!AddTrayIcon()) {
      // The taskbar may not be ready yet (e.g. right after login).
      ::SetTimer(window_, kTrayRetryTimer, 2000, nullptr);
    }
  } else if (name == "setIcon") {
    const EncodableMap* args = AsMap(call.arguments());
    if (args == nullptr || !SetIconFromPixels(Find(*args, "width"),
                                             Find(*args, "height"),
                                             Find(*args, "rgba"))) {
      result->Error("bad-args", "The tray icon pixels are missing or invalid.");
      return;
    }
  } else if (name == "setMenu") {
    std::vector<MenuEntry> entries;
    const auto* list = call.arguments() == nullptr
                           ? nullptr
                           : std::get_if<EncodableList>(call.arguments());
    if (list != nullptr) {
      for (const EncodableValue& item : *list) {
        const EncodableMap* map = AsMap(&item);
        if (map == nullptr) {
          continue;
        }
        MenuEntry entry;
        entry.separator = AsBool(Find(*map, "separator"), false);
        entry.key = AsString(Find(*map, "key")).value_or(std::string());
        entry.label =
            WideFromUtf8(AsString(Find(*map, "label")).value_or(std::string()));
        entry.enabled = AsBool(Find(*map, "enabled"), true);
        entries.push_back(std::move(entry));
      }
    }
    menu_ = std::move(entries);
  } else {
    result->NotImplemented();
    return;
  }
  result->Success();
}

void PrayPlatform::OnSystemCall(const Call& call,
                                std::unique_ptr<Result> result) {
  const std::string& name = call.method_name();
  const EncodableMap* args = AsMap(call.arguments());

  if (name == "openUrl") {
    const auto url = args == nullptr ? std::nullopt
                                     : AsString(Find(*args, "url"));
    // Only web links are opened; anything else could launch a program.
    if (!url || !(StartsWithIgnoreCase(*url, "https://") ||
                  StartsWithIgnoreCase(*url, "http://"))) {
      result->Error("bad-url", "Only http and https links can be opened.");
      return;
    }
    const std::wstring wide = WideFromUtf8(*url);
    const INT_PTR code = reinterpret_cast<INT_PTR>(::ShellExecuteW(
        nullptr, L"open", wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
    if (code <= 32) {
      result->Error("open-failed", "Windows could not open the link.");
      return;
    }
    result->Success();
    return;
  }

  if (name == "pickFilePath" || name == "saveFilePath") {
    const bool save = name == "saveFilePath";
    std::wstring file_name;
    std::wstring directory;
    if (args != nullptr) {
      file_name =
          WideFromUtf8(AsString(Find(*args, "name")).value_or(std::string()));
      directory =
          WideFromUtf8(AsString(Find(*args, "dir")).value_or(std::string()));
    }
    HWND owner = ::IsWindowVisible(window_) ? window_ : nullptr;
    const auto path = RunFileDialog(owner, save, file_name, directory);
    if (!path) {
      result->Success();
      return;
    }
    result->Success(EncodableValue(Utf8FromUtf16(path->c_str())));
    return;
  }

  if (name == "getAutostart") {
    result->Success(EncodableValue(GetAutostart()));
    return;
  }

  if (name == "setAutostart") {
    const bool enabled =
        args == nullptr ? false : AsBool(Find(*args, "enabled"), false);
    if (!SetAutostart(enabled)) {
      result->Error("autostart-failed",
                    "Windows refused to change the startup entry.");
      return;
    }
    result->Success();
    return;
  }

  result->NotImplemented();
}
