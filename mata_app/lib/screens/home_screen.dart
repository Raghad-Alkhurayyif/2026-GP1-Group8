import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/mata_bottom_navigation_bar.dart';
import 'account_screen.dart';
import '../widgets/sos_button.dart';

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

  bool _showError = false;

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  void _submitSymptoms() {
    FocusScope.of(context).unfocus();

    if (_symptomsController.text.trim().isEmpty) {
      setState(() {
        _showError = true;
      });
      return;
    }

    setState(() {
      _showError = false;
    });

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AnalyzingScreen()));
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
                              onPressed: _submitSymptoms,
                              style: ElevatedButton.styleFrom(
                                elevation: 5,
                                backgroundColor: darkBrown,
                                foregroundColor: inputBackground,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
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

class AnalyzingScreen extends StatelessWidget {
  const AnalyzingScreen({super.key});

  static const Color brown = Color(0xFF79543B);
  static const Color darkBrown = Color(0xFF5C3F38);
  static const Color inputBackground = Color(0xFFF7F3EB);

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
                    "Ma'ta is reviewing your symptoms to "
                    'prepare your assessment.',
                    style: GoogleFonts.reemKufi(
                      color: brown,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 60),
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

                  Transform.translate(
                    offset: const Offset(-12, -10),
                    child: Center(
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
                  ),
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
}
