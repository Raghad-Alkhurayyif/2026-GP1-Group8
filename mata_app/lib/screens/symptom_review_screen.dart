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

  @override
  void initState() {
    super.initState();

    _symptoms = _buildReviewedSymptoms();
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

  void _removeSymptom(int index) {
    setState(() {
      _symptoms.removeAt(index);
    });
  }

  void _continue() {
    if (_symptoms.isEmpty) {
      return;
    }

    final updatedResult = Map<String, dynamic>.from(widget.extractionResult);

    updatedResult['symptoms'] = _symptoms
        .map(
          (symptom) => {
            'column': symptom.column,
            'matched_text': symptom.matchedText,
            'layer': symptom.layer,
            'display': symptom.displayName,
          },
        )
        .toList();

    updatedResult['negated'] = _buildUpdatedNegatedSymptoms();

    updatedResult['follow_up_answers'] = widget.followUpAnswers;

    updatedResult['original_description'] = widget.originalDescription;

    widget.onContinue(updatedResult);
  }

  List<dynamic> _buildUpdatedNegatedSymptoms() {
    final negated = <dynamic>[];

    final originalNegated = widget.extractionResult['negated'];

    if (originalNegated is List) {
      negated.addAll(originalNegated);
    }

    final existingColumns = negated
        .whereType<Map>()
        .map((item) => item['column']?.toString())
        .whereType<String>()
        .toSet();

    final confirmationAnswers = widget.followUpAnswers['confirmations'];

    if (confirmationAnswers is List) {
      for (final item in confirmationAnswers) {
        if (item is! Map || item['confirmed'] != false) {
          continue;
        }

        final column = item['column']?.toString();

        if (column == null ||
            column.isEmpty ||
            existingColumns.contains(column)) {
          continue;
        }

        negated.add({
          'column': column,
          'matched_text': item['matched_text']?.toString(),
          'layer': 'confirmation',
          'display': _formatColumnName(column),
        });

        existingColumns.add(column);
      }
    }

    return negated;
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
                  const SizedBox(height: 22),
                  _buildProgressIndicator(),
                  const SizedBox(height: 30),
                  Expanded(child: _buildSymptomList()),
                  const SizedBox(height: 12),
                  _buildContinueButton(),
                  const SizedBox(height: 14),
                  _buildEditButton(),
                  const SizedBox(height: 18),
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
          'We understand your\nsymptoms as...',
          style: GoogleFonts.reemKufi(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We identified the following symptoms from '
          'your description. Please review them and '
          'confirm that they are correct.',
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
    if (_symptoms.isEmpty) {
      return Center(
        child: Text(
          'No symptoms remain.\n'
          'Edit your description and try again.',
          textAlign: TextAlign.center,
          style: GoogleFonts.reemKufi(
            color: brown,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      itemCount: _symptoms.length,
      separatorBuilder: (_, _) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        final symptom = _symptoms[index];

        return Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.only(left: 20, right: 8),
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
          child: Row(
            children: [
              Expanded(
                child: Text(
                  symptom.displayName,
                  style: GoogleFonts.reemKufi(
                    color: brown,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  _removeSymptom(index);
                },
                tooltip: 'Remove symptom',
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF554B47),
                  size: 28,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _symptoms.isEmpty ? null : _continue,
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
