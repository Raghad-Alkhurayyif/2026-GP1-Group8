import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/stroke_background.dart';

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
          const StrokeBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 5),
                  MataBackButton(
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Edit Personal Information',
                    style: MataText.display(fontSize: 26),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: darkBrown),
                          )
                        : SingleChildScrollView(
                            child: MataGlass(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                18,
                              ),
                              child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FieldLabel(text: 'Name'),
                                                                TextField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  style: MataText.body(
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
                                const SizedBox(height: 14),
                                _FieldLabel(text: 'Email'),
                                                                TextField(
                                  controller: _emailController,
                                  readOnly: true,
                                  style: MataText.body(
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
                                const SizedBox(height: 14),
                                _FieldLabel(text: 'Date of Birth'),
                                                                InkWell(
                                  onTap: _selectDateOfBirth,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 13,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: brown.withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _dateOfBirth == null
                                                ? 'Select your date of birth'
                                                : _formatDate(_dateOfBirth!),
                                            style: MataText.body(
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
                                    style: MataText.body(
                                      color: const Color(0xFFB71616),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                MataButton(
                                  label: 'Save Changes',
                                  loading: _isSaving,
                                  onPressed: _isSaving ? null : _saveChanges,
                                ),
                              ],
                              ),
                            ),
                          ),
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

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return MataFields.light(hintText: hintText, suffixIcon: suffixIcon);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return MataLabel(text);
  }
}
