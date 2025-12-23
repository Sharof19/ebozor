import 'package:flutter/material.dart';
import 'package:ebozor/src/core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = const [
    {
      'image': 'assets/photos/onboard1.jpg',
      'title': 'Hujjatni imzolash',
      'desc':
          'Bu tez, qulay va xavfsiz jarayon. Raqamli tasdiqlash orqali hujjatlaringizni istalgan joydan imzolang va vaqtni tejang!',
    },
    {
      'image': 'assets/photos/onboard2.jpg',
      'title': "Hujjatlarni ko'rish",
      'desc':
          'Bu tez va qulay jarayon. Istalgan joydan hujjatlaringizga kirish, ularni ko\'rib chiqish va boshqarish imkoniyatidan foydalaning!',
    },
    {
      'image': 'assets/photos/onboard3.jpg',
      'title': 'Nazorat',
      'desc':
          'Jarayonlarni samarali boshqarish va kuzatishning qulay usuli. Har doim aniq va ishonchli ma\'lumotlarga ega bo\'ling!',
    },
    {
      'image': 'assets/photos/onboard4.jpg',
      'title': 'Hujjatlar almashinuvi',
      'desc':
          'Tezkor va qulay yechim. Foydalanuvchilar o\'rtasida hujjatlarni xavfsiz tarzda yuboring va qabul qiling!',
    },
  ];

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Image.asset(
              'assets/photos/bek_baraka_logo.jpg',
              height: 200,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final item = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          item['image']!,
                          height: screenHeight * 0.35,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          item['title']!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item['desc']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => _buildDot(isActive: index == _currentPage),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _onboardingData.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pushNamed(context, '/cookies');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    backgroundColor: AppColors.primaryAccent,
                  ),
                  child: Text(
                    _currentPage == _onboardingData.length - 1
                        ? 'Start'
                        : 'Next',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 10,
      width: isActive ? 20 : 10,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryAccent : AppColors.bannerDotInactive,
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }
}
