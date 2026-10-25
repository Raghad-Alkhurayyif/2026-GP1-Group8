import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/mata_theme.dart';

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
      backgroundColor: MataColors.softWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Text(
        'Delete Account',
        style: MataText.display(color: red, fontSize: 22),
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
              style: MataText.body(
                color: darkBrown,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enter your password to confirm',
              style: MataText.body(
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
              style: MataText.body(
                color: darkBrown,
                fontSize: 14,
              ),
              decoration: MataFields.light(
                hintText: 'Password',
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
                    color: MataColors.faint,
                    size: 20,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: MataText.body(
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
            style: MataText.body(
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
                  style: MataText.body(
                    color: red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}