import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Interop channel with Android's MainActivity to manage activity lifecycle
/// for the share popup (e.g. moving task to back smoothly).
class AndroidAppChannel {
  AndroidAppChannel._();

  static const MethodChannel _channel = MethodChannel('gopeed.com/app');

  /// Sends the current Android task to the background, immediately returning
  /// the user to the calling application (e.g. YouTube, Facebook, X, Chrome)
  /// while keeping Gopeed's background download service active.
  static Future<bool> moveTaskToBack() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final res = await _channel.invokeMethod<bool>('moveTaskToBack');
      return res ?? true;
    } catch (_) {
      try {
        await SystemNavigator.pop();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Closes the Android activity.
  static Future<void> finish() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('finish');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }
}
