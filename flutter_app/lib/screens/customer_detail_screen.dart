import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _customer;
  List<Transaction> _history = [];
  bool _isLoading = false;
  final TextEditingController _qtyController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCustomerDetails();
      _setupSocketSync();
    });
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  // Setup real-time Socket.IO synchronization listeners
  void _setupSocketSync() {
    final socketService = Provider.of<SocketService>(context, listen: false);

    // Listen for customer count changes
    socketService.onCustomerUpdated((updatedCustomer) {
      if (!mounted) return;
      if (updatedCustomer.id == _customer.id) {
        setState(() {
          _customer = updatedCustomer;
        });
      }
    });

    // Listen for new transactions
    socketService.onTransactionCreated((newTx) {
      if (!mounted) return;
      if (newTx.customerId == _customer.id) {
        setState(() {
          // If transaction doesn't exist, insert at the beginning
          if (!_history.any((tx) => tx.id == newTx.id)) {
            _history.insert(0, newTx);
          }
        });
      }
    });

    // Listen for deleted/reverted transactions
    socketService.onTransactionDeleted((deletedId) {
      if (!mounted) return;
      setState(() {
        _history.removeWhere((tx) => tx.id == deletedId);
      });
    });
  }

  // Retrieve customer details and transaction log history
  Future<void> _fetchCustomerDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final details = await apiService.getCustomerDetails(_customer.id);
      
      setState(() {
        _customer = details['customer'];
        _history = details['history'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile details: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Record a give/return transaction
  Future<void> _submitTransaction(String type) async {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be 1 or more'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // Safety check: Cannot return more empty cans than they have outstanding!
    if (type == 'returned' && qty > _customer.cansOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Customer only has ${_customer.cansOut} outstanding cans! Cannot return $qty.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pop(context); // Dismiss dialog
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final tx = await apiService.createTransaction(_customer.id, type, qty);
      
      // Local reactive update
      setState(() {
        final socketService = Provider.of<SocketService>(context, listen: false);
        if (!socketService.isConnected) {
          if (!_history.any((item) => item.id == tx.id)) {
            _history.insert(0, tx);
          }
          
          // Recalculate local customer cansOut count
          int updatedCount = _customer.cansOut;
          if (type == 'gave') {
            updatedCount += qty;
          } else {
            updatedCount = (updatedCount - qty).clamp(0, 9999);
          }
          _customer = _customer.copyWith(cansOut: updatedCount);
        }
        
        _qtyController.text = '1'; // Reset
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Success: Recorded $qty can(s) ${type == 'gave' ? 'delivered' : 'returned'}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log event: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Show dialog to input quantity for transaction
  void _showTransactionDialog(String type) {
    _qtyController.text = '1'; // Default
    final isGive = type == 'gave';
    
    // Safety check: Cannot return empty cans if outstanding is 0!
    if (!isGive && _customer.cansOut == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Customer has 0 outstanding cans! Cannot return empty cans.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isGive ? '🪣 Deliver Cans' : '🔄 Return Cans',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGive ? 'How many cans are you giving?' : 'How many empty cans did they return?',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _qtyController,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '1',
                    hintStyle: TextStyle(color: Colors.white24),
                    suffixText: 'Cans',
                    suffixStyle: TextStyle(color: Color(0xFF06B6D4)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => _submitTransaction(type),
              style: ElevatedButton.styleFrom(
                backgroundColor: isGive ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                isGive ? 'Deliver' : 'Return',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show modal bottom sheet to edit customer details
  void _showEditCustomerSheet() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: _customer.name);
    final phoneCtrl = TextEditingController(text: _customer.phone);
    final addressCtrl = TextEditingController(text: _customer.address);
    final areaCtrl = TextEditingController(text: _customer.area);

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
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '✏️ Edit Customer Profile',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 18),
                  
                  _buildInputField(nameCtrl, 'Customer Name', Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                  _buildInputField(phoneCtrl, 'Phone Number (Optional)', Icons.phone_android_rounded, keyboardType: TextInputType.phone, isRequired: false),
                  const SizedBox(height: 16),
                  _buildInputField(areaCtrl, 'Delivery Area (Optional, e.g. Doctor Colony)', Icons.location_on_outlined, isRequired: false),
                  const SizedBox(height: 16),
                  _buildInputField(addressCtrl, 'Full Address (Optional)', Icons.home_work_outlined, maxLines: 2, isRequired: false),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(context); // Close sheet
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        final apiService = Provider.of<ApiService>(context, listen: false);
                        final updated = await apiService.editCustomer(
                          _customer.id,
                          nameCtrl.text.trim(),
                          phoneCtrl.text.trim(),
                          addressCtrl.text.trim(),
                          areaCtrl.text.trim(),
                        );
                        setState(() {
                          _customer = updated;
                          _isLoading = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile details updated successfully!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          _isLoading = false;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4), // Cyan 500
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Save Changes',
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
    ).then((_) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      addressCtrl.dispose();
      areaCtrl.dispose();
    });
  }

  // Input field helper for dialog sheet
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

  // Confirmation alert before deleting customer
  void _confirmDeleteCustomer() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '⚠️ Delete Customer Profile?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you absolutely sure you want to delete ${_customer.name}? This will permanently delete their profile and all historic transaction logs. This action cannot be undone.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Dismiss dialog
                setState(() {
                  _isLoading = true;
                });

                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  await apiService.deleteCustomer(_customer.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Customer ${_customer.name} and all data has been permanently purged.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    Navigator.pop(context); // Pop back to list screen!
                  }
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deletion failed: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Delete Purge',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Revert and delete transaction alert dialog
  void _confirmDeleteTransaction(Transaction tx) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '🔄 Revert Transaction Entry?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This will permanently delete this transaction entry and revert its quantity (${tx.qty} cans) from the customer\'s outstanding balance. Are you sure?',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Dismiss dialog
                setState(() {
                  _isLoading = true;
                });

                try {
                  final apiService = Provider.of<ApiService>(context, listen: false);
                  await apiService.deleteTransaction(tx.id);
                  
                  // Local state correction
                  setState(() {
                    final socketService = Provider.of<SocketService>(context, listen: false);
                    if (!socketService.isConnected) {
                      _history.removeWhere((item) => item.id == tx.id);
                      
                      int updatedCount = _customer.cansOut;
                      if (tx.type == 'gave') {
                        updatedCount = (updatedCount - tx.qty).clamp(0, 9999);
                      } else {
                        updatedCount += tx.qty;
                      }
                      _customer = _customer.copyWith(cansOut: updatedCount);
                    }
                    _isLoading = false;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction successfully reverted and corrected!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  setState(() {
                    _isLoading = false;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reversion failed: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316), // Orange
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Revert & Correct',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final hasCans = _customer.cansOut > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(_customer.name, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF06B6D4)),
            tooltip: 'Edit Profile',
            onPressed: _showEditCustomerSheet,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            tooltip: 'Delete Profile',
            onPressed: _confirmDeleteCustomer,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _fetchCustomerDetails,
          )
        ],
      ),
      body: _isLoading && _history.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
          : Column(
              children: [
                // Top Customer Summary Header Card
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    children: [
                      // Cans counter display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: hasCans
                              ? const Color(0xFFF97316).withOpacity(0.12)
                              : const Color(0xFF10B981).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: hasCans
                                ? const Color(0xFFF97316).withOpacity(0.3)
                                : const Color(0xFF10B981).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${_customer.cansOut}',
                              style: TextStyle(
                                color: hasCans ? const Color(0xFFFB923C) : const Color(0xFF34D399),
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'OUTSTANDING CANS',
                              style: TextStyle(
                                color: hasCans ? const Color(0xFFFB923C) : const Color(0xFF34D399),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Customer Metadata Block
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 6),
                              Text(
                                _customer.phone,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${_customer.address} (${_customer.area})',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showTransactionDialog('gave'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4), // Cyan 500
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                              label: const Text('Give Can', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showTransactionDialog('returned'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), // Emerald 500
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                              label: const Text('Return Can', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // History label
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: const Color(0xFF0F172A),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TRANSACTION HISTORY',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.8
                    ),
                  ),
                ),

                // List of past Transactions
                Expanded(
                  child: _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_edu_rounded, size: 50, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 12),
                              Text(
                                'No transactions yet',
                                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            final tx = _history[index];
                            final isGive = tx.type == 'gave';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                children: [
                                  // Mini Icon status
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isGive
                                          ? const Color(0xFF06B6D4).withOpacity(0.12)
                                          : const Color(0xFF10B981).withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isGive ? Icons.outbox_rounded : Icons.move_to_inbox_rounded,
                                      color: isGive ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Transaction Details text
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isGive ? 'Delivered ${tx.qty} Cans' : 'Returned ${tx.qty} Cans',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Recorded by: ${tx.by?.name ?? 'Unknown'}',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Timestamp & Actions
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        dateFormat.format(tx.timestamp),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.3),
                                          fontSize: 11,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      const SizedBox(height: 4),
                                      IconButton(
                                        icon: const Icon(Icons.undo_rounded, size: 18, color: Colors.white54),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Revert transaction',
                                        onPressed: () => _confirmDeleteTransaction(tx),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
