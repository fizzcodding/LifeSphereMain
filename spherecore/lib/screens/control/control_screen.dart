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
  ControlMode _mode = ControlMode.hybrid;

  double _joyX = 0;
  double _joyY = 0;

  String _camIP = '';
  String _ctrlIP = '';
  final _camCtrl = TextEditingController();
  final _ctrlCtrl = TextEditingController();

  bool _connected = false;
  double _led = 0;
  Timer? _ledDebounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _camIP = p.getString('cam_ip') ?? '';
      _ctrlIP = p.getString('ctrl_ip') ?? '';
      _camCtrl.text = _camIP;
      _ctrlCtrl.text = _ctrlIP;
    });
    if (_ctrlIP.isNotEmpty) _connect();
  }

  void _connect() {
    final ip = _ctrlIP.isNotEmpty ? _ctrlIP : _camIP;
    if (ip.isEmpty) return;
    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse('ws://$ip:81'));
      setState(() => _connected = true);
      _send('M,${_mode.index}');
    } catch (_) {
      setState(() => _connected = false);
      showErrorToast('Connection failed: Check IP');
    }
  }

  void _send(String msg) {
    if (_channel != null && _connected) _channel!.sink.add(msg);
  }

  void _sendJoy(double x, double y) {
    _send('J,${(x * 25).toStringAsFixed(1)},${(y * 20).toStringAsFixed(1)}');
  }

  Future<void> _saveIPs() async {
    final p = await SharedPreferences.getInstance();
    final cam = _camCtrl.text.trim();
    final ctrl = _ctrlCtrl.text.trim();
    await p.setString('cam_ip', cam);
    await p.setString('ctrl_ip', ctrl);
    setState(() { _camIP = cam; _ctrlIP = ctrl; });
    _connect();
    showSuccessToast('Device IPs saved');
  }

  void _onLedChanged(double v) {
    setState(() => _led = v);
    _ledDebounce?.cancel();
    _ledDebounce = Timer(const Duration(milliseconds: 150), () async {
      final ip = _camIP.isNotEmpty ? _camIP : _ctrlIP;
      if (ip.isEmpty) return;
      try { await http.get(Uri.parse('http://$ip/led?val=${v.round()}')); } catch (_) {}
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _camCtrl.dispose();
    _ctrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 6,
              backgroundColor: _connected ? AppTheme.secondary : AppTheme.danger,
            )
            .animate(onPlay: (c) => c.repeat())
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 1.seconds, curve: Curves.easeInOut)
            .then()
            .scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/control'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          children: [
            _configCard(t),
            const SizedBox(height: 16),
            _streamSection(t),
            const SizedBox(height: 24),
            _modeSelector(t),
            const SizedBox(height: 32),
            _joystick(t),
            const SizedBox(height: 48),
          ],
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }

  Widget _configCard(ThemeData t) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PremiumPanel(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Configuration', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _camCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ESP32-CAM IP',
                        hintText: 'e.g. 192.168.1.10',
                        prefixIcon: Icon(Icons.videocam_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Servo ESP32 IP',
                        hintText: 'e.g. 192.168.1.11',
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
                  label: const Text('Apply & Connect'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _streamSection(ThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.live_tv_rounded, size: 20, color: AppTheme.danger),
              const SizedBox(width: 8),
              Text('Live Feed', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.dividerColor.withValues(alpha: 0.1)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            clipBehavior: Clip.antiAlias,
            child: (_camIP.isNotEmpty || _ctrlIP.isNotEmpty)
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      RotatedBox(
                        quarterTurns: 2,
                        child: MJPEGStreamScreen(
                          streamUrl: 'http://${_camIP.isNotEmpty ? _camIP : _ctrlIP}/streamahh',
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: AppTheme.danger),
                              SizedBox(width: 6),
                              Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _placeholder(t, 'Enter IP to start stream'),
          ),
          const SizedBox(height: 16),
          _ledControl(t),
        ],
      ),
    );
  }

  Widget _ledControl(ThemeData t) {
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
                    _led > 0 ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
                    size: 20, color: _led > 0 ? AppTheme.secondary : AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Text('LED Power', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '${((_led / 255) * 100).round()}%',
                style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: t.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _led,
            min: 0,
            max: 255,
            onChanged: _onLedChanged,
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeData t, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, size: 48, color: AppTheme.secondary.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: t.hintColor)),
        ],
      ),
    );
  }

  Widget _modeSelector(ThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Operation Mode', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: ControlMode.values.map((m) {
              final sel = _mode == m;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () { setState(() => _mode = m); _send('M,${m.index}'); },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sel ? Colors.transparent : AppTheme.border),
                        boxShadow: sel ? [AppTheme.softShadow] : null,
                      ),
                      child: Text(
                        m.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel ? Colors.white : t.textTheme.bodyMedium?.color,
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

  Widget _joystick(ThemeData t) {
    return Center(
      child: Column(
        children: [
          Text('Joystick Control', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                _joyX = (_joyX + d.delta.dx / 100).clamp(-1, 1);
                _joyY = (_joyY + d.delta.dy / 100).clamp(-1, 1);
              });
              _sendJoy(_joyX, _joyY);
            },
            onPanEnd: (_) {
              setState(() { _joyX = 0; _joyY = 0; });
              _send('J,0,0');
            },
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppTheme.surface, AppTheme.background, AppTheme.border]),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: 2)],
              ),
              child: CustomPaint(
                painter: _JoystickPainter(
                  x: _joyX, y: _joyY,
                  knobColor: t.primaryColor,
                  baseColor: t.dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final double x;
  final double y;
  final Color knobColor;
  final Color baseColor;

  _JoystickPainter({
    required this.x,
    required this.y,
    required this.knobColor,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final ring = Paint()..color = baseColor..style = PaintingStyle.stroke..strokeWidth = 1;
    canvas.drawCircle(c, r * 0.4, ring);
    canvas.drawCircle(c, r * 0.7, ring);
    canvas.drawCircle(c, r, ring);

    canvas.drawLine(Offset(c.dx - 10, c.dy), Offset(c.dx + 10, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - 10), Offset(c.dx, c.dy + 10), ring);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final knob = Offset(c.dx + x * r * 0.7, c.dy + y * r * 0.7);
    canvas.drawCircle(knob + const Offset(0, 4), 24, shadow);

    final paint = Paint()
      ..shader = RadialGradient(colors: [knobColor.withValues(alpha: 0.8), knobColor])
          .createShader(Rect.fromCircle(center: knob, radius: 24));
    canvas.drawCircle(knob, 24, paint);

    canvas.drawCircle(knob - const Offset(6, 6), 6, Paint()..color = Colors.white.withValues(alpha: 0.3));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
