import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color fieldLine = Color(0xFFB99A7B);
  static const Color hintColor = Color(0xFF929292);
  static const Color backgroundColor = Color(0xFFF8F5EF);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _hidePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // سنربطه بالشاشة الرئيسية بعد تجهيزها.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed in successfully.')));
    } on FirebaseAuthException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Invalid email or password.';
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
            top: screenSize.height * 0.035,
            right: 0,
            child: SizedBox(
              width: screenSize.width,
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
                      Text(
                        'SIGN IN',
                        textAlign: TextAlign.left,
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
                      const SizedBox(height: 34),
                      _buildLabel('Email Address'),
                      TextFormField(
                        controller: _emailController,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
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

                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      _buildLabel('Password'),
                      TextFormField(
                        controller: _passwordController,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                        obscureText: _hidePassword,
                        style: GoogleFonts.reemKufi(color: brown, fontSize: 16),
                        textAlignVertical: TextAlignVertical.bottom,
                        decoration: _fieldDecoration(
                          hintText: '**********',
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
                              color: brown,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }

                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.reemKufi(
                              color: brown,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                              decorationColor: brown,
                            ),
                          ),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.reemKufi(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: _isLoading ? null : _signIn,
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
                                      'Sign in',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don’t Have An Account? ',
                            style: GoogleFonts.reemKufi(
                              color: brown,
                              fontSize: 15,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.reemKufi(
                                color: brown,
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                                decorationColor: brown,
                              ),
                            ),
                          ),
                        ],
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

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.reemKufi(color: hintColor, fontSize: 16),
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 22, bottom: 1),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
