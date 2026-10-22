import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'change_password_screen.dart';
import 'edit_personal_information_screen.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/sos_button.dart';

import '../widgets/mata_bottom_navigation_bar.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color red = Color(0xFFB71616);
  static const Color borderColor = Color(0xFFDCCDB5);

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
          backgroundColor: softBeige,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign Out',
            style: GoogleFonts.reemKufi(
              color: darkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.reemKufi(color: brown),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('Cancel', style: GoogleFonts.reemKufi(color: brown)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: Text(
                'Sign Out',
                style: GoogleFonts.reemKufi(
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
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: const Offset(-28, -17),
                      child: Image.asset(
                        'assets/images/mata_logo.png',
                        width: 90,
                        height: 55,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'My Account',
                      style: GoogleFonts.reemKufi(
                        color: darkBrown,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
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
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: softBeige,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.3,
                                  ),
                                ),
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
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: softBeige,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.3,
                                  ),
                                ),
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
                                                style: GoogleFonts.reemKufi(),
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
                                                style: GoogleFonts.reemKufi(),
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
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: softBeige,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.3,
                                  ),
                                ),
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
                                              style: GoogleFonts.reemKufi(),
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
                                  style: GoogleFonts.reemKufi(
                                    color: brown,
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
          Positioned(right: 28, bottom: 105, child: SosButton(onTap: () {})),
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
    return Text(
      text,
      style: GoogleFonts.reemKufi(
        color: AccountScreen.brown,
        fontSize: 14,
        fontWeight: FontWeight.w500,
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
              style: GoogleFonts.reemKufi(
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
              style: GoogleFonts.reemKufi(
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
                style: GoogleFonts.reemKufi(
                  color: labelColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AccountScreen.brown,
              size: 25,
            ),
          ],
        ),
      ),
    );
  }
}
