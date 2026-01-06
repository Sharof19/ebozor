import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import 'package:ebozor/src/core/theme/app_colors.dart';

class InternetCheckPage extends StatefulWidget {
  const InternetCheckPage({super.key});

  @override
  State<InternetCheckPage> createState() => _InternetCheckPageState();
}

class _InternetCheckPageState extends State<InternetCheckPage> {
  bool _showPage = false;
  bool _isChecking = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkConnection(initial: true));
  }

  Future<void> _checkConnection({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasNetwork = connectivityResults
          .any((result) => result != ConnectivityResult.none);

      final hasInternet =
          hasNetwork ? await InternetConnection().hasInternetAccess : false;

      if (!mounted) return;

      if (hasNetwork && hasInternet) {
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      setState(() {
        _showPage = true;
        _isChecking = false;
        _statusMessage =
            "Internet mavjud emas. Ulanishni tekshirib, qayta urinib ko'ring.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _showPage = true;
        _isChecking = false;
        _statusMessage =
            "Ulanishni tekshirishda xatolik yuz berdi. Iltimos, qayta urinib ko'ring.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPage) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    final infoText = _isChecking
        ? 'Internet ulanishi tekshirilmoqda...'
        : (_statusMessage ??
            'Internet ulanmagan. Ulanishni yoqing va "Qayta urinib ko\'rish" tugmasini bosing.');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isChecking ? Icons.wifi : Icons.wifi_off,
                      size: 90,
                      color: AppColors.primaryAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      infoText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    if (_isChecking) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  "Qayta urinib ko'rish",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
