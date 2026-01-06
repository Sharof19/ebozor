import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:ebozor/src/core/storage/app_preferences.dart';
import 'package:ebozor/src/features/auth/presentation/pages/internet_check_page.dart';
import 'package:ebozor/src/features/auth/presentation/pages/onboarding/onboarding_screen.dart';
import 'package:ebozor/src/features/navigation/presentation/pages/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lottie/lottie.dart';

class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  late final Future<Widget> _nextScreenFuture;

  @override
  void initState() {
    super.initState();
    _nextScreenFuture = _resolveNextScreen();
  }

  Future<Widget> _resolveNextScreen() async {
    try {
      final isDemoMode = await AppPreferences.isDemoMode();
      if (isDemoMode) {
        return const HomeScreen();
      }
      final token = await SecureStorageService.readAccessToken();
      var isValid = false;
      if (token != null && token.isNotEmpty) {
        try {
          isValid = !JwtDecoder.isExpired(token);
        } catch (_) {
          isValid = false;
        }
      }
      if (isValid) {
        return const HomeScreen();
      }
      final hasAcceptedCookies = await AppPreferences.hasAcceptedCookies();
      if (hasAcceptedCookies) {
        return const InternetCheckPage();
      }
      return const OnboardingScreen();
    } catch (_) {
      return const InternetCheckPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Center(
        child: Lottie.asset(
          'assets/animation/logo.json',
          frameBuilder: (context, child, composition) {
            if (composition == null) {
              return Image.asset(
                'assets/photos/logo.jpg',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              );
            }
            return child;
          },
        ),
      ),
      nextScreen: _NextScreenLoader(future: _nextScreenFuture),
      duration: 2600,
      splashIconSize: 350,
      backgroundColor: Colors.white,
    );
  }
}

class _NextScreenLoader extends StatelessWidget {
  const _NextScreenLoader({required this.future});

  final Future<Widget> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return snapshot.data!;
        }
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
