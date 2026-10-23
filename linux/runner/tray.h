#ifndef RUNNER_TRAY_H_
#define RUNNER_TRAY_H_

#include <flutter_linux/flutter_linux.h>

void tray_register(FlBinaryMessenger* messenger);

gboolean tray_is_registered();

#endif
