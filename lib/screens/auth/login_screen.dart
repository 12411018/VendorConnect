import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vendorlink/screens/auth/signup_screen.dart';
import 'package:vendorlink/screens/retailer/retailer_dashboard.dart';
import 'package:vendorlink/screens/wholesaler/tabs/wholesaler_home.dart';
import 'package:vendorlink/services/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _retryAfterSeconds = 0;
  Timer? _retryTimer;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _retryTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startRetryCooldown(int seconds) {
    _retryTimer?.cancel();
    setState(() {
      _retryAfterSeconds = seconds;
    });

    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_retryAfterSeconds <= 1) {
        timer.cancel();
        setState(() {
          _retryAfterSeconds = 0;
        });
      } else {
        setState(() {
          _retryAfterSeconds -= 1;
        });
      }
    });
  }

  bool _isRateLimitMessage(String message) {
    final text = message.toLowerCase();
    return text.contains('rate limit') ||
        text.contains('too many requests') ||
        text.contains('over_email_send_rate_limit');
  }

  int _retrySecondsFromMessage(String message) {
    final match = RegExp(
      r'(\d+)\s*seconds?',
      caseSensitive: false,
    ).firstMatch(message);
    if (match == null) {
      return 60;
    }

    return int.tryParse(match.group(1) ?? '') ?? 60;
  }

  Future<String?> _askRoleForMissingProfile() {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Profile Missing'),
          content: const Text(
            'Your account exists but profile role is missing. Pick your role to create profile entry.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 'retailer'),
              child: const Text('Retailer'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 'wholesaler'),
              child: const Text('Wholesaler'),
            ),
          ],
        );
      },
    );
  }

  String _defaultNameFromEmail() {
    final email = _emailController.text.trim();
    if (email.contains('@')) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) {
        return local;
      }
    }
    return 'User';
  }

  String? _roleFromUserMetadata() {
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    final rawRole = metadata?['role'];
    if (rawRole is! String) {
      return null;
    }

    final role = rawRole.toLowerCase();
    if (role != 'wholesaler' && role != 'retailer') {
      return null;
    }

    return role;
  }

  void _navigateByRole(String role) {
    if (role == 'wholesaler') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WholesalerHome()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RetailerDashboard()),
    );
  }

  Future<void> _onLogin() async {
    if (_retryAfterSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait $_retryAfterSeconds seconds and try again.',
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      var role = (await _authService.getUserRole())?.toLowerCase();
      if (!mounted) {
        return;
      }

      if (role != 'wholesaler' && role != 'retailer') {
        final selectedRole =
            _roleFromUserMetadata() ?? await _askRoleForMissingProfile();
        if (!mounted) {
          return;
        }

        if (selectedRole == null) {
          await _authService.logout();
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login cancelled.')));
          return;
        }

        await _authService.createProfileEntryForCurrentUser(
          role: selectedRole,
          name: _defaultNameFromEmail(),
        );

        role = selectedRole;
      }

      if (!mounted) {
        return;
      }

      final resolvedRole = role;
      if (resolvedRole == null) {
        throw const AuthException(
          'Unable to resolve role after profile insert.',
        );
      }

      _navigateByRole(resolvedRole);
    } on AuthException catch (error) {
      if (_isRateLimitMessage(error.message)) {
        _startRetryCooldown(_retrySecondsFromMessage(error.message));
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login timed out. Check internet and Supabase status.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'VendorLink',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Manage your business smarter',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  final email = (value ?? '').trim();
                                  if (email.isEmpty) {
                                    return 'Please enter email';
                                  }
                                  final isValid = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(email);
                                  if (!isValid) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Please enter password';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton(
                                onPressed:
                                    (_isLoading || _retryAfterSeconds > 0)
                                    ? null
                                    : _onLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _retryAfterSeconds > 0
                                            ? 'Try again in ${_retryAfterSeconds}s'
                                            : 'Login',
                                      ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Create Account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
