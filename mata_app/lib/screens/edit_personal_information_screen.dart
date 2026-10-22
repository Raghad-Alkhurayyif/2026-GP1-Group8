import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../widgets/sos_button.dart';

class EditPersonalInformationScreen extends StatefulWidget {
  const EditPersonalInformationScreen({super.key});

  @override
  State<EditPersonalInformationScreen> createState() =>
      _EditPersonalInformationScreenState();
}

class _EditPersonalInformationScreenState
    extends State<EditPersonalInformationScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color borderColor = Color(0xFFDCCDB5);
  static const Color hintGray = Color(0xFF929292);

  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserInformation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInformation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No signed-in user was found.';
      });
      return;
    }

    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = document.data();
      final storedDate = data?['dateOfBirth'];

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = data?['name'] as String? ?? '';
        _emailController.text = user.email ?? data?['email'] as String? ?? '';

        if (storedDate is Timestamp) {
          _dateOfBirth = storedDate.toDate();
        }

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Your information could not be loaded. Please try again.';
      });
    }
  }

  int _calculateAge(DateTime dateOfBirth) {
    final today = DateTime.now();
    var age = today.year - dateOfBirth.year;

    final birthdayHasPassed =
        today.month > dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);

    if (!birthdayHasPassed) {
      age--;
    }

    return age;
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
          _dateOfBirth ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select date of birth',
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _dateOfBirth = selectedDate;
      _errorMessage = null;
    });
  }

  String? _validateInformation() {
    if (_nameController.text.trim().isEmpty) {
      return 'Please enter your name.';
    }

    final dateOfBirth = _dateOfBirth;

    if (dateOfBirth == null) {
      return 'Please select your date of birth.';
    }

    final today = DateTime.now();
    final age = _calculateAge(dateOfBirth);

    if (dateOfBirth.isAfter(today) || age > 120) {
      return 'Please enter a valid date of birth.';
    }

    if (age < 18) {
      return 'Ma’ta is for adults aged 18 and above.';
    }

    return null;
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    final validationError = _validateInformation();

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
      await _authService.updatePersonalInformation(
        name: _nameController.text,
        dateOfBirth: _dateOfBirth!,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = 'Your changes could not be saved. Please try again.';
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
                      Expanded(
                        child: Text(
                          'Edit Personal Information',
                          style: GoogleFonts.reemKufi(
                            color: darkBrown,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: darkBrown),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(text: 'Name'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  style: GoogleFonts.reemKufi(
                                    color: darkBrown,
                                    fontSize: 15,
                                  ),
                                  decoration: _fieldDecoration(
                                    hintText: 'Enter your name',
                                  ),
                                  onChanged: (_) {
                                    if (_errorMessage != null) {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 22),
                                _FieldLabel(text: 'Email'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _emailController,
                                  readOnly: true,
                                  style: GoogleFonts.reemKufi(
                                    color: hintGray,
                                    fontSize: 15,
                                  ),
                                  decoration: _fieldDecoration(
                                    hintText: '',
                                    suffixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: hintGray,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _FieldLabel(text: 'Date of Birth'),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _selectDateOfBirth,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 17,
                                    ),
                                    decoration: BoxDecoration(
                                      color: softBeige,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1.3,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _dateOfBirth == null
                                                ? 'Select your date of birth'
                                                : _formatDate(_dateOfBirth!),
                                            style: GoogleFonts.reemKufi(
                                              color: _dateOfBirth == null
                                                  ? hintGray
                                                  : darkBrown,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.calendar_month_outlined,
                                          color: brown,
                                          size: 23,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: GoogleFonts.reemKufi(
                                      color: const Color(0xFFB71616),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveChanges,
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
                                            'SAVE CHANGES',
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

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.reemKufi(color: hintGray, fontSize: 15),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: softBeige,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: brown, width: 1.8),
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
        color: _EditPersonalInformationScreenState.darkBrown,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
