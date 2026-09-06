import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../firebase_options.dart';
import '../utils/demo_session.dart';
import '../utils/validators.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _focusNodes = List.generate(4, (_) => FocusNode());
  bool _obscure = true;
  bool _loading = false;
  String _role = 'Patient';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      if (DefaultFirebaseOptions.isDemoConfig) {
        await DemoSession.saveUser(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          role: _role,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo account created successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      await cred.user?.updateDisplayName(_name.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'fullName': _name.text.trim(),
            'email': _email.text.trim(),
            'role': _role,
            'phone': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', cred.user!.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Registration failed');
    } on FirebaseException {
      _snack('Database error, try again');
    } catch (_) {
      _snack('No internet connection');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.bloodtype_rounded,
                  color: AppColors.accentSoft,
                  size: 54,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                _animatedField(
                  0,
                  _name,
                  'Full Name',
                  Icons.person_rounded,
                  (v) => Validators.required(v, 'Full name'),
                ),
                _animatedField(
                  1,
                  _email,
                  'Email',
                  Icons.email_rounded,
                  Validators.email,
                ),
                _animatedField(
                  2,
                  _password,
                  'Password',
                  Icons.lock_rounded,
                  Validators.password,
                  password: true,
                ),
                _animatedField(
                  3,
                  _confirm,
                  'Confirm Password',
                  Icons.lock_reset_rounded,
                  (v) => v != _password.text
                      ? 'Passwords do not match'
                      : Validators.password(v),
                  password: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['Patient', 'Doctor'].map((role) {
                    final selected = role == _role;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _role = role),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: EdgeInsets.only(
                            right: role == 'Patient' ? 10 : 0,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryTeal
                                : AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              role,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Register'),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text('Already have account? Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _animatedField(
    int i,
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?) validator, {
    bool password = false,
  }) {
    return AnimatedBuilder(
      animation: _focusNodes[i],
      builder: (_, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focusNodes[i].hasFocus
                ? AppColors.primaryLight
                : AppColors.bgSurface,
          ),
        ),
        child: TextFormField(
          controller: controller,
          focusNode: _focusNodes[i],
          validator: validator,
          obscureText: password && _obscure,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            suffixIcon: password
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
