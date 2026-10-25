import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/road_scene.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color softWhite = MataColors.softWhite;
  static const Color backgroundColor = Color(0xFF1E1517);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email: _emailController.text);

      if (!mounted) return;

      setState(() {
        _successMessage =
            'If an account exists for this email, '
            'a password reset link has been sent.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      if (error.code == 'user-not-found') {
        setState(() {
          _successMessage =
              'If an account exists for this email, '
              'a password reset link has been sent.';
        });
      } else {
        setState(() {
          if (error.code == 'invalid-email') {
            _errorMessage = 'Please enter a valid email address.';
          } else if (error.code == 'too-many-requests') {
            _errorMessage = 'Too many requests. Please try again later.';
          } else if (error.code == 'network-request-failed') {
            _errorMessage = 'Please check your internet connection.';
          } else {
            _errorMessage =
                'The reset email could not be sent. '
                'Please try again.';
          }
        });
      }
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
                          'Forgot password',
                          style: MataText.display(
                            color: softWhite,
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Enter your email and we'll send you a link "
                          'to reset your password.',
                          style: MataText.body(
                            color: softWhite.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildLabel('Email Address'),
                        TextFormField(
                          controller: _emailController,
                          onChanged: (_) {
                            if (_errorMessage != null ||
                                _successMessage != null) {
                              setState(() {
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            }
                          },
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: MataText.body(
                            color: softWhite,
                            fontSize: 15,
                            height: 1.3,
                          ),
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
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: MataText.body(
                              color: const Color(0xFFFF9C8C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (_successMessage != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _successMessage!,
                            textAlign: TextAlign.center,
                            style: MataText.body(
                              color: const Color(0xFFF3D9B6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        MataButton(
                          label: 'Send Reset Link',
                          style: MataButtonStyle.cream,
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _sendResetLink,
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              'Back to Sign In',
                              style: MataText.body(
                                color: softWhite.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
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

  Widget _buildLabel(String text) => MataLabel(text, night: true);

  InputDecoration _fieldDecoration({required String hintText}) {
    return MataFields.night(hintText: hintText);
  }
}
