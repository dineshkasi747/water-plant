import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = [];
  bool _localLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Form controllers for registering customer
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _areaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCustomers();
      _setupSocketSync();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  // Setup real-time Socket.IO synchronization listeners
  void _setupSocketSync() {
    final socketService = Provider.of<SocketService>(context, listen: false);
    
    // Bind customer updates event
    socketService.onCustomerUpdated((updatedCustomer) {
      if (!mounted) return;
      setState(() {
        int index = _customers.indexWhere((c) => c.id == updatedCustomer.id);
        if (index != -1) {
          _customers[index] = updatedCustomer;
        } else {
          // If a new customer was added by other user, insert it
          _customers.add(updatedCustomer);
          _customers.sort((a, b) => a.name.compareTo(b.name));
        }
      });
      // Trigger subtle snackbar to inform of live update
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ Sync: ${updatedCustomer.name} updated!'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    });

    // Bind customer deletion event
    socketService.onCustomerDeleted((deletedId) {
      if (!mounted) return;
      setState(() {
        _customers.removeWhere((c) => c.id == deletedId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚡ Sync: A customer profile was deleted.'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.redAccent,
        ),
      );
    });
  }

  // Retrieve customer directory
  Future<void> _fetchCustomers([String? query]) async {
    setState(() {
      _localLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final list = await apiService.getCustomers(search: query);
      setState(() {
        _customers = list;
        _localLoading = false;
      });
    } catch (e) {
      setState(() {
        _localLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading directory: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Submit request to register new customer
  Future<void> _submitAddCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context); // Close sheet
    setState(() {
      _localLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.addCustomer(
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _addressController.text.trim(),
        _areaController.text.trim(),
      );
      
      // Reset inputs
      _nameController.clear();
      _phoneController.clear();
      _addressController.clear();
      _areaController.clear();

      // Refresh list
      _fetchCustomers(_searchQuery);
    } catch (e) {
      setState(() {
        _localLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding customer: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Modern bottom sheet dialog to register customer
  void _openAddCustomerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '➕ Add New Customer',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 18),
                  
                  _buildInputField(_nameController, 'Customer Name', Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _buildInputField(_phoneController, 'Phone Number (Optional)', Icons.phone_android_rounded, keyboardType: TextInputType.phone, isRequired: false),
                  const SizedBox(height: 16),
                  _buildInputField(_areaController, 'Delivery Area (Optional, e.g. Doctor Colony)', Icons.location_on_outlined, isRequired: false),
                  const SizedBox(height: 16),
                  _buildInputField(_addressController, 'Full Address (Optional)', Icons.home_work_outlined, maxLines: 2, isRequired: false),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _submitAddCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4), // Cyan 500
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Customer',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xFF06B6D4)),
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 2),
        ),
      ),
      validator: isRequired 
          ? (value) => value == null || value.trim().isEmpty ? 'Required field' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final socketService = Provider.of<SocketService>(context);
    final user = apiService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate Navy
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Directory',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Logged in as: ${user?.name ?? 'User'}',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.wifi_tethering_rounded, 
              color: socketService.isConnected ? const Color(0xFF10B981) : Colors.redAccent
            ),
            tooltip: socketService.isConnected ? 'Live Sync Active' : 'Offline',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Logout',
            onPressed: () async {
              await apiService.logout();
              socketService.disconnect();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Search & Metrics Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1E293B),
            child: Column(
              children: [
                // Premium glass Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search by Name or Area...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF06B6D4)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white60),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _fetchCustomers('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      _fetchCustomers(value); // Live Search
                    },
                  ),
                ),
              ],
            ),
          ),

          // Customer Grid/List View
          Expanded(
            child: _localLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : _customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 70, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              'No customers found',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _fetchCustomers(_searchQuery),
                        color: const Color(0xFF06B6D4),
                        backgroundColor: const Color(0xFF1E293B),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _customers.length,
                          itemBuilder: (context, index) {
                            final customer = _customers[index];
                            final hasCans = customer.cansOut > 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF334155)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context, 
                                    '/customer-detail',
                                    arguments: customer,
                                  ).then((_) {
                                    // Refresh on back to get any new counts
                                    _fetchCustomers(_searchQuery);
                                  });
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Rounded Avatar with initials
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF334155)),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          customer.name.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF06B6D4), 
                                            fontSize: 20, 
                                            fontWeight: FontWeight.bold
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Meta text
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on_outlined, size: 13, color: Colors.white60),
                                                const SizedBox(width: 4),
                                                Text(
                                                  customer.area,
                                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Outstanding Cans Counter Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: hasCans
                                              ? const Color(0xFFF97316).withOpacity(0.15) // Deep Orange tint
                                              : const Color(0xFF10B981).withOpacity(0.15), // Emerald tint
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: hasCans 
                                                ? const Color(0xFFF97316).withOpacity(0.4) 
                                                : const Color(0xFF10B981).withOpacity(0.4)
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '${customer.cansOut}',
                                              style: TextStyle(
                                                color: hasCans ? const Color(0xFFFB923C) : const Color(0xFF34D399),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              'CANS',
                                              style: TextStyle(
                                                color: hasCans ? const Color(0xFFFB923C) : const Color(0xFF34D399),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E293B),
        elevation: 10,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.people_alt_rounded, color: Color(0xFF06B6D4), size: 28),
                tooltip: 'Customers',
                onPressed: () {}, // Already here
              ),
              const SizedBox(width: 40), // Space for floating button
              IconButton(
                icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.white60, size: 28),
                tooltip: 'Activity Logs',
                onPressed: () {
                  Navigator.pushNamed(context, '/activity-log');
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddCustomerSheet,
        backgroundColor: const Color(0xFF06B6D4), // Cyan 500
        elevation: 6,
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
