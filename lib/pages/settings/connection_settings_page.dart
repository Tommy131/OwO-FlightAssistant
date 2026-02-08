import 'package:flutter/material.dart';
import '../../core/theme/app_theme_data.dart';
import 'package:provider/provider.dart';
import '../../apps/services/config/simulator_config_service.dart';
import '../../apps/providers/simulator/simulator_provider.dart';
import 'widgets/settings_widgets.dart';

class ConnectionSettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const ConnectionSettingsPage({super.key, this.onBack});

  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  final _xplaneIpController = TextEditingController();
  final _xplanePortController = TextEditingController();
  final _xplaneLocalPortController = TextEditingController();
  final _msfsIpController = TextEditingController();
  final _msfsPortController = TextEditingController();

  final _configService = SimulatorConfigService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _xplaneIpController.dispose();
    _xplanePortController.dispose();
    _xplaneLocalPortController.dispose();
    _msfsIpController.dispose();
    _msfsPortController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final xplaneConfig = await _configService.getXPlaneConfig();
      final msfsConfig = await _configService.getMSFSConfig();

      _xplaneIpController.text = xplaneConfig['ip'] as String;
      _xplanePortController.text = (xplaneConfig['port'] as int).toString();
      _xplaneLocalPortController.text =
          (xplaneConfig['local_port'] as int? ?? 19190).toString();
      _msfsIpController.text = msfsConfig['ip'] as String;
      _msfsPortController.text = (msfsConfig['port'] as int).toString();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateIp(String value) {
    if (value.isEmpty) return false;
    // Allow localhost, IPv4, and simple domain names
    final ipRegex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$|^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\.)+[A-Za-z]{2,6}$|^localhost$',
    );
    return ipRegex.hasMatch(value);
  }

  bool _validatePort(String value) {
    if (value.isEmpty) return false;
    final port = int.tryParse(value);
    return port != null && port >= 0 && port <= 65535;
  }

  Future<void> _saveXPlaneSettings() async {
    final ip = _xplaneIpController.text.trim();
    final portStr = _xplanePortController.text.trim();
    final localPortStr = _xplaneLocalPortController.text.trim();

    if (!_validateIp(ip)) {
      _showError('X-Plane IP 地址/域名格式错误');
      return;
    }
    if (!_validatePort(portStr)) {
      _showError('X-Plane 目标端口号必须在 0-65535 之间');
      return;
    }
    if (!_validatePort(localPortStr)) {
      _showError('X-Plane 本地监听端口号必须在 0-65535 之间');
      return;
    }

    final localPort = int.parse(localPortStr);
    final targetPort = int.parse(portStr);

    _showLoadingDialog('正在验证 X-Plane 连接 (请确保 X-Plane 正在运行并发送数据)...');

    final simulatorProvider = Provider.of<SimulatorProvider>(
      context,
      listen: false,
    );
    final isConnected = await simulatorProvider.xplaneService.verifyConnection(
      host: ip,
      targetPort: targetPort,
      localPort: localPort,
      timeout: const Duration(seconds: 10),
    );

    if (!isConnected) {
      _hideLoadingDialog();
      _showError('无法连接到 X-Plane，请确保模拟器正在运行、目标 IP/端口正确，且本地端口 $localPort 未被占用。');
      return;
    }

    await _configService.setXPlaneConfig(ip, targetPort, localPort: localPort);
    _hideLoadingDialog();
    _showSuccess('X-Plane 连接配置已通过验证并保存');
  }

  Future<void> _saveMsfsSettings() async {
    final ip = _msfsIpController.text.trim();
    final portStr = _msfsPortController.text.trim();

    if (!_validateIp(ip)) {
      _showError('MSFS IP 地址/域名格式错误');
      return;
    }
    if (!_validatePort(portStr)) {
      _showError('MSFS 端口号必须在 0-65535 之间');
      return;
    }

    final port = int.parse(portStr);
    _showLoadingDialog('正在验证 MSFS 连接...');

    final simulatorProvider = Provider.of<SimulatorProvider>(
      context,
      listen: false,
    );
    final isConnected = await simulatorProvider.msfsService.verifyConnection(
      wsUrl: 'ws://$ip:$port',
      timeout: const Duration(seconds: 5),
    );

    if (!isConnected) {
      _hideLoadingDialog();
      _showError('无法连接到 MSFS 服务，请确认模拟器已启动、辅助工具已运行并监听在 $ip:$port');
      return;
    }

    await _configService.setMSFSConfig(ip, port);
    _hideLoadingDialog();
    _showSuccess('MSFS 连接配置已通过验证并保存');
  }

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppThemeData.borderRadiusMedium,
            ),
          ),
          backgroundColor: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(AppThemeData.spacingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppThemeData.spacingMedium),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('连接设置'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppThemeData.spacingMedium),
        children: [_buildXPlaneSection(), _buildMsfsSection()],
      ),
    );
  }

  Widget _buildXPlaneSection() {
    return SettingsCard(
      title: 'X-Plane 11/12 连接配置',
      subtitle: '配置 X-Plane 插件监听的 IP 和端口',
      icon: Icons.flight_rounded,
      child: Column(
        children: [
          _buildInputField(
            label: '目标 IP 地址 / 域名',
            controller: _xplaneIpController,
            hint: '例如: 127.0.0.1',
            icon: Icons.lan,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: '端口号 (Port)',
            controller: _xplanePortController,
            hint: '例如: 49000',
            icon: Icons.numbers_rounded,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: '本地监听端口 (Local Port)',
            controller: _xplaneLocalPortController,
            hint: '例如: 19190',
            icon: Icons.input_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveXPlaneSettings,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('验证并保存 X-Plane 配置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMsfsSection() {
    return SettingsCard(
      title: 'MSFS 2020/2024 连接配置',
      subtitle: '配置 MSFS 辅助服务 (WebSocket) 的地址',
      icon: Icons.connecting_airports_rounded,
      child: Column(
        children: [
          _buildInputField(
            label: '服务 IP 地址 / 域名',
            controller: _msfsIpController,
            hint: '例如: localhost',
            icon: Icons.lan,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: '端口号 (Port)',
            controller: _msfsPortController,
            hint: '例如: 8080',
            icon: Icons.numbers_rounded,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveMsfsSettings,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('验证并保存 MSFS 配置'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    // Reusing the style from SettingsInputField but customizing for flexibility
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.1,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              borderSide: BorderSide(
                color: AppThemeData.getBorderColor(
                  theme,
                ).withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                AppThemeData.borderRadiusSmall,
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
