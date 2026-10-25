import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/road_scene.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const Color softWhite = MataColors.softWhite;
  static const Color backgroundColor = Color(0xFF1E1517);

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

      Navigator.of(context).popUntil((route) => route.isFirst);
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
                          'Welcome back',
                          style: MataText.display(
                            color: softWhite,
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue your check-ins.',
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
                            if (_errorMessage != null) {
                              setState(() {
                                _errorMessage = null;
                              });
                            }
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

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
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
                              style: _linkStyle,
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: MataText.body(
                              color: const Color(0xFFFF9C8C),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 4),
                        MataButton(
                          label: 'Sign in',
                          style: MataButtonStyle.cream,
                          loading: _isLoading,
                          onPressed: _isLoading ? null : _signIn,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New here? ',
                              style: MataText.body(
                                color: softWhite.withValues(alpha: 0.7),
                                fontSize: 13,
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
                              child: Text('Sign Up', style: _linkStyle),
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

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return MataFields.night(hintText: hintText, suffixIcon: suffixIcon);
  }
}
