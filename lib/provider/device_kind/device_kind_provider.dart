import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/utils/platform.dart';

/// The kind of device the app is currently running on. Determines which
/// [LayoutMode]s are offered and which one is used by default.
enum SangeetDeviceKind {
  phone,
  laptop,
  tv,
}

extension SangeetDeviceKindInformation on SangeetDeviceKind {
  LayoutMode get defaultLayoutMode => switch (this) {
        SangeetDeviceKind.phone => LayoutMode.adaptive,
        SangeetDeviceKind.laptop => LayoutMode.extended,
        SangeetDeviceKind.tv => LayoutMode.extended,
      };

  List<LayoutMode> get allowedLayoutModes => switch (this) {
        SangeetDeviceKind.phone => [
            LayoutMode.adaptive,
            LayoutMode.compact,
          ],
        SangeetDeviceKind.laptop => [LayoutMode.extended],
        SangeetDeviceKind.tv => [LayoutMode.extended],
      };
}

Future<SangeetDeviceKind> detectDeviceKind() async {
  if (kIsMobile) {
    if (kIsAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        // "android.software.leanback" is the official Android TV feature.
        if (info.systemFeatures.contains('android.software.leanback')) {
          return SangeetDeviceKind.tv;
        }
      } catch (_) {
        // Detection failure → fall back to phone behaviour.
      }
      return SangeetDeviceKind.phone;
    }
    if (kIsIOS) return SangeetDeviceKind.phone;
  }
  return SangeetDeviceKind.laptop;
}

final deviceKindProvider = FutureProvider<SangeetDeviceKind>(
  (ref) => detectDeviceKind(),
);
