import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/road_scene.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const Color softWhite = MataColors.softWhite;
  static const Color backgroundColor = Color(0xFF1E1517);

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool get _hasMinimumLength => _passwordController.text.length >= 8;

  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);

  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_passwordController.text);

  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);

  bool get _passwordIsValid =>
      _hasMinimumLength && _hasUppercase && _hasLowercase && _hasNumber;

  int _calculateAge(DateTime dateOfBirth) {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;

    final birthdayPassed =
        today.month > dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);

    if (!birthdayPassed) {
      age--;
    }

    return age;
  }

  String? _validateDateOfBirth() {
    final dateOfBirth = _selectedDateOfBirth;

    if (dateOfBirth == null) {
      return 'Date of birth is required.';
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    if (dateOfBirth.isAfter(todayOnly)) {
      return 'The date of birth is not valid.';
    }

    final age = _calculateAge(dateOfBirth);

    if (age > 120) {
      return 'The date of birth is not valid.';
    }

    if (age < 18) {
      return 'Ma’ta is for adults aged 18 and above.';
    }

    return null;
  }

  final _authService = AuthService();

  DateTime? _selectedDateOfBirth;

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _isLoading = false;

  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _dateOfBirthController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _selectDateOfBirth() async {
    final today = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate:
          _selectedDateOfBirth ??
          DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(today.year - 130, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDateOfBirth = selectedDate;
      _dateOfBirthController.text = _formatDate(selectedDate);
      _errorMessage = null;
    });
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        name: _nameController.text,
        dateOfBirth: _selectedDateOfBirth!,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        if (error.code == 'email-already-in-use') {
          _errorMessage = 'An account already exists for this email.';
        } else if (error.code == 'invalid-email') {
          _errorMessage = 'Please enter a valid email address.';
        } else if (error.code == 'weak-password') {
          _errorMessage = 'The password does not meet the required rules.';
        } else if (error.code == 'network-request-failed') {
          _errorMessage = 'Please check your internet connection.';
        } else {
          _errorMessage = 'The account could not be created. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
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
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // the same twilight as the welcome screen, the horizon drawn higher
          const Positioned.fill(child: RoadScene(mood: RoadMood.signIn)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: MataBackButton(
                night: true,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 64, 10, 10),
                child: MataNightSheet(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create your account',
                          style: MataText.display(
                            color: softWhite,
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'It takes a minute, and keeps your check-ins '
                          'in one place.',
                          style: MataText.body(
                            color: softWhite.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                          _buildLabel('Name'),

                          TextFormField(
                            controller: _nameController,
                            onChanged: (_) {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                            textCapitalization: TextCapitalization.words,
                            style: _fieldTextStyle,
                            cursorColor: softWhite,
                            decoration: _fieldDecoration(hintText: 'Your name'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildLabel('Date of Birth'),

                          TextFormField(
                            controller: _dateOfBirthController,
                            readOnly: true,
                            onTap: _selectDateOfBirth,
                            style: _fieldTextStyle,
                            cursorColor: softWhite,
                            decoration: _fieldDecoration(hintText: 'DD/MM/YYYY'),
                            validator: (_) {
                              return _validateDateOfBirth();
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildLabel('Email Address'),

                          TextFormField(
                            controller: _emailController,
                            onChanged: (_) {
                              _clearErrorMessage();
                            },
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            style: _fieldTextStyle,
                            cursorColor: softWhite,
                            decoration: _fieldDecoration(
                              hintText: 'user123@gmail.com',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required.';
                              }

                              final emailPattern = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );

                              if (!emailPattern.hasMatch(value.trim())) {
                                return 'Enter a valid email address.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildLabel('Password'),

                          TextFormField(
                            controller: _passwordController,
                            onChanged: (_) {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                            obscureText: _hidePassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: _fieldTextStyle,
                            cursorColor: softWhite,
                            decoration: _fieldDecoration(
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _hidePassword = !_hidePassword;
                                  });
                                },
                                icon: Icon(
                                  _hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: softWhite.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required.';
                              }

                              if (!_passwordIsValid) {
                                return 'Please complete all password requirements.';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 8),

                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _buildPasswordRule(
                                '8+ characters',
                                _hasMinimumLength,
                              ),
                              _buildPasswordRule('Uppercase', _hasUppercase),
                              _buildPasswordRule('Lowercase', _hasLowercase),
                              _buildPasswordRule('Number', _hasNumber),
                            ],
                          ),

                          const SizedBox(height: 14),

                          _buildLabel('Confirm Password'),

                          TextFormField(
                            controller: _confirmPasswordController,
                            onChanged: (_) {
                              _clearErrorMessage();
                            },
                            obscureText: _hideConfirmPassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: _fieldTextStyle,
                            cursorColor: softWhite,
                            decoration: _fieldDecoration(
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 40,
                                  height: 40,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _hideConfirmPassword = !_hideConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _hideConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: softWhite.withValues(alpha: 0.7),
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password.';
                              }

                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }

                              return null;
                            },
                          ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: MataText.body(
                              color: const Color(0xFFFF9C8C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        MataButton(
                          label: 'Sign Up',
                          style: MataButtonStyle.cream,
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _signUp,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: MataText.body(
                                color: softWhite.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignInScreen(),
                                  ),
                                );
                              },
                              child: Text('Sign In', style: _linkStyle),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _fieldTextStyle =>
      MataText.body(color: softWhite, fontSize: 15, height: 1.3);

  TextStyle get _linkStyle => MataText.body(
    color: softWhite.withValues(alpha: 0.9),
    fontSize: 13,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
  );

  Widget _buildLabel(String text) => MataLabel(text, night: true);

  Widget _buildPasswordRule(String text, bool isValid) {
    final color = isValid
        ? const Color(0xFFF3D9B6)
        : softWhite.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: MataText.body(
            color: color,
            fontSize: 11.5,
            fontWeight: isValid ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return MataFields.night(hintText: hintText, suffixIcon: suffixIcon);
  }
}
