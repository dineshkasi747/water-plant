import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/transaction.dart';
import '../models/customer.dart';

class SocketService extends ChangeNotifier {
  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Initialize socket.io connection
  void init(String token, String baseUrl) {
    // Strip '/api' from baseUrl if present to connect to socket root
    String socketUrl = baseUrl.endsWith('/api') 
        ? baseUrl.substring(0, baseUrl.length - 4) 
        : baseUrl;

    if (_socket != null) {
      _socket!.disconnect();
    }

    debugPrint('Connecting to Socket.IO at: $socketUrl');

    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // websocket preferred
      .disableAutoConnect()
      .setAuth({
        'token': token // optional JWT auth if backend validates handshake
      })
      .build()
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('⚡ Socket.IO Connected successfully.');
      notifyListeners();
      
      // Explicitly join room
      _socket!.emit('join', 'water-plant-room');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('⚡ Socket.IO Disconnected.');
      notifyListeners();
    });

    _socket!.onConnectError((err) {
      debugPrint('⚡ Socket.IO Connection Error: $err');
    });

    _socket!.connect();
  }

  // Subscribe to new transaction events
  void onTransactionCreated(Function(Transaction) onCreated) {
    if (_socket == null) return;
    _socket!.on('transaction_created', (data) {
      debugPrint('⚡ Socket transaction_created event received: $data');
      try {
        final transaction = Transaction.fromJson(data);
        onCreated(transaction);
      } catch (e) {
        debugPrint('Error parsing Socket transaction data: $e');
      }
    });
  }

  // Subscribe to customer balance count update events
  void onCustomerUpdated(Function(Customer) onUpdated) {
    if (_socket == null) return;
    _socket!.on('customer_updated', (data) {
      debugPrint('⚡ Socket customer_updated event received: $data');
      try {
        final customer = Customer.fromJson(data);
        onUpdated(customer);
      } catch (e) {
        debugPrint('Error parsing Socket customer data: $e');
      }
    });
  }

  // Subscribe to customer deletion events
  void onCustomerDeleted(Function(String) onDeleted) {
    if (_socket == null) return;
    _socket!.on('customer_deleted', (id) {
      debugPrint('⚡ Socket customer_deleted event received for ID: $id');
      onDeleted(id.toString());
    });
  }

  // Subscribe to transaction deletion/reversion events
  void onTransactionDeleted(Function(String) onDeleted) {
    if (_socket == null) return;
    _socket!.on('transaction_deleted', (id) {
      debugPrint('⚡ Socket transaction_deleted event received for ID: $id');
      onDeleted(id.toString());
    });
  }

  // Disconnect active socket session
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
