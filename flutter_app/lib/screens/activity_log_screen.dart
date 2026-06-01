import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTransactions();
      _setupSocketSync();
    });
  }

  // Setup real-time Socket.IO synchronization listeners
  void _setupSocketSync() {
    final socketService = Provider.of<SocketService>(context, listen: false);

    // Live update when a new transaction is made by either user
    socketService.onTransactionCreated((newTx) {
      if (!mounted) return;
      setState(() {
        if (!_transactions.any((tx) => tx.id == newTx.id)) {
          _transactions.insert(0, newTx);
        }
      });
    });
  }

  // Retrieve global transaction log list
  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final list = await apiService.getGlobalTransactions();
      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load activity logs: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final socketService = Provider.of<SocketService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Global Activity Logs',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.wifi_tethering_rounded, 
              color: socketService.isConnected ? const Color(0xFF10B981) : Colors.redAccent
            ),
            tooltip: socketService.isConnected ? 'Real-time Connected' : 'Offline',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh logs',
            onPressed: _fetchTransactions,
          )
        ],
      ),
      body: Column(
        children: [
          // Brief stats strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: const Color(0xFF1E293B).withOpacity(0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  'Total Actions: ${_transactions.length}',
                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Main log list
          Expanded(
            child: _isLoading && _transactions.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 70, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions recorded in system',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchTransactions,
                        color: const Color(0xFF06B6D4),
                        backgroundColor: const Color(0xFF1E293B),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final tx = _transactions[index];
                            final isGive = tx.type == 'gave';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF334155)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Row(
                                  children: [
                                    // Visual status circle indicator
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isGive
                                            ? const Color(0xFF06B6D4).withOpacity(0.12)
                                            : const Color(0xFF10B981).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isGive ? Icons.outbox_rounded : Icons.move_to_inbox_rounded,
                                        color: isGive ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Content details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.customerName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          RichText(
                                            text: TextSpan(
                                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                              children: [
                                                TextSpan(
                                                  text: '${tx.by?.name ?? 'User'} ',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                                                ),
                                                TextSpan(
                                                  text: isGive ? 'gave ' : 'received ',
                                                ),
                                                TextSpan(
                                                  text: '${tx.qty} can(s)',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: isGive ? const Color(0xFF06B6D4) : const Color(0xFF10B981)
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dateFormat.format(tx.timestamp),
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                icon: const Icon(Icons.people_alt_rounded, color: Colors.white60, size: 28),
                tooltip: 'Customers',
                onPressed: () {
                  Navigator.pop(context); // Go back to customers list
                },
              ),
              const SizedBox(width: 40), // Space for floating button placeholder
              IconButton(
                icon: const Icon(Icons.history_toggle_off_rounded, color: Color(0xFF06B6D4), size: 28),
                tooltip: 'Activity Logs',
                onPressed: () {}, // Already here
              ),
            ],
          ),
        ),
      ),
    );
  }
}
