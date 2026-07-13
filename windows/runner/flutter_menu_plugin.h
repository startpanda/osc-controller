#ifndef RUNNER_FLUTTER_MENU_PLUGIN_H_
#define RUNNER_FLUTTER_MENU_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>

#include <windows.h>

class FlutterMenuPlugin {
 public:
  FlutterMenuPlugin(flutter::BinaryMessenger* messenger, HWND window);
  ~FlutterMenuPlugin();

  std::optional<LRESULT> HandleWindowProc(HWND hwnd,
                                            UINT message,
                                            WPARAM wparam,
                                            LPARAM lparam);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_FLUTTER_MENU_PLUGIN_H_
