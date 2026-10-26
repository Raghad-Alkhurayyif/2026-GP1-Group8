import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mata_theme.dart';
import '../widgets/severity_scale.dart';
import '../widgets/stroke_background.dart';
import 'symptom_completion_screen.dart';

class SymptomDetailsScreen extends StatefulWidget {
  const SymptomDetailsScreen({
    super.key,
    required this.symptoms,
    required this.modifiers,
    required this.onFinish,
    this.forSomeoneElse = false,
  });

  // True when the assessment is for someone other than the user.
  final bool forSomeoneElse;

  // Only user-confirmed PRESENT symptoms.
  final List<dynamic> symptoms;

  // Original modifiers returned by the NLP API.
  final List<dynamic> modifiers;

  // Save all details through the existing assessment service.
  final Future<void> Function(Map<String, Map<String, dynamic>> details)
  onFinish;

  @override
  State<SymptomDetailsScreen> createState() => _SymptomDetailsScreenState();
}

class _SymptomDetailsScreenState extends State<SymptomDetailsScreen> {
  static const brown = Color(0xFF79543B);
  static const softBeige = Color(0xFFF7F3EB);

  int _index = 0;
  bool _saving = false;

  final _durationController = TextEditingController();

  String? _severity;
  String? _onset;
  String? _progression;
  String _durationUnit = 'hours';
  String? _durationOriginalText;

  final Map<String, Map<String, dynamic>> _answers = {};

  late final List<Map<String, dynamic>> _symptoms;

  @override
  void initState() {
    super.initState();

    _symptoms = widget.symptoms
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .where((s) => (s['column']?.toString() ?? '').isNotEmpty)
        .toList();

    if (_symptoms.isNotEmpty) {
      _loadSymptom();
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  String get _column => _symptoms[_index]['column'].toString();

  String get _displayName {
    final symptom = _symptoms[_index];
    return (symptom['display'] ?? symptom['column']).toString();
  }

  Map<String, dynamic> _initialDetails(String column) {
    final details = <String, dynamic>{
      'severity': null,
      'duration': null,
      'onset': null,
      'progression': null,
      'durationText': null,
    };

    for (final raw in widget.modifiers) {
      if (raw is! Map || raw['column']?.toString() != column) {
        continue;
      }

      final kind = raw['kind']?.toString();
      final value = raw['value'];

      if (kind == 'severity' && value is String) {
        details['severity'] = value;
      } else if (kind == 'onset' && value is String) {
        details['onset'] = value;
      } else if (kind == 'progression' && value is String) {
        details['progression'] = value;
      } else if (kind == 'duration') {
        if (value is num && value.isFinite && value >= 0) {
          details['duration'] = value.toDouble();
        }
        details['durationText'] = raw['text']?.toString();
      }
    }

    return details;
  }

  void _loadSymptom() {
    final details = _answers[_column] ?? _initialDetails(_column);

    _severity = details['severity'] as String?;
    _onset = details['onset'] as String?;
    _progression = details['progression'] as String?;
    _durationOriginalText = details['durationText'] as String?;

    final duration = details['duration'];

    _durationUnit = 'hours';

    if (duration is num && duration.isFinite && duration >= 0) {
      final hours = duration.toDouble();

      // Choose a readable unit for existing NLP results.
      if (hours >= 168 && hours % 168 == 0) {
        _durationUnit = 'weeks';
        _durationController.text = (hours / 168).toStringAsFixed(0);
      } else if (hours >= 24 && hours % 24 == 0) {
        _durationUnit = 'days';
        _durationController.text = (hours / 24).toStringAsFixed(0);
      } else {
        _durationController.text = _formatNumber(hours);
      }
    } else {
      _durationController.clear();
    }
  }

  String _formatNumber(double number) {
    if (number == number.truncateToDouble()) {
      return number.toStringAsFixed(0);
    }
    return number.toString();
  }

  double? _durationHours() {
    final input = _durationController.text.trim();

    if (input.isEmpty) return null;

    final number = double.tryParse(input);
    if (number == null || !number.isFinite || number < 0) {
      return null;
    }

    final multiplier = switch (_durationUnit) {
      'weeks' => 168,
      'days' => 24,
      _ => 1,
    };

    final hours = number * multiplier;
    return hours.isFinite ? hours : null;
  }

  bool get _durationValid {
    final input = _durationController.text.trim();

    if (input.isEmpty) return true;

    return _durationHours() != null;
  }

  void _saveCurrent() {
    _answers[_column] = {
      'severity': _severity,
      'duration': _durationHours(),
      'onset': _onset,
      'progression': _progression,
      'durationText': _durationOriginalText,
    };
  }

  void _next() {
    if (!_durationValid) {
      _showMessage('Enter a valid duration or leave it empty.');
      return;
    }

    _saveCurrent();

    if (_index < _symptoms.length - 1) {
      setState(() {
        _index++;
        _loadSymptom();
      });
    } else {
      _finish();
    }
  }

  void _back() {
    if (_index == 0) {
      Navigator.of(context).pop();
      return;
    }

    if (!_durationValid) {
      _showMessage('Enter a valid duration or leave it empty.');
      return;
    }

    _saveCurrent();

    setState(() {
      _index--;
      _loadSymptom();
    });
  }

  Future<void> _finish() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      // Save the confirmed symptoms and details first.
      await widget.onFinish(_answers);

      if (!mounted) return;

      // Navigate to the temporary completion screen
      // only after Firestore saving succeeds.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SymptomCompletionScreen(
            forSomeoneElse: widget.forSomeoneElse,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'The symptom details could not be saved. '
        'Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? brown.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? brown : brown.withValues(alpha: 0.18),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: MataText.body(
            color: selected ? brown : MataColors.ink,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: MataText.body(
          fontSize: 11.5,
          color: MataColors.faint,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_symptoms.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No confirmed symptoms.')),
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
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      for (var i = 0; i < _symptoms.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Container(
                          width: 22,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _index
                                ? brown
                                : brown.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Text(
                        'SYMPTOM ${_index + 1} OF ${_symptoms.length}',
                        style: MataText.body(
                          color: MataColors.faint,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Symptom Details', style: MataText.display(fontSize: 26)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 10),
                      children: [
                        MataGlass(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: MataText.display(
                                  color: brown,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All details are optional. '
                                'Review or change any information '
                                'we found in your description.',
                                style: MataText.body(
                                  color: const Color(0xFF7A6458),
                                  fontSize: 12.5,
                                  height: 1.45,
                                ),
                              ),
                                _sectionTitle('Severity'),
                                SeverityScale(
                                  value: _severity,
                                  onChanged: (value) =>
                                      setState(() => _severity = value),
                                ),
                                const SizedBox(height: 12),
                                _choice(
                                  label: "I'm not sure",
                                  selected: _severity == null,
                                  onTap: () => setState(() => _severity = null),
                                ),

                                _sectionTitle('Duration'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _durationController,
                                        keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                        ],
                                        onChanged: (_) => setState(() {}),
                                        style: MataText.body(fontSize: 15),
                                        decoration: MataFields.light(hintText: 'e.g. 3')
                                            .copyWith(
                                              errorText: _durationValid
                                                  ? null
                                                  : 'Invalid number',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    DropdownButton<String>(
                                      value: _durationUnit,
                                      style: MataText.body(fontSize: 15),
                                      borderRadius: BorderRadius.circular(14),
                                      dropdownColor: MataColors.softWhite,
                                      underline: const SizedBox.shrink(),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'hours',
                                          child: Text('Hours'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'days',
                                          child: Text('Days'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'weeks',
                                          child: Text('Weeks'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _durationUnit = value;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                if (_durationOriginalText != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'Detected wording: $_durationOriginalText',
                                    style: MataText.body(fontSize: 12, color: MataColors.faint),
                                  ),
                                ],
                                if (_durationHours() != null) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'Stored as: ${_formatNumber(_durationHours()!)} hours',
                                    style: MataText.body(fontSize: 12, color: MataColors.faint),
                                  ),
                                ],

                                _sectionTitle('Onset'),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final option in [
                                      ('Sudden', 'sudden'),
                                      ('Gradual', 'gradual'),
                                    ])
                                      _choice(
                                        label: option.$1,
                                        selected: _onset == option.$2,
                                        onTap: () => setState(() => _onset = option.$2),
                                      ),
                                    _choice(
                                      label: "I'm not sure",
                                      selected: _onset == null,
                                      onTap: () => setState(() => _onset = null),
                                    ),
                                  ],
                                ),

                                _sectionTitle('Progression'),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final option in [
                                      ('Getting worse', 'worse'),
                                      ('Persistent', 'persistent'),
                                      ('Comes and goes', 'intermittent'),
                                      ('Getting better', 'better'),
                                    ])
                                      _choice(
                                        label: option.$1,
                                        selected: _progression == option.$2,
                                        onTap: () =>
                                            setState(() => _progression = option.$2),
                                      ),
                                    _choice(
                                      label: "I'm not sure",
                                      selected: _progression == null,
                                      onTap: () => setState(() => _progression = null),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: MataButton(
                          label: 'Back',
                          style: MataButtonStyle.line,
                          onPressed: _saving ? null : _back,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MataButton(
                          label: _saving
                              ? 'Saving...'
                              : _index == _symptoms.length - 1
                              ? 'Finish'
                              : 'Next Symptom',
                          onPressed: _saving || !_durationValid ? null : _next,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
