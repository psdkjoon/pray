#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "pray_platform.h"
#include "utils.h"

namespace {

constexpr wchar_t kInstanceMutexName[] = L"Local\\ir.psdkjoon.pray.instance";
// Must match the window class registered in win32_window.cpp.
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr wchar_t kWindowTitle[] = L"Pray";

bool HasArgument(const std::vector<std::string>& arguments, const char* name) {
  for (const std::string& argument : arguments) {
    if (argument == name) {
      return true;
    }
  }
  return false;
}

// Puts this process in a job object that kills every process in it when the
// last handle closes. xray.exe is started as a child of Pray, so it is stopped
// together with the app even if Pray is killed or crashes, instead of staying
// behind and holding the proxy port.
void KillChildrenOnExit() {
  HANDLE job = ::CreateJobObjectW(nullptr, nullptr);
  if (job == nullptr) {
    return;
  }
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION info = {};
  info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  if (!::SetInformationJobObject(job, JobObjectExtendedLimitInformation, &info,
                                 sizeof(info)) ||
      !::AssignProcessToJobObject(job, ::GetCurrentProcess())) {
    ::CloseHandle(job);
  }
  // The handle is intentionally kept open until the process ends.
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool start_hidden = HasArgument(command_line_arguments, "--tray") ||
                            HasArgument(command_line_arguments, "--hidden");

  // Only one Pray at a time: a second launch brings the first one forward.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, FALSE, kInstanceMutexName);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    if (!start_hidden) {
      HWND existing = ::FindWindowW(kWindowClassName, kWindowTitle);
      if (existing != nullptr) {
        ::AllowSetForegroundWindow(ASFW_ANY);
        ::PostMessageW(existing, PrayPlatform::ShowWindowMessage(), 0, 0);
      }
    }
    ::CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  KillChildrenOnExit();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Centre a 1000x680 window (logical pixels) on the primary monitor, and keep
  // it inside small screens.
  const double scale = static_cast<double>(::GetDpiForSystem()) / 96.0;
  const double screen_width = ::GetSystemMetrics(SM_CXSCREEN) / scale;
  const double screen_height = ::GetSystemMetrics(SM_CYSCREEN) / scale;
  const double width = std::max(380.0, std::min(1000.0, screen_width - 40.0));
  const double height = std::max(520.0, std::min(680.0, screen_height - 80.0));
  const double left = std::max(0.0, (screen_width - width) / 2.0);
  const double top = std::max(0.0, (screen_height - height) / 2.0);

  FlutterWindow window(project, start_hidden);
  Win32Window::Point origin(static_cast<unsigned int>(left),
                            static_cast<unsigned int>(top));
  Win32Window::Size size(static_cast<unsigned int>(width),
                         static_cast<unsigned int>(height));
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
