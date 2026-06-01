class User {
  final String id;
  final String name;
  final String phone;
  final String? fcmToken;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.fcmToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      fcmToken: json['fcmToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'fcmToken': fcmToken,
    };
  }
}
