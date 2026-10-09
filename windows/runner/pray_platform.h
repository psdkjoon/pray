#ifndef RUNNER_PRAY_PLATFORM_H_
#define RUNNER_PRAY_PLATFORM_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

// Desktop integration for Pray on Windows. It implements the same platform
// channels the Linux runner provides:
//
//   pray/window  show, hide, toggle, quit, notify
//   pray/tray    create, setIcon, setMenu (calls back: activate, menuClick)
//   pray/system  openUrl, pickFilePath, saveFilePath, getAutostart,
//                setAutostart
//
// plus close-to-tray, a minimum window size and the "show the window" message
// a second launch sends to the running instance.
class PrayPlatform {
 public:
  PrayPlatform(HWND window, flutter::BinaryMessenger* messenger);
  ~PrayPlatform();

  PrayPlatform(const PrayPlatform&) = delete;
  PrayPlatform& operator=(const PrayPlatform&) = delete;

  // Handles a message for the top-level window. Returns true (and sets
  // |result|) when the message was consumed.
  bool HandleMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam,
                     LRESULT* result);

  // Registered window message a second instance posts to bring the first one
  // to the front.
  static UINT ShowWindowMessage();

 private:
  struct MenuEntry {
    std::string key;
    std::wstring label;
    bool enabled = true;
    bool separator = false;
  };

  using Value = flutter::EncodableValue;
  using Channel = flutter::MethodChannel<flutter::EncodableValue>;
  using Call = flutter::MethodCall<flutter::EncodableValue>;
  using Result = flutter::MethodResult<flutter::EncodableValue>;

  void OnWindowCall(const Call& call, std::unique_ptr<Result> result);
  void OnTrayCall(const Call& call, std::unique_ptr<Result> result);
  void OnSystemCall(const Call& call, std::unique_ptr<Result> result);

  void ShowWindowNow();
  void HideWindowNow();
  void ToggleWindow();
  void Quit();

  bool AddTrayIcon();
  void RemoveTrayIcon();
  void UpdateTrayIcon();
  void ShowBalloon(const std::wstring& title, const std::wstring& body);
  void ShowTrayMenu();
  bool SetIconFromPixels(const Value* width, const Value* height,
                         const Value* rgba);

  HWND window_;
  std::unique_ptr<Channel> window_channel_;
  std::unique_ptr<Channel> tray_channel_;
  std::unique_ptr<Channel> system_channel_;

  HICON icon_ = nullptr;
  std::wstring title_ = L"Pray";
  std::vector<MenuEntry> menu_;
  bool tray_added_ = false;
  int tray_retries_ = 0;
  bool quitting_ = false;
  UINT taskbar_created_message_ = 0;
};

#endif  // RUNNER_PRAY_PLATFORM_H_
