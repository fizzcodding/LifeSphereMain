import 'package:flutter/material.dart';
import '../../services/health_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';
import '../../widgets/sidebar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _svc = HealthService();
  DateTime? _birthDate;
  int? _age;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _svc.getUserProfile();
    if (profile != null) {
      _nameCtrl.text = profile['name'] ?? '';
      _phoneCtrl.text = profile['phonetag'] ?? '';
      final bd = profile['birthDate'];
      if (bd != null) {
        _birthDate = DateTime.parse(bd);
        _age = _calcAge(_birthDate!);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  int _calcAge(DateTime date) {
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) age--;
    return age;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || picked == _birthDate) return;
    setState(() { _birthDate = picked; _age = _calcAge(picked); });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _birthDate == null) {
      showErrorToast('Please enter name and birth date');
      return;
    }
    await _svc.updateProfile(
      _nameCtrl.text.trim(),
      _birthDate!.toIso8601String(),
      _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    showSuccessToast('Profile saved.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const AppLogoTitle()),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/logo_text.png', height: 104),
                const SizedBox(height: 24),
                PremiumPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Profile', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phonetag',
                          hintText: 'Enter BLE UUID',
                          prefixIcon: Icon(Icons.bluetooth_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            border: Border.all(color: AppTheme.border),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _birthDate == null
                                      ? 'Select Birth Date'
                                      : '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              if (_age != null)
                                Text(
                                  'Age $_age',
                                  style: const TextStyle(
                                    color: AppTheme.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Profile'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
