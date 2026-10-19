import 'package:flutter/material.dart';
import '../../core/services/firebase_user_service.dart';
import '../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseUserService _userService = FirebaseUserService();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _selectedLanguage = 'English';
  String _selectedBloodGroup = '';

  static const List<String> _languages = ['English', 'Hindi', 'Marathi'];
  static const List<String> _bloodGroups = [
    '',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
  );

  String? _validateEmail(String? val) {
    if (val == null || val.trim().isEmpty) {
      return 'Email address is required.';
    }
    final trimmed = val.trim();
    if (!trimmed.contains('@')) {
      return 'Email must contain an "@" symbol.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address (e.g. name@domain.com)';
    }
    return null;
  }

  String? _validatePassword(String? val) {
    if (val == null || val.isEmpty) {
      return 'Password is required.';
    }
    if (val.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!_isLogin) {
      if (!RegExp(r'[A-Z]').hasMatch(val)) {
        return 'Must include at least one uppercase letter (A-Z).';
      }
      if (!RegExp(r'[a-z]').hasMatch(val)) {
        return 'Must include at least one lowercase letter (a-z).';
      }
      if (!RegExp(r'[0-9]').hasMatch(val)) {
        return 'Must include at least one number (0-9).';
      }
      if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(val)) {
        return 'Must include at least one symbol (!@#\$%^&*).';
      }
    }
    return null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    String? error;
    if (_isLogin) {
      error = await _userService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      error = await _userService.signUp(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phoneNumber: _phoneController.text,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
        preferredLanguage: _selectedLanguage,
        bloodGroup: _selectedBloodGroup,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLogin
                ? 'Signed in successfully!'
                : 'Tourist account created and saved to Cloud Firestore!',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    final emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() {
        _errorMessage = 'Please enter a valid email address above to receive a password reset link.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final error = await _userService.sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firebaseReady = _userService.isFirebaseInitialized;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Tourist Sign In' : 'Create Tourist Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!firebaseReady) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cautionAmber),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF92400E)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Firebase Project Configuration Needed',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Authentication uses genuine Firebase Auth & Cloud Firestore (no fake local login). '
                        'To activate live sign-in:\n'
                        '1. Create a project at console.firebase.google.com\n'
                        '2. Enable Email/Password Auth & Cloud Firestore\n'
                        '3. Run "flutterfire configure" in the project terminal.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textDark, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.highRiskRed.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.highRiskRed, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (!_isLogin) ...[
                const Text(
                  'Required Account Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 2) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'e.g. tourist@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  helperText: !_isLogin
                      ? 'Min 8 chars: 1 uppercase, 1 lowercase, 1 number, 1 symbol'
                      : null,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
              ),

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _handleForgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),

              if (!_isLogin) ...[
                const SizedBox(height: 18),
                const Text(
                  'Optional Emergency & Tourist Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Used only to assist you during an emergency. You can update these anytime.',
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Your Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Name (Optional)',
                    prefixIcon: Icon(Icons.contact_emergency_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact Phone (Optional)',
                    prefixIcon: Icon(Icons.call_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Language',
                    prefixIcon: Icon(Icons.language),
                    border: OutlineInputBorder(),
                  ),
                  items: _languages
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLanguage = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBloodGroup,
                  decoration: const InputDecoration(
                    labelText: 'Blood Group (Optional — Not Mandatory)',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _bloodGroups
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.isEmpty ? 'Prefer not to specify' : b),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBloodGroup = val);
                  },
                ),
              ],

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _isLogin ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Create Tourist Account"
                      : 'Already registered? Sign In',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text('Explore as Guest (Offline Demo Mode)'),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        await _userService.signInAsGuest();
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Exploring in Guest Demo Mode.'),
                          ),
                        );
                        navigator.pop();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
