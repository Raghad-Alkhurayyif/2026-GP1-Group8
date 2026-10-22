import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState
    extends State<DeleteAccountDialog> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color borderColor = Color(0xFFDCCDB5);
  static const Color hintGray = Color(0xFF929292);
  static const Color red = Color(0xFFB71616);

  final AuthService _authService = AuthService();
  final TextEditingController _passwordController =
      TextEditingController();

  bool _showPassword = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    FocusScope.of(context).unfocus();

    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter your password to continue.';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await _authService.deleteAccount(
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      String message;

      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'The password is incorrect.';
          break;

        case 'network-request-failed':
          message =
              'Please check your internet connection and try again.';
          break;

        default:
          message =
              'The account could not be deleted. Please try again.';
      }

      setState(() {
        _isDeleting = false;
        _errorMessage = message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
        _errorMessage =
            'The account could not be deleted. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: softBeige,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: Text(
        'Delete Account',
        style: GoogleFonts.reemKufi(
          color: red,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Deleting your account will permanently remove:\n\n'
'• Your profile information\n'
'• Your assessment history and recognized symptoms\n'
'• Your generated reports\n'
'• Your emergency contacts and default SOS contact\n\n'
'This action cannot be undone.',
              style: GoogleFonts.reemKufi(
                color: darkBrown,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enter your password to confirm',
              style: GoogleFonts.reemKufi(
                color: darkBrown,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              enabled: !_isDeleting,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() {
                    _errorMessage = null;
                  });
                }
              },
              style: GoogleFonts.reemKufi(
                color: darkBrown,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: GoogleFonts.reemKufi(
                  color: hintGray,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: softBeige,
                suffixIcon: IconButton(
                  onPressed: _isDeleting
                      ? null
                      : () {
                          setState(() {
                            _showPassword =
                                !_showPassword;
                          });
                        },
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: brown,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: borderColor,
                    width: 1.3,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: brown,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: GoogleFonts.reemKufi(
                  color: red,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting
              ? null
              : () {
                  Navigator.pop(context, false);
                },
          child: Text(
            'Cancel',
            style: GoogleFonts.reemKufi(
              color: brown,
            ),
          ),
        ),
        TextButton(
          onPressed:
              _isDeleting ? null : _deleteAccount,
          child: _isDeleting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: red,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Delete Permanently',
                  style: GoogleFonts.reemKufi(
                    color: red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}