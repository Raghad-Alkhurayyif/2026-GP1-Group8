import 'package:flutter/material.dart';

import '../services/analysis_notice.dart';
import '../services/symptom_api_service.dart';
import '../theme/mata_theme.dart';
import '../widgets/analysis_notice_card.dart';
import '../widgets/road_scene.dart';
import '../widgets/stroke_background.dart';
import '../widgets/mata_bottom_navigation_bar.dart';
import '../widgets/sos_button.dart';
import 'account_screen.dart';
import 'follow_up_questions_screen.dart';
import 'symptom_review_screen.dart';
import '../services/assessment_service.dart';
import 'symptom_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color red = Color(0xFFB71616);
  static const Color inputBackground = Color(0xFFF7F3EB);

  final TextEditingController _symptomsController = TextEditingController();
  final AssessmentService _assessmentService = AssessmentService();

  bool _isSubmitting = false;
  bool _showError = false;

  // Why the last analysis could not go ahead. The description is kept so the
  // user can follow the suggestion and resubmit.
  AnalysisNotice? _notice;

  void _onAssessmentCompleted() {
    if (!mounted) return;
    setState(() {
      _symptomsController.clear();
      _notice = null;
    });
  }

  void _onAnalysisNotice(AnalysisNotice notice) {
    if (!mounted) return;
    setState(() => _notice = notice);
  }

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
      _notice = null;
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
            onCompleted: _onAssessmentCompleted,
            onNotice: _onAnalysisNotice,
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
          const StrokeBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 34),
                  RichText(
                    text: TextSpan(
                      style: MataText.display(fontSize: 30, height: 1.2),
                      children: const [
                        TextSpan(text: "Tell us what you're\n"),
                        TextSpan(
                          text: 'experiencing',
                          style: TextStyle(color: brown),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Describe your symptoms in your own words. '
                    'Include what you feel, where you feel it, and any '
                    'other details you think are important.',
                    style: MataText.body(
                      color: MataColors.muted,
                      fontSize: 14.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: _notice == null ? 230 : 178,
                    child: MataGlass(
                      glow: true,
                      radius: 26,
                      opacity: 0.72,
                      padding: EdgeInsets.zero,
                      borderColor: _showError ? red : null,
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
                        style: MataText.body(
                          color: MataColors.ink,
                          fontSize: 15,
                          height: 1.65,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              "For example: I've had a strong headache "
                              'since this morning and I feel dizzy when I '
                              'stand up...',
                          hintStyle: MataText.body(
                            color: MataColors.hint,
                            fontSize: 15,
                            height: 1.65,
                          ),
                          hintMaxLines: 4,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.fromLTRB(
                            20,
                            18,
                            20,
                            18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 14),
                      child: AnalysisNoticeCard(
                        notice: _notice!,
                        onDismiss: () => setState(() => _notice = null),
                      ),
                    )
                  else
                    SizedBox(
                      height: 46,
                      child: _showError
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12, left: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Symptoms required. ',
                                            style: MataText.body(
                                              color: red,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                'Please describe your symptoms '
                                                'before submitting.',
                                            style: MataText.body(
                                              color: red,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  MataButton(
                    label: 'Submit',
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submitSymptoms,
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
}

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    required this.description,
    required this.submissionId,
    required this.onCompleted,
    required this.onNotice,
  });

  final String description;
  final String submissionId;

  // Called once the whole assessment is saved, so home can clear the text.
  final VoidCallback onCompleted;

  // Called when the analysis cannot go ahead; home shows why.
  final void Function(AnalysisNotice notice) onNotice;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  static const Color brown = Color(0xFF79543B);
  static const Color inputBackground = Color(0xFFF7F3EB);
  static const Color red = Color(0xFFB71616);

  final SymptomApiService _apiService = SymptomApiService();
  final AssessmentService _assessmentService = AssessmentService();

  AnalysisNotice? _error;

  @override
  void initState() {
    super.initState();
    _analyzeSymptoms();
  }

  Future<void> _analyzeSymptoms() async {
    setState(() {
      _error = null;
    });

    // Held here because the closures below outlive this screen.
    final onCompleted = widget.onCompleted;
    final onNotice = widget.onNotice;

    try {
      final result = await _apiService.extractSymptoms(widget.description);

      if (!mounted) {
        return;
      }
      final notice = AnalysisNotice.fromExtraction(result, widget.description);

      if (notice != null) {
        await _assessmentService.failSymptomSubmission(
          submissionId: widget.submissionId,
        );

        if (!mounted) {
          return;
        }

        // Back to the description, with the reason and a suggestion.
        onNotice(notice);
        Navigator.of(context).pop();
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
                final presentSymptoms =
                    confirmedResult['symptoms'] as List? ?? [];

                final deniedSymptoms =
                    confirmedResult['negated'] as List? ?? [];

                final modifiers = result['modifiers'] as List? ?? [];

                Future<void> saveSubmission(
                  Map<String, Map<String, dynamic>> details,
                ) async {
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
                    symptoms: presentSymptoms,
                    negatedSymptoms: deniedSymptoms,
                    isForCurrentUser: isForCurrentUser,
                    subjectAge: subjectAge,
                    symptomDetails: details,
                  );
                }

                if (presentSymptoms.isEmpty) {
                  try {
                    await saveSubmission(<String, Map<String, dynamic>>{});

                    onNotice(AnalysisNotice.noneConfirmed);

                    if (reviewContext.mounted) {
                      Navigator.of(reviewContext)
                          .popUntil((route) => route.isFirst);
                    }
                  } catch (_) {
                    if (reviewContext.mounted) {
                      ScaffoldMessenger.of(reviewContext).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to save the symptom review.'),
                        ),
                      );
                    }
                  }
                  return;
                }

                if (!reviewContext.mounted) return;

                Navigator.of(reviewContext).push(
                  MaterialPageRoute(
                    builder: (_) => SymptomDetailsScreen(
                      symptoms: presentSymptoms,
                      modifiers: modifiers,
                      onFinish: (details) async {
                        await saveSubmission(details);
                        onCompleted();
                      },
                    ),
                  ),
                );
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
    } catch (error) {
      try {
        await _assessmentService.failSymptomSubmission(
          submissionId: widget.submissionId,
        );
      } catch (_) {}

      if (!mounted) {
        return;
      }

      setState(() {
        _error = AnalysisNotice.fromError(error);
      });
    }
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
          // the guiding path, its lights coming on one by one while we read
          const RoadScene(mood: RoadMood.analyzing),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MataCornerLogo(),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Analyzing your\nsymptoms...',
                      textAlign: TextAlign.center,
                      style: MataText.display(fontSize: 28, height: 1.25),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      "Ma'ta is reviewing your symptoms "
                      'to prepare your assessment.',
                      textAlign: TextAlign.center,
                      style: MataText.body(
                        color: MataColors.muted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error == null)
                    _buildLoadingContent()
                  else
                    _buildErrorContent(),
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

  Widget _buildLoadingContent() {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '“${widget.description}”',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: MataText.body(
                color: MataColors.muted,
                fontSize: 13.5,
                height: 1.6,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
          const Spacer(),
          MataGlass(
            radius: 18,
            opacity: 0.6,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              'This usually takes a few seconds.\n'
              'Please don’t close the app.',
              textAlign: TextAlign.center,
              style: MataText.body(
                color: MataColors.cocoa,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: MataGlass(
        glow: true,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: red, size: 40),
            const SizedBox(height: 12),
            Text(
              _error!.title,
              textAlign: TextAlign.center,
              style: MataText.display(fontSize: 19),
            ),
            const SizedBox(height: 6),
            Text(
              _error!.message,
              textAlign: TextAlign.center,
              style: MataText.body(
                color: MataColors.ink,
                fontSize: 14.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!.suggestion,
              textAlign: TextAlign.center,
              style: MataText.body(
                color: MataColors.brown,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            MataButton(label: 'Try Again', onPressed: _analyzeSymptoms),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Back',
                style: MataText.body(
                  color: brown,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
