import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../utils/demo_session.dart';
import '../utils/validators.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _focusEmail = FocusNode();
  final _focusPassword = FocusNode();

  late final AnimationController _controller;
  late final Animation<double> _fade;

  bool _loading = false;
  bool _resettingPassword = false;
  bool _pulse = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _pulse = true);
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _focusEmail.dispose();
    _focusPassword.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      if (DefaultFirebaseOptions.isDemoConfig) {
        await DemoSession.saveUser(
          fullName: 'Demo User',
          email: _email.text.trim(),
          role: 'Patient',
        );

        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No Firebase user was returned.',
        );
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('uid', user.uid);

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on FirebaseAuthException catch (error) {
      _snack(_loginErrorMessage(error));
    } catch (_) {
      _snack(
        'Could not connect. Check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    final validationError = Validators.email(email);

    if (validationError != null) {
      _focusEmail.requestFocus();
      _snack(validationError);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _resettingPassword = true);

    try {
      if (DefaultFirebaseOptions.isDemoConfig) {
        _snack('Password reset is unavailable in demo mode.');
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      _snack(
        'If an account exists for $email, a password reset email has been sent. Check your inbox and spam folder.',
      );
    } on FirebaseAuthException catch (error) {
      _snack(_resetErrorMessage(error));
    } catch (_) {
      _snack(
        'Could not connect. Check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _resettingPassword = false);
      }
    }
  }

  String _loginErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return 'The email or password is incorrect. You can use Forgot Password to reset it.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many unsuccessful attempts. Please wait and try again later.';

      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';

      case 'operation-not-allowed':
        return 'Email and password login is not enabled in Firebase Authentication.';

      default:
        return error.message ?? 'Login failed. Please try again.';
    }
  }

  String _resetErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-not-found':
        return 'No account was found for this email address.';

      case 'too-many-requests':
        return 'Too many reset attempts. Please wait and try again later.';

      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';

      case 'operation-not-allowed':
        return 'Password reset is unavailable because Email/Password authentication is not enabled.';

      default:
        return error.message ??
            'Password reset failed. Please try again later.';
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authenticationBusy = _loading || _resettingPassword;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: _pulse ? Alignment.topRight : Alignment.bottomLeft,
                radius: 1.1,
                colors: [
                  AppColors.primaryTeal.withValues(alpha: 0.22),
                  AppColors.bgDark,
                ],
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 70),
                      const Icon(
                        Icons.bloodtype_rounded,
                        color: AppColors.accentSoft,
                        size: 58,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 34),
                      _field(
                        focus: _focusEmail,
                        controller: _email,
                        label: 'Email',
                        icon: Icons.email_rounded,
                        validator: Validators.email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          _focusPassword.requestFocus();
                        },
                      ),
                      _field(
                        focus: _focusPassword,
                        controller: _password,
                        label: 'Password',
                        icon: Icons.lock_rounded,
                        validator: Validators.password,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!authenticationBusy) {
                            _login();
                          }
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: authenticationBusy ? null : _resetPassword,
                          child: _resettingPassword
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Forgot Password?'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: authenticationBusy ? null : _login,
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Login'),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: authenticationBusy
                              ? null
                              : () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          child: const Text("Don't have an account? Register"),
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
    );
  }

  Widget _field({
    required FocusNode focus,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return AnimatedBuilder(
      animation: focus,
      builder: (context, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focus.hasFocus
                ? AppColors.primaryLight
                : AppColors.bgSurface,
          ),
        ),
        child: TextFormField(
          controller: controller,
          focusNode: focus,
          validator: validator,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          autofillHints: obscure
              ? const [AutofillHints.password]
              : const [AutofillHints.email],
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      ),
    );
  }
}
