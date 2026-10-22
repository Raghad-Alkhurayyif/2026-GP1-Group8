import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/symptom_api_service.dart';
import '../widgets/mata_bottom_navigation_bar.dart';
import '../widgets/sos_button.dart';
import 'account_screen.dart';
import 'follow_up_questions_screen.dart';
import 'symptom_review_screen.dart';
import '../services/assessment_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color red = Color(0xFFB71616);
  static const Color inputBackground = Color(0xFFF7F3EB);
  static const Color hintColor = Color(0xFF929292);

  final TextEditingController _symptomsController = TextEditingController();
  final AssessmentService _assessmentService = AssessmentService();

  bool _isSubmitting = false;
  bool _showError = false;

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _submitSymptoms() async {
    FocusScope.of(context).unfocus();

    final description = _symptomsController.text.trim();

    if (description.isEmpty) {
      setState(() {
        _showError = true;
      });
      return;
    }
    setState(() {
      _showError = false;
      _isSubmitting = true;
    });

    try {
      final submissionId = await _assessmentService.createSymptomSubmission(
        description: description,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalyzingScreen(
            description: description,
            submissionId: submissionId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The symptom description could not be saved. '
            'Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: inputBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 12),
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
                  const SizedBox(height: 40),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.reemKufi(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      children: const [
                        TextSpan(
                          text: "Tell us what you're\n",
                          style: TextStyle(color: Colors.black),
                        ),
                        TextSpan(
                          text: 'experiencing',
                          style: TextStyle(color: darkBrown),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Describe your symptoms in your own words.\n'
                    'Include what you feel, where you feel it, and any\n'
                    'other details you think are important.',
                    style: GoogleFonts.reemKufi(
                      color: brown,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    height: 265,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: inputBackground,
                            borderRadius: BorderRadius.circular(30),
                            border: _showError
                                ? Border.all(color: red, width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _symptomsController,
                            expands: true,
                            maxLines: null,
                            minLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            keyboardType: TextInputType.multiline,
                            onChanged: (value) {
                              if (_showError && value.trim().isNotEmpty) {
                                setState(() {
                                  _showError = false;
                                });
                              }
                            },
                            style: GoogleFonts.reemKufi(
                              color: darkBrown,
                              fontSize: 15,
                              height: 1.7,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  "For example: I've had a strong headache\n"
                                  'since this morning and I feel dizzy when I\n'
                                  'stand up...',
                              hintStyle: GoogleFonts.reemKufi(
                                color: hintColor,
                                fontSize: 14,
                                height: 1.8,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.fromLTRB(
                                28,
                                28,
                                28,
                                75,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 18,
                          bottom: 18,
                          child: SizedBox(
                            width: 130,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitSymptoms,
                              style: ElevatedButton.styleFrom(
                                elevation: 5,
                                backgroundColor: darkBrown,
                                foregroundColor: inputBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: inputBackground,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      'Submit',
                                      style: GoogleFonts.reemKufi(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 62,
                    child: _showError
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14, left: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: red,
                                  size: 25,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Symptoms required',
                                        style: GoogleFonts.reemKufi(
                                          color: red,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Please describe your symptoms '
                                        'before submitting.',
                                        style: GoogleFonts.reemKufi(
                                          color: red,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                  const Spacer(),
                  MataBottomNavigationBar(
                    currentIndex: 0,
                    onHomeTap: () {},
                    onHistoryTap: null,
                    onAccountTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccountScreen(),
                        ),
                      );
                    },
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

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.description,
    required this.submissionId,
  });

  final String description;
  final String submissionId;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color inputBackground = Color(0xFFF7F3EB);
  static const Color red = Color(0xFFB71616);

  final SymptomApiService _apiService = SymptomApiService();
  final AssessmentService _assessmentService = AssessmentService();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _analyzeSymptoms();
  }

  Future<void> _analyzeSymptoms() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await _apiService.extractSymptoms(widget.description);

      if (!mounted) {
        return;
      }
      if (!_hasRecognizedSymptoms(result)) {
        await _assessmentService.failSymptomSubmission(
          submissionId: widget.submissionId,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _errorMessage =
              'We couldn’t identify any symptoms. '
              'Please describe what you are experiencing '
              'and try again.';
        });
        return;
      }

      final hasFollowUpQuestions = _hasFollowUpQuestions(result);

      final description = widget.description;

      Route<void> buildReviewRoute(Map<String, dynamic> followUpAnswers) {
        return MaterialPageRoute(
          builder: (reviewContext) {
            return SymptomReviewScreen(
              originalDescription: description,
              extractionResult: result,
              followUpAnswers: followUpAnswers,
              currentStep: hasFollowUpQuestions ? 2 : 1,
              totalSteps: hasFollowUpQuestions ? 3 : 2,
              onEditDescription: () {
                Navigator.of(reviewContext).popUntil((route) => route.isFirst);
              },
              onContinue: (confirmedResult) async {
                try {
                  final isForCurrentUser =
                      followUpAnswers['confirm_subject'] != false;

                  final int subjectAge;

                  if (isForCurrentUser) {
                    subjectAge = await _assessmentService.getCurrentUserAge();
                  } else {
                    final savedAge = followUpAnswers['subject_age'];

                    if (savedAge is! int) {
                      throw StateError(
                        'The assessed person age was not found.',
                      );
                    }

                    subjectAge = savedAge;
                  }

                  await _assessmentService.completeSymptomSubmission(
                    submissionId: widget.submissionId,
                    symptoms: confirmedResult['symptoms'] as List? ?? [],
                    negatedSymptoms: confirmedResult['negated'] as List? ?? [],
                    isForCurrentUser: isForCurrentUser,
                    subjectAge: subjectAge,
                  );

                  if (!reviewContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(reviewContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Symptoms confirmed.',
                        style: GoogleFonts.reemKufi(),
                      ),
                    ),
                  );
                } catch (_) {
                  if (!reviewContext.mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(reviewContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'The symptoms could not be saved. Please try again.',
                        style: GoogleFonts.reemKufi(),
                      ),
                    ),
                  );
                }
              },
            );
          },
        );
      }

      if (hasFollowUpQuestions) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (questionsContext) {
              return FollowUpQuestionsScreen(
                extractionResult: result,
                onContinue: (answers) {
                  Navigator.of(questionsContext)
                      .push(buildReviewRoute(answers));
                },
              );
            },
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          buildReviewRoute(const {
            'clarifications': <Map<String, dynamic>>[],
            'confirmations': <Map<String, dynamic>>[],
            'confirm_subject': null,
          }),
        );
      }
    } catch (_) {
      try {
        await _assessmentService.failSymptomSubmission(
          submissionId: widget.submissionId,
        );
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'We could not analyze your symptoms. '
            'Make sure the server is running and try again.';
      });
    }
  }

  bool _hasRecognizedSymptoms(Map<String, dynamic> result) {
    const relevantFields = ['symptoms', 'negated', 'clarify', 'confirm'];

    return relevantFields.any((field) {
      final value = result[field];
      return value is List && value.isNotEmpty;
    });
  }

  bool _hasFollowUpQuestions(Map<String, dynamic> result) {
    final clarify = result['clarify'];
    final confirm = result['confirm'];

    final hasClarification = clarify is List && clarify.isNotEmpty;
    final hasConfirmation = confirm is List && confirm.isNotEmpty;
    final needsSubjectConfirmation = result['confirm_subject'] == true;

    return hasClarification || hasConfirmation || needsSubjectConfirmation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: inputBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 14, 30, 28),
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
                  const SizedBox(height: 35),
                  Text(
                    'Analyzing your\nsymptoms...',
                    style: GoogleFonts.reemKufi(
                      color: Colors.black,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Ma'ta is reviewing your symptoms "
                    'to prepare your assessment.',
                    style: GoogleFonts.reemKufi(
                      color: brown,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 60),
                  if (_errorMessage == null)
                    _buildLoadingContent()
                  else
                    _buildErrorContent(),
                  const Spacer(),
                ],
              ),
            ),
          ),
          Positioned(right: 28, bottom: 105, child: SosButton(onTap: () {})),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return Column(
      children: [
        const Center(
          child: SizedBox(
            width: 145,
            height: 145,
            child: CircularProgressIndicator(
              color: darkBrown,
              backgroundColor: Color(0xFFB8A79D),
              strokeWidth: 20,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
        const SizedBox(height: 55),
        Center(
          child: Text(
            'This usually takes a few seconds.\n'
            'Please don’t close the app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.reemKufi(
              color: brown,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: red, size: 54),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.reemKufi(
              color: red,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 150,
            height: 48,
            child: ElevatedButton(
              onPressed: _analyzeSymptoms,
              style: ElevatedButton.styleFrom(
                backgroundColor: darkBrown,
                foregroundColor: inputBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.reemKufi(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Back',
              style: GoogleFonts.reemKufi(
                color: brown,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
