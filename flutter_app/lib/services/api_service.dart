import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/customer.dart';
import '../models/transaction.dart';

class ApiService extends ChangeNotifier {
  // Base URL: configured for local Wi-Fi connection
  String _baseUrl = 'http://192.168.0.147:5000/api';
  
  String? _token;
  User? _currentUser;
  bool _isLoading = false;

  ApiService() {
    _loadAuthData();
  }

  // Getters
  String get baseUrl => _baseUrl;
  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;

  void setBaseUrl(String newUrl) {
    _baseUrl = newUrl;
    notifyListeners();
  }

  // Set loading state helper
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Load auth token and user profile on startup
  Future<void> _loadAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      try {
        _currentUser = User.fromJson(jsonDecode(userJson));
      } catch (e) {
        debugPrint('Failed to parse cached user: $e');
        _currentUser = null;
        _token = null;
      }
    }
    notifyListeners();
  }

  // HTTP Header generator
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Intercept 401 Unauthorized responses to logout instantly (e.g. login from another device)
  void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint('Unauthorized access detected (401). Invalidating session.');
      _token = null;
      _currentUser = null;
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('jwt_token');
        prefs.remove('current_user');
      });
      notifyListeners();
    }
  }

  // PIN-based user login
  Future<bool> login(String phone, String pin) async {
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'pin': pin}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _currentUser = User.fromJson(data['user']);

        // Persist local auth
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setString('current_user', jsonEncode(data['user']));

        _setLoading(false);
        return true;
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Login failed. Please check phone and PIN.');
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Synchronize FCM device registration token
  Future<void> syncFcmToken(String fcmToken) async {
    if (!isAuthenticated) return;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/fcm-token'),
        headers: _getHeaders(),
        body: jsonEncode({'fcmToken': fcmToken}),
      );
      _checkResponse(response);
      if (response.statusCode == 200) {
        debugPrint('FCM token updated successfully on backend.');
      }
    } catch (e) {
      debugPrint('Failed to sync FCM Token: $e');
    }
  }

  // Fetch all or search customers
  Future<List<Customer>> getCustomers({String? search}) async {
    try {
      String queryParam = search != null && search.isNotEmpty ? '?search=$search' : '';
      final response = await http.get(
        Uri.parse('$_baseUrl/customers$queryParam'),
        headers: _getHeaders(),
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((item) => Customer.fromJson(item)).toList();
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to load customers');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Register a new customer
  Future<Customer> addCustomer(String name, String phone, String address, String area) async {
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/customers'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'address': address,
          'area': area,
        }),
      );

      _setLoading(false);
      _checkResponse(response);
      if (response.statusCode == 201) {
        return Customer.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to register customer');
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Retrieve customer details and historical transactions
  Future<Map<String, dynamic>> getCustomerDetails(String customerId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/customers/$customerId'),
        headers: _getHeaders(),
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final customer = Customer.fromJson(data['customer']);
        
        List<dynamic> historyJson = data['history'] ?? [];
        final history = historyJson.map((tx) => Transaction.fromJson(tx)).toList();

        return {
          'customer': customer,
          'history': history,
        };
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to fetch customer details');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Dispatch a new transaction (gave or returned cans)
  Future<Transaction> createTransaction(String customerId, String type, int qty) async {
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions'),
        headers: _getHeaders(),
        body: jsonEncode({
          'customerId': customerId,
          'type': type,
          'qty': qty,
        }),
      );

      _setLoading(false);
      _checkResponse(response);
      if (response.statusCode == 201) {
        return Transaction.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to post transaction');
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Get global transactions log history
  Future<List<Transaction>> getGlobalTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions'),
        headers: _getHeaders(),
      );

      _checkResponse(response);
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((tx) => Transaction.fromJson(tx)).toList();
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to load transaction history');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Edit customer details
  Future<Customer> editCustomer(String id, String name, String phone, String address, String area) async {
    _setLoading(true);
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/customers/$id'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'address': address,
          'area': area,
        }),
      );

      _setLoading(false);
      _checkResponse(response);
      if (response.statusCode == 200) {
        return Customer.fromJson(jsonDecode(response.body));
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to update customer details');
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Delete customer and their log history
  Future<void> deleteCustomer(String id) async {
    _setLoading(true);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/customers/$id'),
        headers: _getHeaders(),
      );

      _setLoading(false);
      _checkResponse(response);
      if (response.statusCode != 200) {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to delete customer');
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Delete/revert a transaction log entry
  Future<void> deleteTransaction(String id) async {
    _setLoading(true);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/transactions/$id'),
        headers: _getHeaders(),
      );

      _setLoading(false);
      _checkResponse(response);
      if (response.statusCode != 200) {
        final err = jsonDecode(response.body);
        throw Exception(err['message'] ?? 'Failed to revert transaction');
      }
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
  }

  // Clears credentials on user logout
  Future<void> logout() async {
    _setLoading(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('current_user');
    
    _token = null;
    _currentUser = null;
    _setLoading(false);
  }
}
