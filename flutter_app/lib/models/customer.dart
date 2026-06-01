class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String area;
  final int cansOut;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.area,
    required this.cansOut,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      cansOut: json['cansOut'] is int ? json['cansOut'] : (json['cansOut'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'area': area,
      'cansOut': cansOut,
    };
  }

  // Helper method to create a copy of Customer with updated cans count
  Customer copyWith({int? cansOut}) {
    return Customer(
      id: id,
      name: name,
      phone: phone,
      address: address,
      area: area,
      cansOut: cansOut ?? this.cansOut,
    );
  }
}
