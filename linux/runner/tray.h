#ifndef RUNNER_TRAY_H_
#define RUNNER_TRAY_H_

#include <flutter_linux/flutter_linux.h>

void tray_register(FlBinaryMessenger* messenger);

// TRUE once a status notifier host (a panel with a tray) has accepted our
// icon. Used to avoid hiding the window when there is no way to bring it back.
gboolean tray_is_registered();

#endif
