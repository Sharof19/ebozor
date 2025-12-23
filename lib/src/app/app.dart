import 'package:ebozor/src/core/connectivity/internet_checker.dart';
import 'package:ebozor/src/data/services/didox_service.dart';
import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:ebozor/src/features/auth/presentation/pages/auth_page.dart';
import 'package:ebozor/src/features/auth/presentation/pages/internet_check_page.dart';
import 'package:ebozor/src/features/auth/presentation/pages/onboarding/cookie_consent_page.dart';
import 'package:ebozor/src/features/auth/presentation/pages/onboarding/onboarding_screen.dart';
import 'package:ebozor/src/features/auth/presentation/pages/signing_page.dart';
import 'package:ebozor/src/features/auth/presentation/pages/splash_screen.dart';
import 'package:ebozor/src/features/navigation/presentation/pages/home_screen.dart';
import 'package:ebozor/src/features/signing/bloc/eimzo_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EbozorApp extends StatefulWidget {
  const EbozorApp({super.key});

  @override
  State<EbozorApp> createState() => _EbozorAppState();
}

class _EbozorAppState extends State<EbozorApp> {
  bool _isConnectivityDialogVisible = false;
  bool? _lastConnectivityStatus;

  void _handleConnectivity(BuildContext context, InternetState state) {
    final previousStatus = _lastConnectivityStatus;
    _lastConnectivityStatus = state.isConnected;

    if (previousStatus != null && previousStatus == state.isConnected) {
      return;
    }

    if (!state.isConnected) {
      if (_isConnectivityDialogVisible) return;
      _isConnectivityDialogVisible = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text('Internet yo\'q'),
          content: Text('Iltimos, internet aloqasini tiklang.'),
        ),
      ).then((_) {
        _isConnectivityDialogVisible = false;
      });
    } else if (_isConnectivityDialogVisible) {
      _isConnectivityDialogVisible = false;
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  Map<String, WidgetBuilder> _routes() {
    return {
      '/': (context) => const SplashScreenPage(),
      '/main': (context) => const HomeScreen(),
      '/cookies': (context) => const CookieConsentPage(),
      '/onboarding': (context) => const OnboardingScreen(),
      '/inet_check': (context) => const InternetCheckPage(),
      '/auth': (context) => const AuthPage(),
      '/signing': (context) => BlocProvider(
            create: (context) => EimzoBloc(context.read<EimzoService>())
              ..add(
                const EimzoFlowStarted(),
              ),
            child: const SigningPage(),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DidoxService>(
          create: (_) => DidoxService(),
        ),
        RepositoryProvider<EimzoService>(
          create: (_) => EimzoService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<InternetChecker>(
            create: (_) => InternetChecker(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          initialRoute: '/',
          builder: (context, child) {
            return BlocListener<InternetChecker, InternetState>(
              listener: _handleConnectivity,
              child: child ?? const SizedBox.shrink(),
            );
          },
          routes: _routes(),
        ),
      ),
    );
  }
}
