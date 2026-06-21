class Member {
  final String id;
  final String name;
  final String role;
  final String? imageUrl;
  final DateTime createdAt;

  Member({
    required this.id,
    required this.name,
    required this.role,
    this.imageUrl,
    required this.createdAt,
  });
  factory Member.fromMap(String id, Map<dynamic, dynamic> map) {
    return Member(
      id: id,
      name: map['name'] ?? '',
      role: map['role'] ?? 'Household',
      imageUrl: map['imageUrl'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}
