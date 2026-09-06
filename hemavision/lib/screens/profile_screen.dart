import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_colors.dart';
import '../app_theme.dart';
import '../firebase_options.dart';
import '../models/user_model.dart';
import '../utils/demo_session.dart';
import '../utils/validators.dart';
import '../widgets/custom_appbar.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _edit = false;
  bool _dark = true;
  bool _notifications = true;
  bool _loading = false;

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      if (DefaultFirebaseOptions.isDemoConfig) {
        await DemoSession.saveUser(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          role: 'Patient',
        );
        _snack('Profile updated successfully');
        setState(() => _edit = false);
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
      }, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        _name.text.trim(),
      );
      _snack('Profile updated successfully');
      setState(() => _edit = false);
    } on FirebaseException {
      _snack('Database error, try again');
    } catch (_) {
      _snack('No internet connection');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _password() async {
    if (_newPassword.text.length < 6 ||
        _newPassword.text != _confirmPassword.text) {
      _snack('Check password length and confirmation');
      return;
    }
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(
        _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _snack('Password updated successfully');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Password update failed');
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: 'Profile',
        showBack: Navigator.canPop(context),
        actions: [
          IconButton(
            icon: Icon(_edit ? Icons.close_rounded : Icons.edit_rounded),
            onPressed: () => setState(() => _edit = !_edit),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: DefaultFirebaseOptions.isDemoConfig
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
        builder: (_, snap) {
          if (!DefaultFirebaseOptions.isDemoConfig &&
              snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            );
          }
          if (DefaultFirebaseOptions.isDemoConfig) {
            return FutureBuilder<UserModel>(
              future: DemoSession.user(),
              builder: (_, demoSnap) =>
                  _profileBody(demoSnap.data ?? _fallbackUser()),
            );
          }
          final user = snap.hasData && snap.data!.exists
              ? UserModel.fromDoc(snap.data!)
              : _fallbackUser();
          return _profileBody(user);
        },
      ),
    );
  }

  UserModel _fallbackUser() => UserModel(
    id: uid,
    fullName:
        FirebaseAuth.instance.currentUser?.displayName ?? 'HemaVision User',
    email: FirebaseAuth.instance.currentUser?.email ?? '',
    role: 'Patient',
    createdAt: DateTime.now(),
  );

  Widget _profileBody(UserModel user) {
    if (!_edit) {
      _name.text = user.fullName;
      _email.text = user.email;
      _phone.text = user.phone;
    }
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _header(user),
            const SizedBox(height: 14),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _edit
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _editForm(user),
            ),
            _passwordCard(),
            _settingsCard(),
            _dangerCard(),
          ],
        ),
      ),
    );
  }

  Widget _header(UserModel user) => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryTeal,
            child: Text(
              user.initials,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(user.role),
          ),
          const SizedBox(height: 8),
          Text(
            user.email,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            'Member since ${user.createdAt.toLocal().toString().split(' ').first}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _editForm(UserModel user) => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              validator: (v) => Validators.required(v, 'Full name'),
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              validator: Validators.email,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: user.role,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _passwordCard() => Card(
    color: AppColors.bgCard,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Change Password',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const Divider(),
          TextField(
            controller: _currentPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New Password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _password,
            child: const Text('Update Password'),
          ),
        ],
      ),
    ),
  );

  Widget _settingsCard() => Card(
    color: AppColors.bgCard,
    child: Column(
      children: [
        SwitchListTile(
          value: _dark,
          onChanged: (v) => setState(() => _dark = v),
          title: const Text('Dark Mode'),
          secondary: const Icon(Icons.dark_mode_rounded),
        ),
        SwitchListTile(
          value: _notifications,
          onChanged: (v) => setState(() => _notifications = v),
          title: const Text('Notifications'),
          secondary: const Icon(Icons.notifications_rounded),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ValueListenableBuilder<String>(
            valueListenable: AppThemeController.current,
            builder: (_, selected, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_rounded),
                    SizedBox(width: 12),
                    Text('Theme'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppThemeController.themes
                      .map(
                        (name) => ChoiceChip(
                          label: Text(name),
                          selected: selected == name,
                          onSelected: (_) =>
                              AppThemeController.current.value = name,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.language_rounded),
          title: Text('Language'),
          trailing: Text('English'),
        ),
      ],
    ),
  );

  Widget _dangerCard() => Card(
    color: AppColors.bgCard,
    child: ListTile(
      leading: const Icon(Icons.logout_rounded, color: AppColors.accentSoft),
      title: const Text(
        'Logout',
        style: TextStyle(color: AppColors.accentSoft),
      ),
      onTap: _logoutSheet,
    ),
  );

  void _logoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
              },
              child: const Text('Confirm'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
