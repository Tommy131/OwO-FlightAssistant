import 'package:shared_preferences/shared_preferences.dart';

class SimulatorConfigService {
  static const String _xplaneIpKey = 'xplane_ip';
  static const String _xplanePortKey = 'xplane_port';
  static const String _xplaneLocalPortKey = 'xplane_local_port';
  static const String _msfsIpKey = 'msfs_ip';
  static const String _msfsPortKey = 'msfs_port';

  static const String defaultXPlaneIp = '127.0.0.1';
  static const int defaultXPlanePort = 49000;
  static const int defaultXPlaneLocalPort = 19190;
  static const String defaultMsfsIp = 'localhost';
  static const int defaultMsfsPort = 8080;

  Future<Map<String, dynamic>> getXPlaneConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ip': prefs.getString(_xplaneIpKey) ?? defaultXPlaneIp,
      'port': prefs.getInt(_xplanePortKey) ?? defaultXPlanePort,
      'local_port': prefs.getInt(_xplaneLocalPortKey) ?? defaultXPlaneLocalPort,
    };
  }

  Future<void> setXPlaneConfig(String ip, int port, {int? localPort}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_xplaneIpKey, ip);
    await prefs.setInt(_xplanePortKey, port);
    if (localPort != null) {
      await prefs.setInt(_xplaneLocalPortKey, localPort);
    }
  }

  Future<Map<String, dynamic>> getMSFSConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ip': prefs.getString(_msfsIpKey) ?? defaultMsfsIp,
      'port': prefs.getInt(_msfsPortKey) ?? defaultMsfsPort,
    };
  }

  Future<void> setMSFSConfig(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_msfsIpKey, ip);
    await prefs.setInt(_msfsPortKey, port);
  }
}
