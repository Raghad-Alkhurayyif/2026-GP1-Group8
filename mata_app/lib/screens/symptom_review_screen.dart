import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/sos_button.dart';

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
  static const Color borderColor = Color(0xFFDCCDB5);

  late final List<_ReviewedSymptom> _symptoms;
  late final List<_ReviewedSymptom> _deniedSymptoms;
  late final List<_ReviewedSymptom> _conflictingSymptoms;

// true = user confirms the symptom is present
// false = user confirms the symptom is absent
// null/missing = user has not answered yet
  final Map<String, bool> _decisions = {};

  bool get _allReviewed {
    final all = [
      ..._symptoms,
      ..._deniedSymptoms,
      ..._conflictingSymptoms,
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
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 4),
                  _buildTitle(),
                  const SizedBox(height: 12),
                  _buildProgressIndicator(),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: _buildSymptomList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildContinueButton(),
                  const SizedBox(height: 6),
                  _buildEditButton(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SosButton(onTap: () {}),
                  ),
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
      height: 65,
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
          'Let’s confirm your\nsymptoms',
          style: GoogleFonts.reemKufi(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please review both the symptoms we detected '
              'and those we understood as denied. '
              'Correct anything that is not accurate.',
          style: GoogleFonts.reemKufi(
            color: brown,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.7,
          ),
        ),
      ],
    );
  }


  Widget _buildProgressIndicator() {
    final progressSegments = <Widget>[];

    for (var step = 1; step <= widget.totalSteps; step++) {
      if (progressSegments.isNotEmpty) {
        progressSegments.add(const SizedBox(width: 7));
      }

      progressSegments.add(
        Expanded(
          child: _progressLine(
            color: step <= widget.currentStep ? brown : const Color(0xFFE7E1DA),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: progressSegments),
        const SizedBox(height: 7),
        Text(
          'Step ${widget.currentStep} '
          'of ${widget.totalSteps}',
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


  Widget _buildSymptomList() {
    if (_symptoms.isEmpty &&
        _deniedSymptoms.isEmpty &&
        _conflictingSymptoms.isEmpty) {      return Center(
        child: Text(
          'No symptoms were identified.\n'
              'Edit your description and try again.',
          textAlign: TextAlign.center,
          style: GoogleFonts.reemKufi(
            color: brown,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      primary: true,
      padding: const EdgeInsets.symmetric(
        horizontal: 2,
        vertical: 4,
      ),
      children: [
        if (_symptoms.isNotEmpty) ...[
          Text(
            'Detected Symptoms',
            style: GoogleFonts.reemKufi(
              color: darkBrown,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Are you currently experiencing these symptoms?',
            style: GoogleFonts.reemKufi(
              color: brown,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          ..._symptoms.map(
                (symptom) => _buildReviewCard(
              symptom: symptom,
              isOriginallyDenied: false,
            ),
          ),
        ],

        if (_deniedSymptoms.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Symptoms Understood as Denied',
            style: GoogleFonts.reemKufi(
              color: darkBrown,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We understood that you do not have these '
                'symptoms. Please correct us if this is wrong.',
            style: GoogleFonts.reemKufi(
              color: brown,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),

          ..._deniedSymptoms.map(
                (symptom) => _buildReviewCard(
              symptom: symptom,
              isOriginallyDenied: true,
            ),
          ),
        ],

        if (_conflictingSymptoms.isNotEmpty) ...[
          const SizedBox(height: 24),

          Text(
            'Symptoms Needing Clarification',
            style: GoogleFonts.reemKufi(
              color: darkBrown,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'We found conflicting information about these '
                'symptoms. Please tell us whether you currently '
                'have them.',
            style: GoogleFonts.reemKufi(
              color: brown,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 14),

          ..._conflictingSymptoms.map(
                (symptom) => _buildReviewCard(
              symptom: symptom,
              isOriginallyDenied: false,
            ),
          ),
        ],

      ],
    );
  }

  Widget _buildReviewCard({
    required _ReviewedSymptom symptom,
    required bool isOriginallyDenied,
  }) {
    final selected = _decisions[symptom.column];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            symptom.displayName,
            style: GoogleFonts.reemKufi(
              color: brown,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  label: isOriginallyDenied
                      ? 'I have it'
                      : 'Yes',
                  isSelected: selected == true,
                  onPressed: () {
                    setState(() {
                      _decisions[symptom.column] = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceButton(
                  label: isOriginallyDenied
                      ? "I don't have it"
                      : 'No',
                  isSelected: selected == false,
                  onPressed: () {
                    setState(() {
                      _decisions[symptom.column] = false;
                    });
                  },
                ),
              ),
            ],
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor:
        isSelected ? const Color(0xFFF0EBE6) : Colors.white,
        foregroundColor: darkBrown,
        side: BorderSide(
          color: isSelected ? darkBrown : borderColor,
          width: isSelected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.reemKufi(
          fontSize: 12,
          fontWeight:
          isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }


  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _allReviewed ? _continue : null,
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

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: widget.onEditDescription,
        style: OutlinedButton.styleFrom(
          foregroundColor: brown,
          side: const BorderSide(color: brown, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: Text(
          'Edit my Description',
          style: GoogleFonts.reemKufi(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
