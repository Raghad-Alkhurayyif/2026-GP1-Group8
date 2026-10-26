import 'package:flutter/material.dart';

import '../theme/mata_theme.dart';
import '../widgets/stroke_background.dart';

class SymptomCompletionScreen extends StatelessWidget {
  const SymptomCompletionScreen({super.key, this.forSomeoneElse = false});

  // True when the assessment is for someone other than the user.
  final bool forSomeoneElse;

  static const Color brown = Color(0xFF79543B);
  static const Color softBeige = Color(0xFFF7F3EB);

  void _returnHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: MataCornerLogo(),
                  ),
                  const Spacer(),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MataColors.softWhite.withValues(alpha: 0.8),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0xCCFFF4E4), blurRadius: 50),
                        BoxShadow(
                          color: Color(0x4D79543B),
                          blurRadius: 30,
                          spreadRadius: -12,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: brown,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Symptoms Confirmed!',
                    textAlign: TextAlign.center,
                    style: MataText.display(fontSize: 27),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${forSomeoneElse ? 'Their' : 'Your'} symptoms and '
                    'their details have been saved successfully.',
                    textAlign: TextAlign.center,
                    style: MataText.body(
                      fontSize: 14,
                      height: 1.6,
                      color: MataColors.muted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  MataGlass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        _completedRow('Symptom review'),
                        Divider(
                          height: 1,
                          color: brown.withValues(alpha: 0.12),
                        ),
                        _completedRow('Symptom details'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'The remaining assessment steps '
                    'are under development.',
                    textAlign: TextAlign.center,
                    style: MataText.body(
                      color: MataColors.faint,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  MataButton(
                    label: 'Return to Home',
                    onPressed: () => _returnHome(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedRow(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: brown, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: MataText.body(fontSize: 14.5, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
