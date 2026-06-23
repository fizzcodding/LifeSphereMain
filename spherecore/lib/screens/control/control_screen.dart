import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mjpeg_stream/mjpeg_stream.dart';
import 'package:http/http.dart' as http;
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';
import '../../utils/toast.dart';

enum ControlMode { auto, manual, hybrid }

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  WebSocketChannel? _channel;
  ControlMode _currentMode = ControlMode.hybrid;

  double _joyX = 0;
  double _joyY = 0;

  String _camIP = "";
  String _ctrlIP = "";

  final _camController = TextEditingController();
  final _ctrlController = TextEditingController();

  bool _isConnected = false;
  double _ledValue = 0;
  Timer? _ledDebounce;

  @override
  void initState() {
    super.initState();
    _loadIPs();
  }

  Future<void> _loadIPs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _camIP = prefs.getString("cam_ip") ?? "";
      _ctrlIP = prefs.getString("ctrl_ip") ?? "";
      _camController.text = _camIP;
      _ctrlController.text = _ctrlIP;
    });

    if (_ctrlIP.isNotEmpty) {
      _connectWebSocket();
    }
  }

  void _connectWebSocket() {
    String targetIP = _ctrlIP.isNotEmpty ? _ctrlIP : _camIP;
    if (targetIP.isEmpty) return;

    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse("ws://$targetIP:81"));
      setState(() => _isConnected = true);
      _sendMode();
    } catch (e) {
      setState(() => _isConnected = false);
      showErrorToast("Connection failed: Check IP");
    }
  }

  void _send(String msg) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(msg);
    }
  }

  void _sendMode() {
    _send("M,${_currentMode.index}");
  }

  void _sendJoystick(double x, double y) {
    final pan = x * 25;
    final tilt = y * 20;
    _send("J,${pan.toStringAsFixed(1)},${tilt.toStringAsFixed(1)}");
  }

  Future<void> _saveIPs() async {
    final prefs = await SharedPreferences.getInstance();
    final newCam = _camController.text.trim();
    final newCtrl = _ctrlController.text.trim();

    await prefs.setString("cam_ip", newCam);
    await prefs.setString("ctrl_ip", newCtrl);

    setState(() {
      _camIP = newCam;
      _ctrlIP = newCtrl;
    });

    _connectWebSocket();
    showSuccessToast("Device IPs saved");
  }

  void _onLedSliderChanged(double value) {
    setState(() => _ledValue = value);
    _ledDebounce?.cancel();
    _ledDebounce = Timer(const Duration(milliseconds: 150), () {
      _sendLedValue(value.round());
    });
  }

  Future<void> _sendLedValue(int value) async {
    final ip = _camIP.isNotEmpty ? _camIP : _ctrlIP;
    if (ip.isEmpty) return;

    final url = Uri.parse("http://$ip/led?val=$value");
    try {
      await http.get(url).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _camController.dispose();
    _ctrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child:
                CircleAvatar(
                      radius: 6,
                      backgroundColor: _isConnected
                          ? AppTheme.secondary
                          : AppTheme.danger,
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.2, 1.2),
                      duration: 1.seconds,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.2, 1.2),
                      end: const Offset(0.8, 0.8),
                    ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/control'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          children: [
            _buildConfigCard(theme),
            const SizedBox(height: 16),
            _buildStreamSection(theme),
            const SizedBox(height: 24),
            _buildModeSelector(theme),
            const SizedBox(height: 32),
            _buildJoystickSection(theme),
            const SizedBox(height: 48),
          ],
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }

  Widget _buildConfigCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PremiumPanel(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Device Configuration",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _camController,
                    decoration: const InputDecoration(
                      labelText: "ESP32-CAM IP",
                      hintText: "e.g. 192.168.1.10",
                      prefixIcon: Icon(Icons.videocam_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ctrlController,
                    decoration: const InputDecoration(
                      labelText: "Servo ESP32 IP",
                      hintText: "e.g. 192.168.1.11",
                      prefixIcon: Icon(Icons.settings_input_component),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveIPs,
                icon: const Icon(Icons.save_rounded),
                label: const Text("Apply & Connect"),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStreamSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.live_tv_rounded,
                size: 20,
                color: AppTheme.danger,
              ),
              const SizedBox(width: 8),
              Text(
                "Live Feed",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: (_camIP.isNotEmpty || _ctrlIP.isNotEmpty)
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      RotatedBox(
                        quarterTurns: 2,
                        child: MJPEGStreamScreen(
                          streamUrl:
                              "http://${_camIP.isNotEmpty ? _camIP : _ctrlIP}/streamahh",
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 240,
                          showLiveIcon: true,
                          timeout: const Duration(seconds: 5),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: AppTheme.danger,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "LIVE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildStreamPlaceholder(theme, "Enter IP to start stream"),
          ),
          const SizedBox(height: 16),
          _buildLedControl(theme),
        ],
      ),
    );
  }

  Widget _buildLedControl(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [AppTheme.softShadow],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _ledValue > 0
                        ? Icons.lightbulb_rounded
                        : Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: _ledValue > 0 ? AppTheme.secondary : AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "LED Power",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                "${((_ledValue / 255) * 100).round()}%",
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.secondary,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.secondary.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _ledValue,
              min: 0,
              max: 255,
              onChanged: _onLedSliderChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamPlaceholder(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: AppTheme.secondary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: theme.hintColor)),
        ],
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Operation Mode",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: ControlMode.values.map((mode) {
              final isSelected = _currentMode == mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() => _currentMode = mode);
                      _sendMode();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppTheme.border,
                        ),
                        boxShadow: isSelected ? [AppTheme.softShadow] : null,
                      ),
                      child: Text(
                        mode.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildJoystickSection(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Text(
            "Joystick Control",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                _joyX = (_joyX + d.delta.dx / 100).clamp(-1, 1);
                _joyY = (_joyY + d.delta.dy / 100).clamp(-1, 1);
              });
              _sendJoystick(_joyX, _joyY);
            },
            onPanEnd: (_) {
              setState(() {
                _joyX = 0;
                _joyY = 0;
              });
              _send("J,0,0");
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.surface,
                    AppTheme.background,
                    AppTheme.border,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: JoystickPainter(
                  x: _joyX,
                  y: _joyY,
                  knobColor: theme.primaryColor,
                  baseColor: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JoystickPainter extends CustomPainter {
  final double x;
  final double y;
  final Color knobColor;
  final Color baseColor;

  JoystickPainter({
    required this.x,
    required this.y,
    required this.knobColor,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius * 0.4, ringPaint);
    canvas.drawCircle(center, radius * 0.7, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy + 10),
      ringPaint,
    );

    final knobShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final knobPos = Offset(
      center.dx + x * radius * 0.7,
      center.dy + y * radius * 0.7,
    );

    canvas.drawCircle(knobPos + const Offset(0, 4), 24, knobShadow);

    final knobPaint = Paint()
      ..shader = RadialGradient(
        colors: [knobColor.withValues(alpha: 0.8), knobColor],
      ).createShader(Rect.fromCircle(center: knobPos, radius: 24));

    canvas.drawCircle(knobPos, 24, knobPaint);

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(knobPos - const Offset(6, 6), 6, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
