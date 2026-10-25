import 'package:flutter/material.dart';

import '../theme/mata_theme.dart';
import '../widgets/road_scene.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color softWhite = Color(0xFFFFFBF7);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1517),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // twilight, with the guiding path running to a warm horizon
          const RoadScene(mood: RoadMood.welcome),

          Positioned(
            top: screenSize.height * 0.16,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Ma'ta",
                  style: MataText.display(
                    color: softWhite,
                    fontSize: 46,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'SYMPTOM GUIDANCE',
                  style: MataText.body(
                    color: softWhite.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 5.5,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                120,
                24,
                34 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0C0807).withValues(alpha: 0.62),
                    const Color(0xFF0C0807).withValues(alpha: 0.62),
                    const Color(0x000C0807),
                  ],
                  stops: const [0, 0.22, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find your way to the right care.',
                    style: MataText.display(
                      color: softWhite,
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Describe how you feel in your own words. '
                    "We'll guide you from there.",
                    style: MataText.body(
                      color: softWhite.withValues(alpha: 0.78),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  MataButton(
                    label: 'Create account',
                    style: MataButtonStyle.cream,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  MataButton(
                    label: 'Sign in',
                    style: MataButtonStyle.ghost,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                      );
                    },
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
