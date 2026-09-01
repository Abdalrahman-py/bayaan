class Account {
  final String id;
  final String name;
  final String email;
  final String? avatarPath;

  const Account({
    required this.id,
    required this.name,
    this.email = '',
    this.avatarPath,
  });

  Account copyWith({
    String? name,
    String? email,
    String? avatarPath,
    bool clearAvatar = false,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarPath': avatarPath,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String? ?? '1',
    name: json['name'] as String? ?? 'Learner',
    email: json['email'] as String? ?? '',
    avatarPath: json['avatarPath'] as String?,
  );
}
