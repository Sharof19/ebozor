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
  Future<Widget> _resolveNextScreen() async {
    final token = await SecureStorageService.readAccessToken();
    final isValid =
        token != null && token.isNotEmpty && !JwtDecoder.isExpired(token);
    if (isValid) {
      return const HomeScreen();
    }
    final hasAcceptedCookies = await AppPreferences.hasAcceptedCookies();
    if (hasAcceptedCookies) {
      return const InternetCheckPage();
    }
    return const OnboardingScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveNextScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final next = snapshot.data ?? const OnboardingScreen();
        return AnimatedSplashScreen(
          splash: Center(
            child: Lottie.asset('assets/animation/logo.json'),
          ),
          nextScreen: next,
          duration: 2600,
          splashIconSize: 350,
        );
      },
    );
  }
}
