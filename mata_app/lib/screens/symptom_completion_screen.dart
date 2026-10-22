import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SymptomCompletionScreen extends StatelessWidget {
  const SymptomCompletionScreen({super.key});

  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color softBeige = Color(0xFFF7F3EB);
  static const Color borderColor = Color(0xFFDCCDB5);

  void _returnHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBeige,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/background.png', fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const Spacer(),

                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: brown.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: brown.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: brown,
                      size: 65,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Symptoms Confirmed!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.reemKufi(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: darkBrown,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Your symptoms and their details '
                    'have been saved successfully.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.reemKufi(
                      fontSize: 15,
                      height: 1.7,
                      color: brown,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _completedRow('Symptom review'),
                        const SizedBox(height: 16),
                        _completedRow('Symptom details'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  Text(
                    'The remaining assessment steps '
                    'are under development.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.reemKufi(
                      color: brown,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _returnHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBrown,
                        foregroundColor: softBeige,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'Return to Home',
                        style: GoogleFonts.reemKufi(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completedRow(String title) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: brown, size: 23),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.reemKufi(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: darkBrown,
            ),
          ),
        ),
      ],
    );
  }
}
