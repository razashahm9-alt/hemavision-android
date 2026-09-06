class Validators {
  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    final requiredError = required(value, 'Email');
    if (requiredError != null) return requiredError;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? value) {
    final requiredError = required(value, 'Password');
    if (requiredError != null) return requiredError;
    return value!.length < 6 ? 'Password must be at least 6 characters' : null;
  }

  static String? numeric(String? value, String label) {
    final requiredError = required(value, label);
    if (requiredError != null) return requiredError;
    return double.tryParse(value!.trim()) == null
        ? 'Enter a valid number'
        : null;
  }
}
