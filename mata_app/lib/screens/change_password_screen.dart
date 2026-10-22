import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../widgets/sos_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color borderColor = Color(0xFFDCCDB5);
  static const Color hintGray = Color(0xFF929292);
  static const Color red = Color(0xFFB71616);

  final AuthService _authService = AuthService();

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isSaving = false;
  String? _errorMessage;

  String get _newPassword => _newPasswordController.text;

  bool get _hasMinimumLength => _newPassword.length >= 8;

  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newPassword);

  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_newPassword);

  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPassword);

  bool get _meetsAllRules =>
      _hasMinimumLength && _hasUppercase && _hasLowercase && _hasNumber;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onFieldChanged(String _) {
    setState(() {
      _errorMessage = null;
    });
  }

  String? _validateForm() {
    final currentPassword = _currentPasswordController.text;

    final newPassword = _newPasswordController.text;

    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      return 'Please enter your current password.';
    }

    if (newPassword.isEmpty) {
      return 'Please enter a new password.';
    }

    if (!_meetsAllRules) {
      return 'Please meet all password requirements.';
    }

    if (newPassword == currentPassword) {
      return 'The new password must be different from the current password.';
    }

    if (confirmPassword.isEmpty) {
      return 'Please confirm your new password.';
    }

    if (newPassword != confirmPassword) {
      return 'The new passwords do not match.';
    }

    return null;
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    final validationError = _validateForm();

    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _authService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message;

      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'The current password is incorrect.';
          break;

        case 'weak-password':
          message = 'The new password does not meet the required rules.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection and try again.';
          break;

        default:
          message = 'The password could not be changed. Please try again.';
      }

      setState(() {
        _isSaving = false;
        _errorMessage = message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = 'The password could not be changed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBeige,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(-28, -17),
                    child: Image.asset(
                      'assets/images/mata_logo.png',
                      width: 90,
                      height: 55,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: darkBrown,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Change Password',
                        style: GoogleFonts.reemKufi(
                          color: darkBrown,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel(text: 'Current Password'),
                          const SizedBox(height: 8),
                          _PasswordField(
                            controller: _currentPasswordController,
                            hintText: 'Enter your current password',
                            obscureText: !_showCurrentPassword,
                            onChanged: _onFieldChanged,
                            onVisibilityPressed: () {
                              setState(() {
                                _showCurrentPassword = !_showCurrentPassword;
                              });
                            },
                          ),
                          const SizedBox(height: 22),
                          _FieldLabel(text: 'New Password'),
                          const SizedBox(height: 8),
                          _PasswordField(
                            controller: _newPasswordController,
                            hintText: 'Enter your new password',
                            obscureText: !_showNewPassword,
                            onChanged: _onFieldChanged,
                            onVisibilityPressed: () {
                              setState(() {
                                _showNewPassword = !_showNewPassword;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _PasswordRule(
                            text: 'At least 8 characters',
                            isMet: _hasMinimumLength,
                          ),
                          _PasswordRule(
                            text: 'At least one uppercase letter',
                            isMet: _hasUppercase,
                          ),
                          _PasswordRule(
                            text: 'At least one lowercase letter',
                            isMet: _hasLowercase,
                          ),
                          _PasswordRule(
                            text: 'At least one number',
                            isMet: _hasNumber,
                          ),
                          const SizedBox(height: 20),
                          _FieldLabel(text: 'Confirm New Password'),
                          const SizedBox(height: 8),
                          _PasswordField(
                            controller: _confirmPasswordController,
                            hintText: 'Confirm your new password',
                            obscureText: !_showConfirmPassword,
                            onChanged: _onFieldChanged,
                            onVisibilityPressed: () {
                              setState(() {
                                _showConfirmPassword = !_showConfirmPassword;
                              });
                            },
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: GoogleFonts.reemKufi(
                                color: red,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _changePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkBrown,
                                foregroundColor: softBeige,
                                disabledBackgroundColor: brown,
                                elevation: 5,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.25,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(29),
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: softBeige,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'CHANGE PASSWORD',
                                      style: GoogleFonts.reemKufi(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(right: 28, bottom: 105, child: SosButton(onTap: () {})),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.reemKufi(
        color: _ChangePasswordScreenState.darkBrown,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onChanged,
    required this.onVisibilityPressed,
  });

  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final ValueChanged<String> onChanged;
  final VoidCallback onVisibilityPressed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: GoogleFonts.reemKufi(
        color: _ChangePasswordScreenState.darkBrown,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.reemKufi(
          color: _ChangePasswordScreenState.hintGray,
          fontSize: 15,
        ),
        filled: true,
        fillColor: _ChangePasswordScreenState.softBeige,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        suffixIcon: IconButton(
          onPressed: onVisibilityPressed,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _ChangePasswordScreenState.brown,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _ChangePasswordScreenState.borderColor,
            width: 1.3,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: _ChangePasswordScreenState.brown,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.text, required this.isMet});

  final String text;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(
            isMet
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isMet
                ? _ChangePasswordScreenState.darkBrown
                : _ChangePasswordScreenState.hintGray,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.reemKufi(
              color: isMet
                  ? _ChangePasswordScreenState.darkBrown
                  : _ChangePasswordScreenState.hintGray,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
