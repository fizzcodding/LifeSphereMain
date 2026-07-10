import 'package:flutter/material.dart';
import '../../models/member.dart';
import '../../services/members_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';
import '../../widgets/sidebar.dart';
import 'add_member_dialog.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _svc = MembersService();
  final _ipCtrl = TextEditingController();
  List<Member> _members = [];
  bool _loading = false;
  bool _ipSet = false;

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIp() async {
    final ip = await _svc.getSavedIp();
    if (ip == null || ip.isEmpty) return;
    setState(() { _ipCtrl.text = ip; _ipSet = true; });
    _fetch();
  }

  Future<void> _saveIp() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) { showErrorToast('Server IP cannot be empty.'); return; }
    await _svc.saveIp(ip);
    setState(() => _ipSet = true);
    showSuccessToast('Server IP saved.');
    _fetch();
  }

  Future<void> _fetch() async {
    if (!_ipSet) return;
    setState(() => _loading = true);
    try {
      final members = await _svc.getMembers();
      if (mounted) setState(() => _members = members);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAdd() async {
    final result = await showDialog<bool>(context: context, builder: (_) => const AddMemberDialog());
    if (result == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(),
        actions: const [AppUserAvatar()],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/members'),
      floatingActionButton: FloatingActionButton(
        onPressed: _ipSet ? _openAdd : null,
        backgroundColor: _ipSet ? AppTheme.primary : AppTheme.muted,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: _buildIpInput(),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty ? _buildEmpty() : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildIpInput() {
    return PremiumPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ipCtrl,
              decoration: const InputDecoration(
                labelText: 'Server IP Address',
                hintText: '192.168.0.105:5000',
                isDense: true,
              ),
              onChanged: (_) => setState(() => _ipSet = false),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: ElevatedButton(onPressed: _saveIp, child: const Text('Save')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: PremiumPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: 58,
                color: AppTheme.secondary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              Text(
                _ipSet ? 'No members added yet' : 'Server not configured',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final m = _members[index];
        return _MemberCard(
          member: m,
          onDelete: () async {
            final ok = await _svc.removeMember(m.id);
            ok ? showSuccessToast('Member removed.') : showErrorToast('Failed to remove member.');
            _fetch();
          },
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onDelete;

  const _MemberCard({required this.member, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                ),
                clipBehavior: Clip.antiAlias,
                child: member.imageUrl == null
                    ? const Icon(Icons.person_rounded, size: 42)
                    : Image.network(
                        member.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.person_rounded, size: 42),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                member.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _roleColor(member.role).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  member.role,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _roleColor(member.role),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
              onPressed: () => _confirmDelete(context),
            ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    return switch (role) {
      'Household' => AppTheme.primary,
      'Guest' => AppTheme.secondary,
      'Relative' => AppTheme.danger,
      _ => AppTheme.muted,
    };
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove ${member.name} from your household?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onDelete(); },
            child: const Text('Remove', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}
