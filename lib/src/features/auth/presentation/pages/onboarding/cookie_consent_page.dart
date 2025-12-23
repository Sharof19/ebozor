import 'package:ebozor/src/core/storage/app_preferences.dart';
import 'package:ebozor/src/core/theme/app_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CookieConsentPage extends StatefulWidget {
  const CookieConsentPage({super.key});

  @override
  State<CookieConsentPage> createState() => _CookieConsentPageState();
}

class _CookieConsentPageState extends State<CookieConsentPage> {
  bool _isChecked = false;

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/photos/bek_baraka_logo.jpg', height: 200),
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/photos/onboard5.jpg',
                      height: screenHeight * 0.35,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _isChecked,
                          onChanged: (val) => setState(() {
                            _isChecked = val ?? false;
                          }),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Ommaviy oferta ',
                                  style: const TextStyle(color: Colors.blue),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _launchURL(
                                          'https://your-website.com/privacy');
                                    },
                                ),
                                const TextSpan(text: 'va '),
                                TextSpan(
                                  text: 'maxfiylik siyosati',
                                  style: const TextStyle(color: Colors.blue),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _launchURL(
                                          'https://your-website.com/privacy');
                                    },
                                ),
                                const TextSpan(text: ' shartlariga roziman.'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecked
                      ? () async {
                          await AppPreferences.setCookiesAccepted(true);
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/inet_check');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Davom etish',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
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
