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
  final _healthService = HealthService();
  final Map<String, TextEditingController> _dietControllers = {
    'breakfast': TextEditingController(),
    'lunch': TextEditingController(),
    'dinner': TextEditingController(),
  };
  bool _isGeneratingAI = false;

  @override
  void dispose() {
    for (final controller in _dietControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: const [AppUserAvatar()],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/vital32'),
      body: StreamBuilder(
        stream: _healthService.vitalsStream(),
        builder: (context, snapshot) {
          final data = _asMap(snapshot.data?.snapshot.value);
          final steps = _currentValue(data, 'steps');
          final hydration = _currentValue(data, 'hydration');
          final hr = _currentValue(data, 'hr');
          final spo2 = _currentValue(data, 'spo2');
          final temp = _currentValue(data, 'temp');
          final tips = _asMap(data['aiSuggestions']);
          final diet = _asMap(data['diet']);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 18),
                _buildVitalsPanel(hr, spo2, temp.toDouble()),
                const SizedBox(height: 18),
                _buildTrendChart(hr, spo2, hydration),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Step Count',
                        steps.toString(),
                        Icons.directions_walk_rounded,
                        AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatCard(
                        'Hydration',
                        '$hydration ml',
                        Icons.water_drop_rounded,
                        AppTheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildHydrationControls(hydration),
                const SizedBox(height: 22),
                _buildAISuggestions(tips),
                const SizedBox(height: 22),
                _buildDietSection(diet),
              ],
            ),
          );
        },
      ),
    );
  }

  Map _asMap(Object? value) {
    if (value is Map) return value;
    if (value is List) return value.asMap();
    return {};
  }

  int _currentValue(Map data, String key) {
    final value = data[key];
    if (value is Map && value['currently'] is num) {
      return (value['currently'] as num).toInt();
    }
    return 0;
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vital32', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 4),
        Text(
          '${now.day} ${_month(now.month)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  Widget _buildVitalsPanel(int hr, int spo2, double temp) {
    return PremiumPanel(
      child: Row(
        children: [
          SizedBox(
            width: 138,
            height: 138,
            child: Stack(
              children: [
                _Ring(
                  progress: hr / 200,
                  color: AppTheme.danger,
                  strokeWidth: 12,
                  radius: 60,
                ),
                _Ring(
                  progress: spo2 / 100,
                  color: AppTheme.secondary,
                  strokeWidth: 12,
                  radius: 45,
                ),
                _Ring(
                  progress: (temp - 30) / 10,
                  color: AppTheme.primary,
                  strokeWidth: 12,
                  radius: 30,
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRingLabel('Heart Rate', '$hr BPM', AppTheme.danger),
                _buildRingLabel('SpO2', '$spo2%', AppTheme.secondary),
                _buildRingLabel(
                  'Temperature',
                  '${temp.toStringAsFixed(1)} C',
                  AppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingLabel(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(int hr, int spo2, int hydration) {
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
            style: const TextStyle(
              color: AppTheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<double> _trend(int base, int spread) {
    return List.generate(8, (index) {
      final wave = math.sin(index * 0.85) * spread;
      return (base + wave).toDouble();
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildHydrationControls(int current) {
    return PremiumPanel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hydration Tracker', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '$current / 2500 ml today',
                  style: const TextStyle(color: AppTheme.secondary),
                ),
              ],
            ),
          ),
          _roundButton(
            Icons.remove_rounded,
            () => _healthService.updateHydration(-250),
          ),
          const SizedBox(width: 12),
          _roundButton(
            Icons.add_rounded,
            () => _healthService.updateHydration(250),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
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

  Widget _buildAISuggestions(Map tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('AI Insights', style: Theme.of(context).textTheme.titleLarge),
            ),
            _isGeneratingAI
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () async {
                      setState(() => _isGeneratingAI = true);
                      await _healthService.generateAISuggestions();
                      if (mounted) setState(() => _isGeneratingAI = false);
                    },
                  ),
          ],
        ),
        const SizedBox(height: 10),
        if (tips.isEmpty)
          PremiumPanel(
            child: Text(
              'No insights yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...tips.values.map(
            (tip) => Padding(
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
            ),
          ),
      ],
    );
  }

  Widget _buildDietSection(Map diet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Diet Planner', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _buildMealTile('breakfast', Icons.wb_sunny_rounded, diet['breakfast'] ?? []),
        _buildMealTile('lunch', Icons.sunny, diet['lunch'] ?? []),
        _buildMealTile('dinner', Icons.nightlight_round, diet['dinner'] ?? []),
      ],
    );
  }

  Widget _buildMealTile(String title, IconData icon, List items) {
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
                      controller: _dietControllers[title],
                      decoration: const InputDecoration(
                        hintText: 'Add food item',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded, color: AppTheme.secondary),
                    onPressed: () {
                      final controller = _dietControllers[title];
                      final value = controller?.text.trim();
                      if (controller == null || value == null || value.isEmpty) return;
                      _healthService.addDietItem(title, value);
                      controller.clear();
                    },
                  ),
                ],
              ),
            ),
            ...items.asMap().entries.map(
              (entry) => ListTile(
                title: Text(entry.value.toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                  onPressed: () => _healthService.removeDietItem(title, entry.key),
                ),
              ),
            ),
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
          progress: progress,
          color: color,
          strokeWidth: strokeWidth,
          radius: radius,
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
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LineChartPainter extends CustomPainter {
  final List<double> primaryValues;
  final List<double> secondaryValues;

  _LineChartPainter({
    required this.primaryValues,
    required this.secondaryValues,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    _drawLine(canvas, size, primaryValues, AppTheme.primary);
    _drawLine(canvas, size, secondaryValues, AppTheme.secondary);
  }

  void _drawLine(Canvas canvas, Size size, List<double> values, Color color) {
    final minValue = values.reduce((a, b) => math.min(a, b).toDouble());
    final maxValue = values.reduce((a, b) => math.max(a, b).toDouble());
    final range = math.max(1.0, maxValue - minValue).toDouble();
    final points = List.generate(values.length, (index) {
      final x = size.width * index / (values.length - 1);
      final y = size.height - ((values[index] - minValue) / range * size.height);
      return Offset(x, y);
    });

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      final control = Offset((current.dx + next.dx) / 2, current.dy);
      final controlNext = Offset((current.dx + next.dx) / 2, next.dy);
      path.cubicTo(control.dx, control.dy, controlNext.dx, controlNext.dy, next.dx, next.dy);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
