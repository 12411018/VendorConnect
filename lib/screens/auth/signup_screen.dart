import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vendorlink/services/auth/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _accountType = 'wholesaler';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  int _retryAfterSeconds = 0;
  Timer? _retryTimer;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _retryTimer?.cancel();
    _fullNameController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  Future<void> _onCreateAccount() async {
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
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _fullNameController.text.trim(),
        role: _accountType,
        shopName: _accountType == 'wholesaler'
            ? _shopNameController.text.trim()
            : null,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully. Please login.'),
        ),
      );
      Navigator.pop(context);
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up failed. Please try again.')),
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
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _fullNameController,
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  final name = (value ?? '').trim();
                                  if (name.isEmpty) {
                                    return 'Please enter full name';
                                  }
                                  if (name.length < 3) {
                                    return 'Name must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              if (_accountType == 'wholesaler') ...[
                                TextFormField(
                                  controller: _shopNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Shop Name',
                                    prefixIcon: const Icon(
                                      Icons.storefront_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_accountType != 'wholesaler') {
                                      return null;
                                    }
                                    final shop = (value ?? '').trim();
                                    if (shop.isEmpty) {
                                      return 'Please enter shop name';
                                    }
                                    if (shop.length < 2) {
                                      return 'Shop name must be at least 2 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
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
                                  final password = value ?? '';
                                  if (password.isEmpty) {
                                    return 'Please enter password';
                                  }
                                  if (password.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_person_outlined,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  final confirm = value ?? '';
                                  if (confirm.isEmpty) {
                                    return 'Please confirm password';
                                  }
                                  if (confirm != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _accountType,
                                decoration: InputDecoration(
                                  labelText: 'Account Type',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'wholesaler',
                                    child: Text('Wholesaler'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'retailer',
                                    child: Text('Retailer'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _accountType = value ?? 'wholesaler';
                                  });
                                },
                              ),
                              const SizedBox(height: 22),
                              ElevatedButton(
                                onPressed:
                                    (_isLoading || _retryAfterSeconds > 0)
                                    ? null
                                    : _onCreateAccount,
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
                                            : 'Create Account',
                                      ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Back to Login'),
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
