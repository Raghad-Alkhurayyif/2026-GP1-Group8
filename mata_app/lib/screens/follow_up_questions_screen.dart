import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/sos_button.dart';

import 'package:flutter/services.dart';

class FollowUpQuestionsScreen extends StatefulWidget {
  const FollowUpQuestionsScreen({
    super.key,
    required this.extractionResult,
    required this.onContinue,
  });

  final Map<String, dynamic> extractionResult;

  final ValueChanged<Map<String, dynamic>> onContinue;

  @override
  State<FollowUpQuestionsScreen> createState() =>
      _FollowUpQuestionsScreenState();
}

class _FollowUpQuestionsScreenState extends State<FollowUpQuestionsScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color borderColor = Color(0xFFDCCDB5);

  late final List<_FollowUpQuestion> _questions;

  final Map<String, String> _selectedAnswers = {};
  final TextEditingController _otherPersonAgeController =
      TextEditingController();

  bool get _isForOtherPerson {
    return _selectedAnswers['confirm_subject'] == 'yes';
  }

  bool get _isOtherPersonAgeValid {
    if (!_isForOtherPerson) {
      return true;
    }

    final age = int.tryParse(_otherPersonAgeController.text.trim());

    return age != null && age >= 0 && age <= 120;
  }

  @override
  void initState() {
    super.initState();

    _questions = _buildQuestions(widget.extractionResult);
  }

  @override
  void dispose() {
    _otherPersonAgeController.dispose();
    super.dispose();
  }

  bool get _allQuestionsAnswered {
    final allAnswersSelected =
        _questions.isEmpty || _selectedAnswers.length == _questions.length;

    return allAnswersSelected && _isOtherPersonAgeValid;
  }

  void _continue() {
    if (!_allQuestionsAnswered) {
      return;
    }

    final clarificationAnswers = <Map<String, dynamic>>[];
    final confirmationAnswers = <Map<String, dynamic>>[];

    bool? symptomsBelongToUser;

    for (final question in _questions) {
      final answer = _selectedAnswers[question.id];

      if (answer == null) {
        continue;
      }

      switch (question.type) {
        case _QuestionType.clarify:
          clarificationAnswers.add({
            'matched_text': question.matchedText,
            'selected_column': answer,
          });
          break;

        case _QuestionType.confirm:
          confirmationAnswers.add({
            'column': question.column,
            'confirmed': answer == 'yes',
          });
          break;

        case _QuestionType.confirmSubject:
          symptomsBelongToUser = answer == 'no';
          break;
      }
    }

    widget.onContinue({
      'clarifications': clarificationAnswers,
      'confirmations': confirmationAnswers,
      'confirm_subject': symptomsBelongToUser,
      'subject_age': _isForOtherPerson
          ? int.parse(_otherPersonAgeController.text.trim())
          : null,
    });
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
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildTitle(),
                  const SizedBox(height: 24),
                  _buildProgressIndicator(),
                  const SizedBox(height: 28),
                  Expanded(child: _buildQuestionList()),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SosButton(onTap: () {}),
                  ),
                  const SizedBox(height: 18),
                  _buildContinueButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
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
          Positioned(
            left: 0,
            bottom: 0,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: brown,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              label: Text(
                'Back',
                style: GoogleFonts.reemKufi(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few more details',
          style: GoogleFonts.reemKufi(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Help us understand your symptoms better.',
          style: GoogleFonts.reemKufi(
            color: brown,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _progressLine(color: brown)),
            const SizedBox(width: 7),
            Expanded(child: _progressLine(color: const Color(0xFFE7E1DA))),
            const SizedBox(width: 7),
            Expanded(child: _progressLine(color: const Color(0xFFE7E1DA))),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Step 1 of 3',
          style: GoogleFonts.reemKufi(
            color: brown,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _progressLine({required Color color}) {
    return Container(
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildQuestionList() {
    if (_questions.isEmpty) {
      return Center(
        child: Text(
          'No additional details are needed.',
          textAlign: TextAlign.center,
          style: GoogleFonts.reemKufi(
            color: brown,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
      itemCount: _questions.length,
      separatorBuilder: (_, _) {
        return const SizedBox(height: 22);
      },
      itemBuilder: (context, index) {
        return _buildQuestionCard(_questions[index]);
      },
    );
  }

  Widget _buildQuestionCard(_FollowUpQuestion question) {
    final isYesNoQuestion =
        question.options.length == 2 &&
        question.options.any((option) => option.value == 'yes') &&
        question.options.any((option) => option.value == 'no');

    final showAgeField =
        question.type == _QuestionType.confirmSubject && _isForOtherPerson;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 22),
      decoration: BoxDecoration(
        color: softBeige,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              question.question,
              style: GoogleFonts.reemKufi(
                color: const Color(0xFF6A211A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isYesNoQuestion)
            Row(
              children: question.options.map((option) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _buildOptionButton(
                      question: question,
                      option: option,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Column(
              children: question.options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildOptionButton(question: question, option: option),
                );
              }).toList(),
            ),
          if (showAgeField) ...[
            const SizedBox(height: 16),
            _buildOtherPersonAgeField(),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    required _FollowUpQuestion question,
    required _QuestionOption option,
  }) {
    final isSelected = _selectedAnswers[question.id] == option.value;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedAnswers[question.id] = option.value;
          });
        },
        style: ElevatedButton.styleFrom(
          elevation: isSelected ? 1 : 3,
          backgroundColor: isSelected
              ? darkBrown.withValues(alpha: 0.10)
              : Colors.white,
          foregroundColor: darkBrown,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          side: BorderSide(
            color: isSelected ? darkBrown : borderColor,
            width: isSelected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          style: GoogleFonts.reemKufi(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildOtherPersonAgeField() {
    return TextField(
      controller: _otherPersonAgeController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      onChanged: (_) {
        setState(() {});
      },
      style: GoogleFonts.reemKufi(color: darkBrown, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Their age',
        hintText: 'Enter age',
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: darkBrown, width: 2),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _allQuestionsAnswered ? _continue : null,
        style: ElevatedButton.styleFrom(
          elevation: 5,
          backgroundColor: darkBrown,
          disabledBackgroundColor: darkBrown.withValues(alpha: 0.45),
          foregroundColor: softBeige,
          disabledForegroundColor: softBeige.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          'Continue',
          style: GoogleFonts.reemKufi(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<_FollowUpQuestion> _buildQuestions(Map<String, dynamic> result) {
    final questions = <_FollowUpQuestion>[];

    final rawClarifications = result['clarify'];

    if (rawClarifications is List) {
      for (var index = 0; index < rawClarifications.length; index++) {
        final rawQuestion = rawClarifications[index];

        if (rawQuestion is! Map) {
          continue;
        }

        final candidates = _stringList(rawQuestion['candidates']);

        final candidateDisplays = _stringList(
          rawQuestion['candidate_displays'],
        );

        if (candidates.isEmpty) {
          continue;
        }

        final options = <_QuestionOption>[];

        for (
          var optionIndex = 0;
          optionIndex < candidates.length;
          optionIndex++
        ) {
          final label = optionIndex < candidateDisplays.length
              ? candidateDisplays[optionIndex]
              : candidates[optionIndex];

          options.add(
            _QuestionOption(value: candidates[optionIndex], label: label),
          );
        }

        final matchedText = rawQuestion['matched_text']?.toString();

        questions.add(
          _FollowUpQuestion(
            id: 'clarify_$index',
            type: _QuestionType.clarify,
            question:
                rawQuestion['question']?.toString() ??
                'Which option best describes '
                    '"${matchedText ?? 'this symptom'}"?',
            options: options,
            matchedText: matchedText,
          ),
        );
      }
    }

    final seenConfirmationColumns = <String>{};
    final rawConfirmations = result['confirm'];

    if (rawConfirmations is List) {
      for (var index = 0; index < rawConfirmations.length; index++) {
        final rawQuestion = rawConfirmations[index];

        if (rawQuestion is! Map) {
          continue;
        }

        final column = rawQuestion['column']?.toString();

        if (column == null ||
            column.trim().isEmpty ||
            !seenConfirmationColumns.add(column)) {
          continue;
        }
        final matchedText = rawQuestion['matched_text']?.toString();

        questions.add(
          _FollowUpQuestion(
            id: 'confirm_$index',
            type: _QuestionType.confirm,
            question:
                rawQuestion['question']?.toString() ??
                'Are you experiencing '
                    '"${matchedText ?? column}"?',
            options: const [
              _QuestionOption(value: 'yes', label: 'Yes'),
              _QuestionOption(value: 'no', label: 'No'),
            ],
            column: column,
            matchedText: matchedText,
          ),
        );
      }
    }

    if (result['confirm_subject'] == true) {
      questions.add(
        const _FollowUpQuestion(
          id: 'confirm_subject',
          type: _QuestionType.confirmSubject,
          question: 'Are you completing this assessment for someone else?',
          options: [
            _QuestionOption(value: 'yes', label: 'Yes'),
            _QuestionOption(value: 'no', label: 'No'),
          ],
        ),
      );
    }

    return questions;
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}

enum _QuestionType { clarify, confirm, confirmSubject }

class _FollowUpQuestion {
  const _FollowUpQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    this.column,
    this.matchedText,
  });

  final String id;
  final _QuestionType type;
  final String question;
  final List<_QuestionOption> options;
  final String? column;
  final String? matchedText;
}

class _QuestionOption {
  const _QuestionOption({required this.value, required this.label});

  final String value;
  final String label;
}
