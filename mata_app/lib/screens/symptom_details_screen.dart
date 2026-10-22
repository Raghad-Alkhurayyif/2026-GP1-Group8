import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'symptom_completion_screen.dart';

class SymptomDetailsScreen extends StatefulWidget {
  const SymptomDetailsScreen({
    super.key,
    required this.symptoms,
    required this.modifiers,
    required this.onFinish,
  });

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
  static const darkBrown = Color(0xFF5C3F38);
  static const softBeige = Color(0xFFF7F3EB);
  static const borderColor = Color(0xFFDCCDB5);

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
        MaterialPageRoute(builder: (_) => const SymptomCompletionScreen()),
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
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFF0EBE6) : Colors.white,
        foregroundColor: darkBrown,
        side: BorderSide(
          color: selected ? darkBrown : borderColor,
          width: selected ? 2 : 1,
        ),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.reemKufi(fontSize: 13),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.reemKufi(
          fontSize: 17,
          color: darkBrown,
          fontWeight: FontWeight.w700,
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/mata_logo.png',
                width: 90,
                height: 48,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
              Text(
                'Symptom Details',
                style: GoogleFonts.reemKufi(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: darkBrown,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Symptom ${_index + 1} of ${_symptoms.length}',
                style: GoogleFonts.reemKufi(color: brown, fontSize: 13),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_index + 1) / _symptoms.length,
                color: brown,
                backgroundColor: borderColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      _displayName,
                      style: GoogleFonts.reemKufi(
                        color: darkBrown,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'All details are optional. '
                      'Review or change any information '
                      'we found in your description.',
                      style: GoogleFonts.reemKufi(color: brown, fontSize: 13),
                    ),

                    _sectionTitle('Severity'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in [
                          ('Mild', 'low'),
                          ('Moderate', 'moderate'),
                          ('Severe', 'high'),
                        ])
                          _choice(
                            label: option.$1,
                            selected: _severity == option.$2,
                            onTap: () => setState(() => _severity = option.$2),
                          ),
                        _choice(
                          label: 'Skip',
                          selected: _severity == null,
                          onTap: () => setState(() => _severity = null),
                        ),
                      ],
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
                            decoration: InputDecoration(
                              hintText: 'e.g. 3',
                              filled: true,
                              fillColor: Colors.white,
                              errorText: _durationValid
                                  ? null
                                  : 'Invalid number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _durationUnit,
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
                        style: GoogleFonts.reemKufi(fontSize: 12, color: brown),
                      ),
                    ],
                    if (_durationHours() != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Stored as: ${_formatNumber(_durationHours()!)} hours',
                        style: GoogleFonts.reemKufi(fontSize: 12, color: brown),
                      ),
                    ],

                    _sectionTitle('Onset'),
                    Wrap(
                      spacing: 8,
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
                          label: 'Skip',
                          selected: _onset == null,
                          onTap: () => setState(() => _onset = null),
                        ),
                      ],
                    ),

                    _sectionTitle('Progression'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
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
                          label: 'Skip',
                          selected: _progression == null,
                          onTap: () => setState(() => _progression = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _back,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving || !_durationValid ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBrown,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _saving
                            ? 'Saving...'
                            : _index == _symptoms.length - 1
                            ? 'Finish'
                            : 'Next Symptom',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
