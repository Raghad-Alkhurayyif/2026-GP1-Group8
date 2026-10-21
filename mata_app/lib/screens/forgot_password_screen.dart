import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color fieldLine = Color(0xFFB99A7B);
  static const Color hintColor = Color(0xFF929292);
  static const Color backgroundColor = Color(0xFFF8F5EF);

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
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/welcome_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: screenSize.height * 0.06,
            //right: 0,
            right: 40,
            child: SizedBox(
              // width: screenSize.width,
              width: 370, 
              child: Image.asset(
                'assets/images/mata_logo.png',
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          Positioned.fill(
            top: screenSize.height * 0.27,
            child: Container(
              decoration: const BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 34, 32, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'FORGOT PASSWORD',
                          style: GoogleFonts.reemKufi(
                            color: brown,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Color(0x40000000),
                                offset: Offset(0, 3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
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
                        style: GoogleFonts.reemKufi(color: brown, fontSize: 16),
                        textAlignVertical: TextAlignVertical.bottom,
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
                          style: GoogleFonts.reemKufi(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _successMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.reemKufi(
                            color: brown,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: _isLoading ? null : _sendResetLink,
                        child: Opacity(
                          opacity: _isLoading ? 0.6 : 1,
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              image: const DecorationImage(
                                image: AssetImage(
                                  'assets/images/'
                                  'sign_in_button_background.png',
                                ),
                                fit: BoxFit.fill,
                              ),
                              border: Border.all(
                                color: backgroundColor,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 23,
                                    height: 23,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Transform.translate(
                                    offset: const Offset(0, -3),
                                    child: Text(
                                      'Send Reset Link',
                                      style: GoogleFonts.reemKufi(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Back to Sign In',
                            style: GoogleFonts.reemKufi(
                              color: brown,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                              decorationColor: brown,
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
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.reemKufi(
        color: brown,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.reemKufi(color: hintColor, fontSize: 16),
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 22, bottom: 1),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: fieldLine, width: 1.5),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: brown, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
