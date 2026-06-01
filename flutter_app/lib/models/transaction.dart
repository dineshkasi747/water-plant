import 'user.dart';

class Transaction {
  final String id;
  final String customerId;
  final String customerName; // Handy for flat list representation
  final String type; // 'gave' | 'returned'
  final int qty;
  final User? by;
  final DateTime timestamp;
  final bool returned;

  Transaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.type,
    required this.qty,
    this.by,
    required this.timestamp,
    required this.returned,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Determine customer ID and name based on whether customerId is populated
    String parsedCustomerId = '';
    String parsedCustomerName = '';
    
    if (json['customerId'] != null) {
      if (json['customerId'] is Map) {
        parsedCustomerId = json['customerId']['_id'] ?? json['customerId']['id'] ?? '';
        parsedCustomerName = json['customerId']['name'] ?? '';
      } else {
        parsedCustomerId = json['customerId'].toString();
        parsedCustomerName = 'Customer';
      }
    }

    // Handled populated User in 'by' field
    User? parsedBy;
    if (json['by'] != null) {
      if (json['by'] is Map) {
        parsedBy = User.fromJson(json['by']);
      } else {
        parsedBy = User(id: json['by'].toString(), name: 'User', phone: '');
      }
    }

    return Transaction(
      id: json['id'] ?? json['_id'] ?? '',
      customerId: parsedCustomerId,
      customerName: parsedCustomerName,
      type: json['type'] ?? 'gave',
      qty: json['qty'] is int ? json['qty'] : (json['qty'] as num?)?.toInt() ?? 0,
      by: parsedBy,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']).toLocal() 
          : DateTime.now(),
      returned: json['returned'] ?? false,
    );
  }
}
