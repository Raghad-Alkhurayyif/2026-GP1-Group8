import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'change_password_screen.dart';
import 'edit_personal_information_screen.dart';
import '../theme/mata_theme.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/sos_button.dart';
import '../widgets/stroke_background.dart';

import '../widgets/mata_bottom_navigation_bar.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color red = Color(0xFFB71616);
  static const Color borderColor = Color(0x1F79543B);

  String _formatDate(Object? value) {
    if (value is! Timestamp) {
      return 'Not available';
    }

    final date = value.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: MataColors.softWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Sign Out',
            style: MataText.display(fontSize: 22, color: darkBrown),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: MataText.body(color: brown),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('Cancel', style: MataText.body(color: brown)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Sign Out',
                style: MataText.body(
                  color: red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: darkBrown)),
      );
    }

    return Scaffold(
      backgroundColor: softBeige,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const StrokeBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 12),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: MataCornerLogo(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'My Account',
                      style: MataText.display(fontSize: 30),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: darkBrown),
                          );
                        }

                        final data = snapshot.data?.data();

                        final name =
                            data?['name'] as String? ?? 'Not available';

                        final email =
                            user.email ??
                            (data?['email'] as String? ?? 'Not available');

                        final dateOfBirth = _formatDate(data?['dateOfBirth']);

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionTitle(text: 'ACCOUNT INFORMATION'),
                              const SizedBox(height: 10),
                              MataGlass(
                                padding: EdgeInsets.zero,
                                radius: 18,
                                child: Column(
                                  children: [
                                    _InformationRow(label: 'Name', value: name),
                                    const Divider(
                                      height: 1,
                                      color: borderColor,
                                    ),
                                    _InformationRow(
                                      label: 'Email',
                                      value: email,
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: borderColor,
                                    ),
                                    _InformationRow(
                                      label: 'Date of Birth',
                                      value: dateOfBirth,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 26),
                              const _SectionTitle(text: 'ACCOUNT ACTIONS'),
                              const SizedBox(height: 10),
                              MataGlass(
                                padding: EdgeInsets.zero,
                                radius: 18,
                                child: Column(
                                  children: [
                                    _ActionRow(
                                      label: 'Edit Personal Information',
                                      onTap: () async {
                                        final updated =
                                            await Navigator.of(
                                              context,
                                            ).push<bool>(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const EditPersonalInformationScreen(),
                                              ),
                                            );

                                        if (updated == true &&
                                            context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Your information has been updated.',
                                                style: MataText.body(color: MataColors.softWhite),
                                              ),
                                              backgroundColor: darkBrown,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: borderColor,
                                    ),
                                    _ActionRow(
                                      label: 'Change Password',
                                      onTap: () async {
                                        final changed =
                                            await Navigator.of(
                                              context,
                                            ).push<bool>(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const ChangePasswordScreen(),
                                              ),
                                            );

                                        if (changed == true &&
                                            context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Your password has been changed.',
                                                style: MataText.body(color: MataColors.softWhite),
                                              ),
                                              backgroundColor: darkBrown,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: borderColor,
                                    ),
                                    const _ActionRow(
                                      label: 'Emergency Contacts',
                                      onTap: null,
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: borderColor,
                                    ),
                                    _ActionRow(
                                      label: 'Sign Out',
                                      onTap: () {
                                        _confirmSignOut(context);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              MataGlass(
                                padding: EdgeInsets.zero,
                                radius: 18,
                                child: _ActionRow(
                                  label: 'Delete Account',
                                  labelColor: red,
                                  onTap: () async {
                                    final deleted = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) =>
                                          const DeleteAccountDialog(),
                                    );

                                    if (deleted == true && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Your account has been permanently deleted.',
                                              style: MataText.body(color: MataColors.softWhite),
                                            ),
                                            backgroundColor: darkBrown,
                                            duration: const Duration(
                                              seconds: 4,
                                            ),
                                          ),
                                        );

                                      Navigator.of(context)
                                          .popUntil((route) => route.isFirst);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  'This action is permanent and cannot be undone.',
                                  style: MataText.body(
                                    color: MataColors.faint,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  MataBottomNavigationBar(
                    currentIndex: 2,
                    onHomeTap: () {
                      Navigator.pop(context);
                    },
                    onHistoryTap: null,
                    onAccountTap: () {},
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 22),
                child: SosButton(onTap: () {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: MataText.body(
          color: MataColors.faint,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: MataText.body(
                color: AccountScreen.brown,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: MataText.body(
                color: AccountScreen.darkBrown,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.onTap,
    this.labelColor = AccountScreen.darkBrown,
  });

  final String label;
  final VoidCallback? onTap;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: MataText.body(
                  color: labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: MataColors.faint,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }
}
