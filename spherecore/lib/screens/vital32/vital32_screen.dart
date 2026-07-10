import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/health_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';

class Vital32Screen extends StatefulWidget {
  const Vital32Screen({super.key});

  @override
  State<Vital32Screen> createState() => _Vital32ScreenState();
}

class _Vital32ScreenState extends State<Vital32Screen> {
  final _svc = HealthService();
  final Map<String, TextEditingController> _dietCtrls = {
    'breakfast': TextEditingController(),
    'lunch': TextEditingController(),
    'dinner': TextEditingController(),
  };
  bool _genAI = false;

  @override
  void dispose() {
    for (final c in _dietCtrls.values) { c.dispose(); }
    super.dispose();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: const [AppUserAvatar()],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/vital32'),
      body: StreamBuilder(
        stream: _svc.vitalsStream(),
        builder: (context, snap) {
          final data = snap.data?.snapshot.value as Map? ?? {};
          final steps = _val(data, 'steps');
          final hr = _val(data, 'hr');
          final spo2 = _val(data, 'spo2');
          final temp = _val(data, 'temp').toDouble();
          final hydration = _val(data, 'hydration');
          final tips = data['aiSuggestions'] as Map? ?? {};
          final diet = data['diet'] as Map? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context),
                const SizedBox(height: 18),
                _vitalsPanel(hr, spo2, temp),
                const SizedBox(height: 18),
                _trendChart(hr, spo2, hydration),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _statCard('Step Count', steps.toString(), Icons.directions_walk_rounded, AppTheme.primary)),
                    const SizedBox(width: 14),
                    Expanded(child: _statCard('Hydration', '$hydration ml', Icons.water_drop_rounded, AppTheme.secondary)),
                  ],
                ),
                const SizedBox(height: 18),
                _hydrationControls(hydration),
                const SizedBox(height: 22),
                _aiInsights(tips),
                const SizedBox(height: 22),
                _dietSection(diet),
              ],
            ),
          );
        },
      ),
    );
  }

  int _val(Map data, String key) {
    final v = data[key];
    if (v is Map && v['currently'] is num) {
      return (v['currently'] as num).toInt();
    }
    return 0;
  }

  Widget _header(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vital32', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 4),
        Text('${now.day} ${_months[now.month - 1]}', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _vitalsPanel(int hr, int spo2, double temp) {
    return PremiumPanel(
      child: Row(
        children: [
          SizedBox(
            width: 138, height: 138,
            child: Stack(
              children: [
                _Ring(progress: hr / 200, color: AppTheme.danger, strokeWidth: 12, radius: 60),
                _Ring(progress: spo2 / 100, color: AppTheme.secondary, strokeWidth: 12, radius: 45),
                _Ring(progress: (temp - 30) / 10, color: AppTheme.primary, strokeWidth: 12, radius: 30),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Heart Rate', '$hr BPM', AppTheme.danger),
                _label('SpO2', '$spo2%', AppTheme.secondary),
                _label('Temperature', '${temp.toStringAsFixed(1)} C', AppTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _trendChart(int hr, int spo2, int hydration) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trends', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                primaryValues: _trend(hr == 0 ? 72 : hr, 14),
                secondaryValues: _trend(spo2 == 0 ? 96 : spo2, 9),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hydration ${hydration.clamp(0, 2500)} / 2500 ml',
            style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  List<double> _trend(int base, int spread) {
    return List.generate(8, (i) => (base + math.sin(i * 0.85) * spread).toDouble());
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _hydrationControls(int current) {
    return PremiumPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hydration Tracker', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('$current / 2500 ml today', style: const TextStyle(color: AppTheme.secondary)),
              ],
            ),
          ),
          _btn(Icons.remove_rounded, () => _svc.updateHydration(-250)),
          const SizedBox(width: 12),
          _btn(Icons.add_rounded, () => _svc.updateHydration(250)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(icon, color: AppTheme.secondary),
      ),
    );
  }

  Widget _aiInsights(Map tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('AI Insights', style: Theme.of(context).textTheme.titleLarge)),
            _genAI
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () async {
                      setState(() => _genAI = true);
                      await _svc.generateAISuggestions();
                      if (mounted) setState(() => _genAI = false);
                    },
                  ),
          ],
        ),
        const SizedBox(height: 10),
        if (tips.isEmpty)
          PremiumPanel(child: Text('No insights yet.', style: Theme.of(context).textTheme.bodyMedium))
        else
          ...tips.values.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PremiumPanel(
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.secondary),
                  const SizedBox(width: 14),
                  Expanded(child: Text(tip.toString())),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Widget _dietSection(Map diet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Diet Planner', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _mealTile('breakfast', Icons.wb_sunny_rounded, diet['breakfast'] ?? []),
        _mealTile('lunch', Icons.sunny, diet['lunch'] ?? []),
        _mealTile('dinner', Icons.nightlight_round, diet['dinner'] ?? []),
      ],
    );
  }

  Widget _mealTile(String title, IconData icon, List items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPanel(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          leading: Icon(icon, color: AppTheme.secondary),
          title: Text(title.toUpperCase()),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dietCtrls[title],
                      decoration: const InputDecoration(hintText: 'Add food item', isDense: true),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppTheme.secondary),
                    onPressed: () {
                      final ctrl = _dietCtrls[title];
                      final val = ctrl?.text.trim();
                      if (ctrl == null || val == null || val.isEmpty) return;
                      _svc.addDietItem(title, val);
                      ctrl.clear();
                    },
                  ),
                ],
              ),
            ),
            ...items.asMap().entries.map((e) => ListTile(
              title: Text(e.value.toString()),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                onPressed: () => _svc.removeDietItem(title, e.key),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double radius;

  const _Ring({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress, color: color, strokeWidth: strokeWidth, radius: radius,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double radius;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final track = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final prog = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      prog,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _LineChartPainter extends CustomPainter {
  final List<double> primaryValues;
  final List<double> secondaryValues;

  _LineChartPainter({required this.primaryValues, required this.secondaryValues});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = AppTheme.border..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    _draw(canvas, size, primaryValues, AppTheme.primary);
    _draw(canvas, size, secondaryValues, AppTheme.secondary);
  }

  void _draw(Canvas canvas, Size size, List<double> values, Color color) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).clamp(1.0, double.infinity);

    final pts = List.generate(values.length, (i) {
      return Offset(
        size.width * i / (values.length - 1),
        size.height - ((values[i] - min) / range * size.height),
      );
    });

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final cur = pts[i], next = pts[i + 1];
      final c = Offset((cur.dx + next.dx) / 2, cur.dy);
      final cn = Offset((cur.dx + next.dx) / 2, next.dy);
      path.cubicTo(c.dx, c.dy, cn.dx, cn.dy, next.dx, next.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
