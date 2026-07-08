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
  final _membersService = MembersService();
  final _ipController = TextEditingController();
  List<Member> _members = [];
  bool _isLoading = false;
  bool _isIpSet = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedIp() async {
    final ip = await _membersService.getSavedIp();
    if (ip == null || ip.isEmpty) return;
    setState(() {
      _ipController.text = ip;
      _isIpSet = true;
    });
    _fetchMembers();
  }

  Future<void> _saveIp() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      showErrorToast('Server IP cannot be empty.');
      return;
    }
    await _membersService.saveIp(ip);
    setState(() => _isIpSet = true);
    showSuccessToast('Server IP saved.');
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    if (!_isIpSet) return;
    setState(() => _isLoading = true);
    try {
      final members = await _membersService.getMembers();
      if (mounted) setState(() => _members = members);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openAddMember() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddMemberDialog(),
    );
    if (result == true) _fetchMembers();
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
        onPressed: _isIpSet ? _openAddMember : null,
        backgroundColor: _isIpSet ? AppTheme.primary : AppTheme.muted,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: _buildIpInput(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? _buildEmptyState()
                    : _buildMembersGrid(),
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
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Server IP Address',
                hintText: '192.168.0.105:5000',
                isDense: true,
              ),
              onChanged: (_) {
                if (_isIpSet) setState(() => _isIpSet = false);
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: ElevatedButton(
              onPressed: _saveIp,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                _isIpSet ? 'No members added yet' : 'Server not configured',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersGrid() {
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
        final member = _members[index];
        return _MemberCard(
          member: member,
          onDelete: () async {
            final success = await _membersService.removeMember(member.id);
            if (success) {
              showSuccessToast('Member removed.');
              _fetchMembers();
            } else {
              showErrorToast('Failed to remove member.');
            }
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
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person_rounded, size: 42),
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
              onPressed: () => _showDeleteConfirm(context),
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

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Remove ${member.name} from your household?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onDelete();
            },
            child: const Text('Remove', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}
