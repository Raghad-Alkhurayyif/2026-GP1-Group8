import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/mata_page_transitions.dart';
import 'theme/mata_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            ...const PageTransitionsTheme().builders,
            TargetPlatform.android: const MataPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<void> _sessionCheck;

  bool _sessionExpired = false;
  bool _messageShown = false;

  @override
  void initState() {
    super.initState();
    _sessionCheck = _checkStoredSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ready before the first slide, which shows a still picture of the next
    // screen and must not catch it before its artwork has loaded.
    precacheImage(const AssetImage('assets/images/background.png'), context);
    precacheImage(
      const AssetImage('assets/images/mata_logo_corner.png'),
      context,
    );
    MataText.preload();
  }

  Future<void> _checkStoredSession() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      const invalidSessionCodes = {
        'user-disabled',
        'user-not-found',
        'invalid-user-token',
        'user-token-expired',
      };

      if (invalidSessionCodes.contains(error.code)) {
        _sessionExpired = true;
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  void _showSessionExpiredMessage(BuildContext context) {
    if (!_sessionExpired || _messageShown) {
      return;
    }

    _messageShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has ended. Please sign in again.'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _sessionCheck,
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (authSnapshot.hasData) {
              return const HomeScreen();
            }

            _showSessionExpiredMessage(context);
            return const WelcomeScreen();
          },
        );
      },
    );
  }
}
