import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/activity_log_screen.dart';
import 'models/customer.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure Flutter engine bindings are initialized fully
  WidgetsFlutterBinding.ensureInitialized();

  // Try to initialize Firebase messaging. Gracefully catch if configuration files are not in place yet.
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase services initialized successfully.");
  } catch (e) {
    debugPrint("⚠️ Firebase.initializeApp() bypassed. Add google-services.json to test actual FCM background notifications: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: const AquaFlowApp(),
    ),
  );
}

class AquaFlowApp extends StatefulWidget {
  const AquaFlowApp({super.key});

  @override
  State<AquaFlowApp> createState() => _AquaFlowAppState();
}

class _AquaFlowAppState extends State<AquaFlowApp> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initializeBackgroundServices();
    }
  }

  // Orchestrate initialization of Socket.IO and FCM integration
  Future<void> _initializeBackgroundServices() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final socketService = Provider.of<SocketService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);

    // 1. Initialize FCM Notifications and register token sync callback
    await notificationService.init((token) {
      if (apiService.isAuthenticated) {
        apiService.syncFcmToken(token);
      }
    });

    // 2. Setup Socket sync if user is already logged in on startup
    if (apiService.isAuthenticated) {
      socketService.init(apiService.token!, apiService.baseUrl);
      
      // Auto sync FCM token now that we are authenticated
      if (notificationService.fcmToken != null) {
        apiService.syncFcmToken(notificationService.fcmToken!);
      }
    }

    // 3. Listen to authentication changes to open/close Socket connections instantly
    apiService.addListener(() {
      if (apiService.isAuthenticated) {
        if (!socketService.isConnected) {
          socketService.init(apiService.token!, apiService.baseUrl);
          if (notificationService.fcmToken != null) {
            apiService.syncFcmToken(notificationService.fcmToken!);
          }
        }
      } else {
        if (socketService.isConnected) {
          socketService.disconnect();
        }
        // Safely redirect to Login and clear route history if session invalidates
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AquaFlow Tracker',
      debugShowCheckedModeBanner: false,
      
      // Premium Sleek Dark Theme System
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF06B6D4), // Cyan 500
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate Navy
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF06B6D4),
          secondary: Color(0xFF0D9488), // Teal 600
          surface: Color(0xFF1E293B), // Slate Grey Card
          background: const Color(0xFF0F172A),
          error: Colors.redAccent,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          bodyLarge: TextStyle(letterSpacing: 0.2),
        ),
        cardTheme: CardTheme(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          centerTitle: false,
          elevation: 0,
        ),
      ),

      // Set initial loading state screen or route
      home: apiService.isAuthenticated ? const CustomersScreen() : const LoginScreen(),
      
      // Application Routing
      routes: {
        '/login': (context) => const LoginScreen(),
        '/customers': (context) => const CustomersScreen(),
        '/activity-log': (context) => const ActivityLogScreen(),
      },

      // Custom routing for parsing arguments cleanly
      onGenerateRoute: (settings) {
        if (settings.name == '/customer-detail') {
          final customer = settings.arguments as Customer;
          return MaterialPageRoute(
            builder: (context) => CustomerDetailScreen(customer: customer),
          );
        }
        return null;
      },
    );
  }
}
