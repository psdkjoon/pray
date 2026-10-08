#ifndef RUNNER_PLATFORM_H_
#define RUNNER_PLATFORM_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

void platform_register(FlBinaryMessenger* messenger, GtkWindow* window,
                       GApplication* application);

#endif
