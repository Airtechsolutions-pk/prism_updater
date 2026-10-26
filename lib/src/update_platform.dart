import 'package:flutter/foundation.dart';

/// Information about the platform the app is running on, used to pick the
/// right update flow per platform.
///
/// Web and desktop builds cannot rely on store flows, so the package exposes
/// explicit platform info that screens and controllers branch on.
class PrismUpdatePlatformInfo {
  /// Creates platform info.
  const PrismUpdatePlatformInfo({
    required this.isWeb,
    required this.isAndroid,
    required this.isIOS,
    required this.isWindows,
    required this.isMacOS,
    required this.isLinux,
  });

  /// Detects the current platform from [defaultTargetPlatform].
  factory PrismUpdatePlatformInfo.detect() {
    final target = defaultTargetPlatform;
    return PrismUpdatePlatformInfo(
      isWeb: kIsWeb,
      isAndroid: !kIsWeb && target == TargetPlatform.android,
      isIOS: !kIsWeb && target == TargetPlatform.iOS,
      isWindows:
          !kIsWeb && target == TargetPlatform.windows,
      isMacOS: !kIsWeb && target == TargetPlatform.macOS,
      isLinux: !kIsWeb && target == TargetPlatform.linux,
    );
  }

  /// Whether the app runs in a browser.
  final bool isWeb;

  /// Whether the app runs on Android.
  final bool isAndroid;

  /// Whether the app runs on iOS.
  final bool isIOS;

  /// Whether the app runs on Windows.
  final bool isWindows;

  /// Whether the app runs on macOS.
  final bool isMacOS;

  /// Whether the app runs on Linux.
  final bool isLinux;

  /// A canonical platform key used to look up download URLs in remote
  /// metadata: `web`, `android`, `ios`, `windows`, `macos`, `linux`.
  String get key {
    if (isWeb) return 'web';
    if (isAndroid) return 'android';
    if (isIOS) return 'ios';
    if (isWindows) return 'windows';
    if (isMacOS) return 'macos';
    return 'linux';
  }

  /// Whether this platform can open a store page directly (Android/iOS).
  bool get hasStoreFlow => isAndroid || isIOS;

  /// Whether updates must go through a direct download URL (desktop/web).
  bool get needsDownloadUrl => isWeb || isWindows || isMacOS || isLinux;
}
