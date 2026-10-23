#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "pray_platform.h"
#include "win32_window.h"

class FlutterWindow : public Win32Window {
 public:
  FlutterWindow(const flutter::DartProject& project, bool start_hidden);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  flutter::DartProject project_;

  bool start_hidden_;

  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<PrayPlatform> platform_;
};

#endif
