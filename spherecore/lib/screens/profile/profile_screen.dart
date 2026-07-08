import 'package:flutter/material.dart';
import '../../services/health_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phonetagController = TextEditingController();
  final _healthService = HealthService();
  DateTime? _selectedDate;
  int? _age;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phonetagController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _healthService.getUserProfile();
    if (profile != null) {
      _nameController.text = profile['name'] ?? '';
      _phonetagController.text = profile['phonetag'] ?? '';
      final birthDate = profile['birthDate'];
      if (birthDate != null) {
        _selectedDate = DateTime.parse(birthDate);
        _age = _calculateAge(_selectedDate!);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  int _calculateAge(DateTime date) {
    final now = DateTime.now();
    var age = now.year - date.year;
    if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
      age--;
    }
    return age;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || picked == _selectedDate) return;
    setState(() {
      _selectedDate = picked;
      _age = _calculateAge(picked);
    });
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and birth date')),
      );
      return;
    }
    await _healthService.updateProfile(
      _nameController.text.trim(),
      _selectedDate!.toIso8601String(),
      _phonetagController.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phonetagController,
                        decoration: const InputDecoration(
                          labelText: 'Phonetag',
                          hintText: 'Enter BLE UUID',
                          prefixIcon: Icon(Icons.bluetooth_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDate,
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
                                  _selectedDate == null
                                      ? 'Select Birth Date'
                                      : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
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
                        onPressed: _saveProfile,
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
