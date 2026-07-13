#include "include/flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h"

#include <flutter/plugin_registrar_windows.h>

namespace {

class FlutterSecureStorageWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar) {
    // Legacy method-channel storage is unused; Dart FFI handles Windows I/O.
  }
};

}  // namespace

void FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  FlutterSecureStorageWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}