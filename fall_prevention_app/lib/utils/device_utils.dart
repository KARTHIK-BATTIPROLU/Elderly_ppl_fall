import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceUtils {
  static const String _deviceIdKey = 'device_id';

  /// Get the persistent device ID.
  /// If it doesn't exist, generate one and save it.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    return deviceId;
  }

  /// Generate a random device ID.
  static String _generateDeviceId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomStr = List.generate(10, (_) => random.nextInt(9)).join();
    return 'device_${timestamp}_$randomStr';
  }
}
