#include "flutter_menu_plugin.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "flutter/menu";
constexpr char kMenuSetMethod[] = "Menu.setMenus";
constexpr char kIsPluginAvailableMethod[] = "Menu.isPluginAvailable";
constexpr char kMenuSelectedCallbackMethod[] = "Menu.selectedCallback";
constexpr char kWindowKey[] = "0";
constexpr char kIdKey[] = "id";
constexpr char kLabelKey[] = "label";
constexpr char kEnabledKey[] = "enabled";
constexpr char kChildrenKey[] = "children";
constexpr char kIsDividerKey[] = "isDivider";
constexpr char kBadArgumentsError[] = "Bad Arguments";
constexpr char kMenuConstructionError[] = "Menu Construction Error";
constexpr unsigned int kFirstMenuId = 1000;

const EncodableValue* ValueOrNull(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &(it->second);
}

std::wstring Utf16FromUtf8(const std::string& utf8_string) {
  if (utf8_string.empty()) {
    return std::wstring();
  }
  const int target_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), nullptr, 0);
  if (target_length == 0) {
    return std::wstring();
  }
  std::wstring utf16_string;
  utf16_string.resize(target_length);
  const int converted_length = ::MultiByteToWideChar(
      CP_UTF8, MB_ERR_INVALID_CHARS, utf8_string.data(),
      static_cast<int>(utf8_string.length()), utf16_string.data(),
      target_length);
  if (converted_length == 0) {
    return std::wstring();
  }
  return utf16_string;
}

std::optional<EncodableValue> AddMenuItem(HMENU menu,
                                          const EncodableMap& representation);

std::optional<EncodableValue> PopulateMenu(
    HMENU menu,
    const EncodableList& representation) {
  for (const auto& item : representation) {
    const auto* item_map = std::get_if<EncodableMap>(&item);
    if (!item_map) {
      return EncodableValue(kBadArgumentsError);
    }
    auto optional_error = AddMenuItem(menu, *item_map);
    if (optional_error) {
      return optional_error;
    }
  }
  return std::nullopt;
}

std::optional<EncodableValue> AddMenuItem(HMENU menu,
                                          const EncodableMap& representation) {
  const auto* is_divider =
      std::get_if<bool>(ValueOrNull(representation, kIsDividerKey));
  if (is_divider && *is_divider) {
    if (!::AppendMenu(menu, MF_SEPARATOR, 0, nullptr)) {
      return EncodableValue(static_cast<int32_t>(::GetLastError()));
    }
    return std::nullopt;
  }

  const auto* label =
      std::get_if<std::string>(ValueOrNull(representation, kLabelKey));
  const std::wstring wide_label(label ? Utf16FromUtf8(*label) : L"");
  UINT flags = MF_STRING;

  const auto* enabled =
      std::get_if<bool>(ValueOrNull(representation, kEnabledKey));
  flags |= (enabled == nullptr || *enabled) ? MF_ENABLED : MF_GRAYED;

  const auto* children =
      std::get_if<EncodableList>(ValueOrNull(representation, kChildrenKey));
  UINT_PTR item_id = 0;
  if (children) {
    flags |= MF_POPUP;
    HMENU submenu = ::CreatePopupMenu();
    auto optional_error = PopulateMenu(submenu, *children);
    if (optional_error) {
      ::DestroyMenu(submenu);
      return optional_error;
    }
    item_id = reinterpret_cast<UINT_PTR>(submenu);
  } else {
    const auto* menu_id =
        std::get_if<int32_t>(ValueOrNull(representation, kIdKey));
    item_id = menu_id ? (kFirstMenuId + static_cast<unsigned int>(*menu_id))
                      : 0;
  }

  if (!::AppendMenu(menu, flags, item_id, wide_label.c_str())) {
    return EncodableValue(static_cast<int32_t>(::GetLastError()));
  }
  return std::nullopt;
}

}  // namespace

FlutterMenuPlugin::FlutterMenuPlugin(flutter::BinaryMessenger* messenger,
                                     HWND window)
    : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

FlutterMenuPlugin::~FlutterMenuPlugin() = default;

void FlutterMenuPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare(kIsPluginAvailableMethod) == 0) {
    result->Success(EncodableValue(true));
    return;
  }

  if (method_call.method_name().compare(kMenuSetMethod) != 0) {
    result->NotImplemented();
    return;
  }

  if (!window_) {
    result->Error(kMenuConstructionError,
                  "Cannot add a menu to a headless engine.");
    return;
  }

  const auto* args = std::get_if<EncodableMap>(method_call.arguments());
  if (!args) {
    result->Error(kBadArgumentsError, "Expected a map of menus.");
    return;
  }

  const EncodableValue* window_menus = ValueOrNull(*args, kWindowKey);
  if (!window_menus) {
    result->Success();
    return;
  }

  const auto* menu_list = std::get_if<EncodableList>(window_menus);
  if (!menu_list) {
    result->Error(kBadArgumentsError, "Expected a list of menus.");
    return;
  }

  HMENU menu = ::CreateMenu();
  HMENU previous_menu = ::GetMenu(window_);
  std::optional<EncodableValue> optional_error = PopulateMenu(menu, *menu_list);
  if (optional_error) {
    ::DestroyMenu(menu);
    result->Error(kMenuConstructionError, "Unable to construct menu",
                  *optional_error);
    return;
  }

  if (!::SetMenu(window_, menu)) {
    ::DestroyMenu(menu);
    result->Error(kMenuConstructionError, "Unable to set menu",
                  EncodableValue(static_cast<int32_t>(::GetLastError())));
    return;
  }

  if (previous_menu) {
    ::DestroyMenu(previous_menu);
  }

  ::DrawMenuBar(window_);
  result->Success();
}

std::optional<LRESULT> FlutterMenuPlugin::HandleWindowProc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) {
  if (message == WM_COMMAND) {
    const DWORD menu_id = LOWORD(wparam);
    if (menu_id >= kFirstMenuId) {
      const int32_t flutter_id =
          static_cast<int32_t>(menu_id - kFirstMenuId);
      channel_->InvokeMethod(
          kMenuSelectedCallbackMethod,
          std::make_unique<EncodableValue>(flutter_id));
      return 0;
    }
  }
  return std::nullopt;
}
