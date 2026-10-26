import 'package:flutter/material.dart';

import '../theme/mata_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/stroke_background.dart';

import 'package:flutter/services.dart';

class FollowUpQuestionsScreen extends StatefulWidget {
  const FollowUpQuestionsScreen({
    super.key,
    required this.extractionResult,
    required this.onContinue,
    this.forSomeoneElse = false,
  });

  // True when the user already said the assessment is for someone else.
  final bool forSomeoneElse;

  final Map<String, dynamic> extractionResult;

  final ValueChanged<Map<String, dynamic>> onContinue;

  @override
  State<FollowUpQuestionsScreen> createState() =>
      _FollowUpQuestionsScreenState();
}

class _FollowUpQuestionsScreenState extends State<FollowUpQuestionsScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color softBeige = Color(0xFFF7F3EB);

  late final List<_FollowUpQuestion> _questions;

  final Map<String, String> _selectedAnswers = {};

  // "Which kind?" questions take several answers: each option is its own
  // yes/no symptom in the dataset, so "burning" and "lower" can both be true.
  final Map<String, Set<String>> _multiAnswers = {};
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
    final requiredQuestionsAnswered = _questions
        .where((question) => question.type != _QuestionType.clarify)
        .every((question) => _selectedAnswers.containsKey(question.id));

    return requiredQuestionsAnswered && _isOtherPersonAgeValid;
  }

  void _continue() {
    if (!_allQuestionsAnswered) {
      return;
    }

    final clarificationAnswers = <Map<String, dynamic>>[];

    bool? symptomsBelongToUser;

    for (final question in _questions) {
      if (question.type == _QuestionType.clarify) {
        for (final column in _multiAnswers[question.id] ?? const <String>{}) {
          clarificationAnswers.add({
            'matched_text': question.matchedText,
            'selected_column': column,
          });
        }
        continue;
      }

      final answer = _selectedAnswers[question.id];

      if (answer == null) {
        continue;
      }

      switch (question.type) {
        case _QuestionType.clarify:
          break; // answered above, with several choices

        case _QuestionType.confirmSubject:
          symptomsBelongToUser = answer == 'no';
          break;
      }
    }

    widget.onContinue({
      'clarifications': clarificationAnswers,
      // Presence is confirmed on the review screen now; kept empty so the
      // answers keep the shape the review screen reads.
      'confirmations': <Map<String, dynamic>>[],
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
          const StrokeBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 10),
                  _buildProgressIndicator(),
                  const SizedBox(height: 10),
                  _buildTitle(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildQuestionList()),
                  const SizedBox(height: 12),
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
      width: double.infinity,
      height: 92,
      child: Stack(
        // The logo is nudged up and left into the screen margin, past this
        // header's edges. Clipping it there cut off its left tail and top.
        clipBehavior: Clip.none,
        children: [
          const MataCornerLogo(),
          Positioned(
            right: 0,
            top: -2,
            child: SosButton(onTap: () {}),
          ),
          Positioned(
            left: 0,
            bottom: 4,
            child: MataBackButton(
              onTap: () {
                Navigator.of(context).pop();
              },
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
        Text('A few more details', style: MataText.display(fontSize: 26)),
        const SizedBox(height: 6),
        Text(
          widget.forSomeoneElse
              ? 'Help us understand their symptoms better.'
              : 'Help us understand your symptoms better.',
          style: MataText.body(
            color: MataColors.muted,
            fontSize: 13.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final segments = <Widget>[];

    for (var step = 1; step <= 3; step++) {
      if (segments.isNotEmpty) {
        segments.add(const SizedBox(width: 4));
      }

      segments.add(
        _progressLine(
          color: step <= 1
              ? MataColors.brown
              : MataColors.brown.withValues(alpha: 0.22),
        ),
      );
    }

    return Row(
      children: [
        ...segments,
        const SizedBox(width: 10),
        Text(
          'STEP 1 OF 3',
          style: MataText.body(
            color: MataColors.faint,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _progressLine({required Color color}) {
    return Container(
      width: 22,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildQuestionList() {
    if (_questions.isEmpty) {
      return Center(
        child: Text(
          'No additional details are needed.',
          textAlign: TextAlign.center,
          style: MataText.body(
            color: MataColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      itemCount: _questions.length,
      separatorBuilder: (_, _) {
        return const SizedBox(height: 14);
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

    return MataGlass(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: MataText.body(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          // Which words this question comes from, so someone who described
          // two similar symptoms knows which one is being asked about.
          if (question.type == _QuestionType.clarify) ...[
            const SizedBox(height: 4),
            Text(
              (question.matchedText?.trim().isNotEmpty ?? false)
                  ? 'From what you wrote: “${question.matchedText!.trim()}”. '
                        'Choose all that apply.'
                  : 'Choose all that apply.',
              style: MataText.body(
                color: MataColors.faint,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isYesNoQuestion)
            Row(
              children: [
                for (var i = 0; i < question.options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _buildOptionButton(
                      question: question,
                      option: question.options[i],
                    ),
                  ),
                ],
              ],
            )
          else
            Column(
              children: question.options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildOptionButton(question: question, option: option),
                );
              }).toList(),
            ),
          if (showAgeField) ...[
            const SizedBox(height: 14),
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
    final isMulti = question.type == _QuestionType.clarify;
    final isSelected = isMulti
        ? (_multiAnswers[question.id]?.contains(option.value) ?? false)
        : _selectedAnswers[question.id] == option.value;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isMulti) {
            final chosen = _multiAnswers.putIfAbsent(
              question.id,
              () => <String>{},
            );
            if (!chosen.remove(option.value)) {
              chosen.add(option.value);
            }
          } else {
            _selectedAnswers[question.id] = option.value;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? brown.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? brown : brown.withValues(alpha: 0.18),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          style: MataText.body(
            color: isSelected ? brown : MataColors.ink,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildOtherPersonAgeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MataLabel('Their age'),
        TextField(
          controller: _otherPersonAgeController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: (_) {
            setState(() {});
          },
          style: MataText.body(fontSize: 15),
          decoration: MataFields.light(hintText: 'Enter age'),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return MataButton(
      label: 'Continue',
      onPressed: _allQuestionsAnswered ? _continue : null,
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

// "Is this symptom present?" is not asked here: the review screen confirms
// every finding, so asking it twice was redundant.
enum _QuestionType { clarify, confirmSubject }

class _FollowUpQuestion {
  const _FollowUpQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    this.matchedText,
  });

  final String id;
  final _QuestionType type;
  final String question;
  final List<_QuestionOption> options;
  final String? matchedText;
}

class _QuestionOption {
  const _QuestionOption({required this.value, required this.label});

  final String value;
  final String label;
}
