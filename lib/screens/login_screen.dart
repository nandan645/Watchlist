import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/server_settings_dialog.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final StorageService _storageService = StorageService();
  String _error = '';
  String _successMessage = '';
  bool _isSignUp = false;
  bool _isLoading = false;

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Email and password fields are required';
        _successMessage = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _successMessage = '';
    });

    final String? errorMessage = _isSignUp
        ? await _storageService.signUp(email, password)
        : await _storageService.checkLogin(email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (errorMessage == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else if (_isSignUp && errorMessage.startsWith('Signup successful!')) {
        setState(() {
          _successMessage = errorMessage;
        });
      } else {
        setState(() {
          _error = errorMessage;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF18212F);
    final mutedTextColor = isDark ? const Color(0xFF888888) : const Color(0xFF5A6474);
    final cardBgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final cardBorderColor = isDark ? const Color(0xFF242424) : const Color(0xFFDBE3F1);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(Icons.settings_rounded, color: mutedTextColor),
                  tooltip: 'Supabase Settings',
                  onPressed: () => showSupabaseSettingsDialog(context, () {
                    setState(() {});
                  }),
                ),
              ),
            ),
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      border: Border.all(color: cardBorderColor),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.transparent
                              : const Color(0xFF18212F).withValues(alpha: 0.08),
                          blurRadius: 34,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'Create Watchlist Account' : 'Watchlist Login',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isSignUp
                              ? 'Sign up with email and password to begin'
                              : 'Enter email and password to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: primaryTextColor),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE3E7EE)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE3E7EE)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: primaryTextColor),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE3E7EE)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE3E7EE)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          ),
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8E8),
                              border: Border.all(color: const Color(0xFFF0C6C6)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _error,
                              style: const TextStyle(
                                color: Color(0xFFC73535),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                        if (_successMessage.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              border: Border.all(color: const Color(0xFFA5D6A7)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _successMessage,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: Text(
                            _isLoading
                                ? 'Loading...'
                                : (_isSignUp ? 'Sign Up' : 'Enter'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = '';
                                    _successMessage = '';
                                  });
                                },
                          child: Text(
                            _isSignUp
                                ? 'Already have an account? Sign In'
                                : "Don't have an account? Sign Up",
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
