import 'package:flutter/material.dart';

import '../theme/mata_theme.dart';
import '../widgets/sos_button.dart';
import '../widgets/stroke_background.dart';

class SymptomReviewScreen extends StatefulWidget {
  const SymptomReviewScreen({
    super.key,
    required this.originalDescription,
    required this.extractionResult,
    required this.followUpAnswers,
    required this.currentStep,
    required this.totalSteps,
    required this.onContinue,
    required this.onEditDescription,
  });
  final String originalDescription;
  final Map<String, dynamic> extractionResult;
  final Map<String, dynamic> followUpAnswers;
  final int currentStep;
  final int totalSteps;

  final ValueChanged<Map<String, dynamic>> onContinue;
  final VoidCallback onEditDescription;

  @override
  State<SymptomReviewScreen> createState() => _SymptomReviewScreenState();
}

class _SymptomReviewScreenState extends State<SymptomReviewScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);

  late final List<_ReviewedSymptom> _symptoms;
  late final List<_ReviewedSymptom> _deniedSymptoms;
  late final List<_ReviewedSymptom> _conflictingSymptoms;
  late final List<_ReviewedSymptom> _setAsideSymptoms;
  late final List<_ReviewedSymptom> _possibleSymptoms;

  // True when the user said the assessment is for someone else, so every
  // line on this screen talks about "they", not "you".
  bool get _forSomeoneElse => widget.extractionResult['subject'] == 'other';

// true = user confirms the symptom is present
// false = user confirms the symptom is absent
// null/missing = user has not answered yet
  final Map<String, bool> _decisions = {};

  bool get _allReviewed {
    final all = [
      ..._symptoms,
      ..._deniedSymptoms,
      ..._conflictingSymptoms,
      ..._setAsideSymptoms,
      ..._possibleSymptoms,
    ];
    return all.every(
          (symptom) => _decisions.containsKey(symptom.column),
    );
  }

  @override
  void initState() {
    super.initState();

    _symptoms = _buildReviewedSymptoms();
    _deniedSymptoms = _buildDeniedSymptoms();

    final positiveColumns = _symptoms.map((s) => s.column).toSet();

    final negativeColumns = <String>{};

    final originalNegated = widget.extractionResult['negated'];

    if (originalNegated is List) {
      for (final item in originalNegated) {
        if (item is Map && item['column'] != null) {
          negativeColumns.add(item['column'].toString());
        }
      }
    }

    final conflicts = positiveColumns.intersection(negativeColumns);

    _conflictingSymptoms = _symptoms
        .where((s) => conflicts.contains(s.column))
        .toList();

    _symptoms.removeWhere(
          (s) => conflicts.contains(s.column),
    );

    _deniedSymptoms.removeWhere(
          (s) => conflicts.contains(s.column),
    );

    final reviewedColumns = {
      ..._symptoms.map((s) => s.column),
      ..._deniedSymptoms.map((s) => s.column),
      ..._conflictingSymptoms.map((s) => s.column),
    };

    _setAsideSymptoms = _buildSetAsideSymptoms()
        .where((s) => !reviewedColumns.contains(s.column))
        .toList();

    reviewedColumns.addAll(_setAsideSymptoms.map((s) => s.column));

    // Mentioned only as a possibility ("I might have a cough"). Asked here
    // instead of on a page of their own before this one.
    _possibleSymptoms = _buildItems(widget.extractionResult['confirm'])
        .where((s) => !reviewedColumns.contains(s.column))
        .toList();

    // Start from what the model understood, so the user only has to change
    // what is wrong. Conflicting, set-aside and possible symptoms stay
    // unanswered: the model has no reading to offer for those.
    for (final symptom in _symptoms) {
      _decisions[symptom.column] = true;
    }
    for (final symptom in _deniedSymptoms) {
      _decisions[symptom.column] = false;
    }
  }

  // Findings left out because they seem to belong to the other person.
  // Shown so the user can correct us, never dropped silently.
  List<_ReviewedSymptom> _buildSetAsideSymptoms() =>
      _buildItems(widget.extractionResult['set_aside']);

  List<_ReviewedSymptom> _buildItems(dynamic items) {
    final setAside = <_ReviewedSymptom>[];
    final seenColumns = <String>{};

    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;

        final column = item['column']?.toString();

        if (column == null || column.isEmpty || !seenColumns.add(column)) {
          continue;
        }

        setAside.add(
          _ReviewedSymptom(
            column: column,
            displayName: _displayNameFromItem(item, column),
            matchedText: item['matched_text']?.toString(),
            layer: item['layer']?.toString(),
          ),
        );
      }
    }

    return setAside;
  }

  List<_ReviewedSymptom> _buildReviewedSymptoms() {
    final symptoms = <_ReviewedSymptom>[];
    final seenColumns = <String>{};

    final extractedSymptoms = widget.extractionResult['symptoms'];

    if (extractedSymptoms is List) {
      for (final item in extractedSymptoms) {
        if (item is! Map) {
          continue;
        }

        final column = item['column']?.toString();

        if (column == null || column.isEmpty || seenColumns.contains(column)) {
          continue;
        }

        symptoms.add(
          _ReviewedSymptom(
            column: column,
            displayName: _displayNameFromItem(item, column),
            matchedText: item['matched_text']?.toString(),
            layer: item['layer']?.toString(),
          ),
        );

        seenColumns.add(column);
      }
    }

    final clarificationAnswers = widget.followUpAnswers['clarifications'];

    if (clarificationAnswers is List) {
      for (final item in clarificationAnswers) {
        if (item is! Map) {
          continue;
        }

        final column = item['selected_column']?.toString();

        if (column == null || column.isEmpty || seenColumns.contains(column)) {
          continue;
        }

        symptoms.add(
          _ReviewedSymptom(
            column: column,
            displayName: _formatColumnName(column),
            matchedText: item['matched_text']?.toString(),
            layer: 'confirmation',
          ),
        );

        seenColumns.add(column);
      }
    }

    final confirmationAnswers = widget.followUpAnswers['confirmations'];

    if (confirmationAnswers is List) {
      for (final item in confirmationAnswers) {
        if (item is! Map || item['confirmed'] != true) {
          continue;
        }

        final column = item['column']?.toString();

        if (column == null || column.isEmpty || seenColumns.contains(column)) {
          continue;
        }

        symptoms.add(
          _ReviewedSymptom(
            column: column,
            displayName: _formatColumnName(column),
            layer: 'confirmation',
          ),
        );

        seenColumns.add(column);
      }
    }

    return symptoms;
  }


  List<_ReviewedSymptom> _buildDeniedSymptoms() {
    final denied = <_ReviewedSymptom>[];

    // Might contains contradictory positive and negative findings.
    final seenColumns = <String>{};

    void addDenied({
      required String column,
      String? matchedText,
      String? layer,
      String? displayName,
    }) {
      if (column.isEmpty || seenColumns.contains(column)) {
        return;
      }

      denied.add(
        _ReviewedSymptom(
          column: column,
          displayName: displayName ?? _formatColumnName(column),
          matchedText: matchedText,
          layer: layer,
        ),
      );

      seenColumns.add(column);
    }

    // Findings explicitly negated by the NLP pipeline.
    final extractedNegated = widget.extractionResult['negated'];

    if (extractedNegated is List) {
      for (final item in extractedNegated) {
        if (item is! Map) continue;

        final column = item['column']?.toString() ?? '';

        addDenied(
          column: column,
          matchedText: item['matched_text']?.toString(),
          layer: item['layer']?.toString(),
          displayName: _displayNameFromItem(item, column),
        );
      }
    }

    // Findings rejected during the preceding follow-up screen.
    final confirmationAnswers =
    widget.followUpAnswers['confirmations'];

    if (confirmationAnswers is List) {
      for (final item in confirmationAnswers) {
        if (item is! Map || item['confirmed'] != false) {
          continue;
        }

        addDenied(
          column: item['column']?.toString() ?? '',
          matchedText: item['matched_text']?.toString(),
          layer: 'confirmation',
        );
      }
    }

    return denied;
  }


  String _displayNameFromItem(Map<dynamic, dynamic> item, String fallback) {
    final display = item['display'];

    if (display is String && display.trim().isNotEmpty) {
      return display;
    }

    return _formatColumnName(fallback);
  }

  String _formatColumnName(String value) {
    final cleaned = value.replaceAll('_', ' ').trim();

    if (cleaned.isEmpty) {
      return value;
    }

    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }



  void _continue() {
    if (!_allReviewed) return;

    final allSymptoms = [
      ..._symptoms,
      ..._deniedSymptoms,
      ..._conflictingSymptoms,
      ..._setAsideSymptoms,
      ..._possibleSymptoms,
    ];

    Map<String, dynamic> toJson(
        _ReviewedSymptom symptom,
        bool confirmedPresent,
        ) {
      return {
        'column': symptom.column,
        'matched_text': symptom.matchedText,
        'layer': symptom.layer,
        'display': symptom.displayName,
        'user_confirmed': true,
        'confirmed_present': confirmedPresent,
      };
    }

    final confirmedPresent = <Map<String, dynamic>>[];
    final confirmedAbsent = <Map<String, dynamic>>[];

    for (final symptom in allSymptoms) {
      final present = _decisions[symptom.column]!;

      if (present) {
        confirmedPresent.add(toJson(symptom, true));
      } else {
        confirmedAbsent.add(toJson(symptom, false));
      }
    }

    final updatedResult =
    Map<String, dynamic>.from(widget.extractionResult);

    // Keep the original NLP result for future comparison.
    updatedResult['original_extraction'] = {
      'symptoms': widget.extractionResult['symptoms'],
      'negated': widget.extractionResult['negated'],
    };

    // The corrected values become the authoritative result.
    updatedResult['symptoms'] = confirmedPresent;
    updatedResult['negated'] = confirmedAbsent;

    updatedResult['n_actionable'] = confirmedPresent.length;
    updatedResult['n_confirmed_absent'] = confirmedAbsent.length;

    updatedResult['follow_up_answers'] =
        widget.followUpAnswers;

    updatedResult['original_description'] =
        widget.originalDescription;

    widget.onContinue(updatedResult);
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
                  const SizedBox(height: 14),
                  Expanded(child: _buildSymptomList()),
                  const SizedBox(height: 12),
                  _buildContinueButton(),
                  const SizedBox(height: 10),
                  _buildEditButton(),
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
        Text(
          _forSomeoneElse
              ? 'Let’s confirm their symptoms'
              : 'Let’s confirm your symptoms',
          style: MataText.display(fontSize: 26),
        ),
        const SizedBox(height: 6),
        Text(
          'Please review both the symptoms we detected '
          'and those we understood as denied. '
          'Correct anything that is not accurate.',
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

    for (var step = 1; step <= widget.totalSteps; step++) {
      if (segments.isNotEmpty) {
        segments.add(const SizedBox(width: 4));
      }

      segments.add(
        _progressLine(
          color: step <= widget.currentStep
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
          'STEP ${widget.currentStep} OF ${widget.totalSteps}',
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

  Widget _buildSymptomList() {
    if (_symptoms.isEmpty &&
        _deniedSymptoms.isEmpty &&
        _conflictingSymptoms.isEmpty &&
        _setAsideSymptoms.isEmpty &&
        _possibleSymptoms.isEmpty) {
      return Center(
        child: Text(
          'No symptoms were identified.\n'
          'Edit your description and try again.',
          textAlign: TextAlign.center,
          style: MataText.body(
            color: MataColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: true,
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      children: [
        if (_symptoms.isNotEmpty)
          _buildSection(
            dot: brown,
            title: 'Detected Symptoms',
            description: _forSomeoneElse
                ? 'Are they currently experiencing these symptoms?'
                : 'Are you currently experiencing these symptoms?',
            symptoms: _symptoms,
            isOriginallyDenied: false,
          ),

        if (_deniedSymptoms.isNotEmpty)
          _buildSection(
            dot: const Color(0xFF9C8B80),
            title: 'Symptoms Understood as Denied',
            description: _forSomeoneElse
                ? 'We understood that they do not have these '
                    'symptoms. Please correct us if this is wrong.'
                : 'We understood that you do not have these '
                    'symptoms. Please correct us if this is wrong.',
            symptoms: _deniedSymptoms,
            isOriginallyDenied: true,
          ),

        if (_conflictingSymptoms.isNotEmpty)
          _buildSection(
            dot: MataColors.amber,
            title: 'Symptoms Needing Clarification',
            description: _forSomeoneElse
                ? 'We found conflicting information about these '
                    'symptoms. Please tell us whether they currently '
                    'have them.'
                : 'We found conflicting information about these '
                    'symptoms. Please tell us whether you currently '
                    'have them.',
            symptoms: _conflictingSymptoms,
            isOriginallyDenied: false,
          ),

        if (_setAsideSymptoms.isNotEmpty)
          _buildSection(
            dot: const Color(0xFF9C8B80),
            title: widget.extractionResult['subject'] == 'other'
                ? 'Symptoms We Think Are Yours'
                : 'Symptoms We Think Belong to Someone Else',
            description: widget.extractionResult['subject'] == 'other'
                ? 'We left these out because they seem to be about you, '
                    'not the person you are assessing. Tell us if they '
                    'have them too.'
                : 'We left these out because they seem to be about '
                    'someone else. Tell us if you have them too.',
            symptoms: _setAsideSymptoms,
            isOriginallyDenied: false,
          ),

        if (_possibleSymptoms.isNotEmpty)
          _buildSection(
            dot: MataColors.amber,
            title: 'Symptoms Mentioned as Possible',
            description: _forSomeoneElse
                ? 'You mentioned these as a possibility. '
                    'Do they have them?'
                : 'You mentioned these as a possibility. '
                    'Do you have them?',
            symptoms: _possibleSymptoms,
            isOriginallyDenied: false,
          ),
      ],
    );
  }

  Widget _buildSection({
    required Color dot,
    required String title,
    required String description,
    required List<_ReviewedSymptom> symptoms,
    required bool isOriginallyDenied,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MataGlass(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: MataText.body(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: MataText.body(
                color: const Color(0xFF7A6458),
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < symptoms.length; i++)
              _buildReviewCard(
                symptom: symptoms[i],
                isOriginallyDenied: isOriginallyDenied,
                showDivider: i > 0,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required _ReviewedSymptom symptom,
    required bool isOriginallyDenied,
    bool showDivider = false,
  }) {
    final selected = _decisions[symptom.column];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(color: brown.withValues(alpha: 0.12)),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symptom.displayName,
                  style: MataText.body(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                if (symptom.matchedText != null)
                  Text(
                    '“${symptom.matchedText}”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MataText.body(
                      color: MataColors.faint,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: brown.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChoiceButton(
                  label: isOriginallyDenied
                      ? (_forSomeoneElse ? 'They have it' : 'I have it')
                      : 'Yes',
                  isSelected: selected == true,
                  onPressed: () {
                    setState(() {
                      _decisions[symptom.column] = true;
                    });
                  },
                ),
                _buildChoiceButton(
                  label: isOriginallyDenied
                      ? (_forSomeoneElse
                          ? "They don't have it"
                          : "I don't have it")
                      : 'No',
                  isSelected: selected == false,
                  onPressed: () {
                    setState(() {
                      _decisions[symptom.column] = false;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 46),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? MataColors.softWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: darkBrown.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: MataText.body(
            color: isSelected ? brown : const Color(0xFF7A6458),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return MataButton(
      label: 'Continue',
      onPressed: _allReviewed ? _continue : null,
    );
  }

  Widget _buildEditButton() {
    return MataButton(
      label: 'Edit my Description',
      style: MataButtonStyle.line,
      onPressed: widget.onEditDescription,
    );
  }
}

class _ReviewedSymptom {
  const _ReviewedSymptom({
    required this.column,
    required this.displayName,
    this.matchedText,
    this.layer,
  });

  final String column;
  final String displayName;
  final String? matchedText;
  final String? layer;
}
