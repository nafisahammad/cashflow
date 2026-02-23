class Tour {
  const Tour({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.inviteCode,
    required this.members,
  });

  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final String inviteCode;
  final List<String> members;

  Tour copyWith({
    String? id,
    String? name,
    String? createdBy,
    DateTime? createdAt,
    String? inviteCode,
    List<String>? members,
  }) {
    return Tour(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
    );
  }
}
