import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '9876543210'); // Pre-fill Dad's for convenience
  String _pin = '';
  String _errorMessage = '';

  void _handleNumberPress(String number) {
    if (_pin.length < 4) {
      setState(() {
        _pin += number;
        _errorMessage = '';
      });
      if (_pin.length == 4) {
        _submitLogin();
      }
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _handleClear() {
    setState(() {
      _pin = '';
      _errorMessage = '';
    });
  }

  Future<void> _submitLogin() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter phone number';
        _pin = '';
      });
      return;
    }

    try {
      final success = await apiService.login(
        _phoneController.text.trim(),
        _pin,
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/customers');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _pin = ''; // Reset PIN on failure
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep Slate Navy
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Premium branding icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    size: 60,
                    color: Color(0xFF06B6D4), // Cyan 500
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AquaFlow Tracker',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Water Plant Distribution Tracking',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),

                // Phone Input Field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _phoneController,
                    style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 1.0),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: const Icon(Icons.phone_rounded, color: Color(0xFF06B6D4)),
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      hintText: 'Enter 10 digit number',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                ),

                const SizedBox(height: 36),
                
                // PIN dots indicator
                Text(
                  'Enter 4-Digit Security PIN',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = _pin.length > index;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? const Color(0xFF06B6D4) : Colors.transparent,
                        border: Border.all(
                          color: isFilled ? const Color(0xFF06B6D4) : const Color(0xFF475569),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF06B6D4).withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 20),

                // Error Message Display
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 10),

                if (apiService.isLoading)
                  const CircularProgressIndicator(color: Color(0xFF06B6D4))
                else ...[
                  // Premium Virtual Numeric Keypad
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 24,
                        childAspectRatio: 1.3,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        // Layout: 
                        // 1 2 3
                        // 4 5 6
                        // 7 8 9
                        // C 0 Backspace
                        if (index < 9) {
                          String num = (index + 1).toString();
                          return _buildKeypadButton(num, () => _handleNumberPress(num));
                        } else if (index == 9) {
                          return _buildKeypadButton('C', _handleClear, isAction: true);
                        } else if (index == 10) {
                          return _buildKeypadButton('0', () => _handleNumberPress('0'));
                        } else {
                          return _buildKeypadIcon(Icons.backspace_outlined, _handleBackspace);
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String text, VoidCallback onPressed, {bool isAction = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isAction ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isAction ? Colors.redAccent.shade100 : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadIcon(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.7),
          size: 24,
        ),
      ),
    );
  }
}
