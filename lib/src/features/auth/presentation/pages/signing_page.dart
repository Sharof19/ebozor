import 'package:ebozor/src/core/theme/app_colors.dart';
import 'package:ebozor/src/features/signing/bloc/eimzo_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SigningPage extends StatelessWidget {
  const SigningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocConsumer<EimzoBloc, EimzoState>(
          listener: (context, state) {
            if (state.status == EimzoStatus.success) {
              Navigator.pushReplacementNamed(context, '/main');
              return;
            }

            if (state.status == EimzoStatus.failure ||
                state.status == EimzoStatus.needsInstallation) {
              final message = state.errorMessage?.isNotEmpty == true
                  ? state.errorMessage!
                  : 'Jarayon yakunlanmadi. Qayta urinib ko\'ring.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
              Navigator.pushReplacementNamed(context, '/auth');
            }
          },
          builder: (context, state) {
            final isLoading = state.status == EimzoStatus.loading ||
                state.status == EimzoStatus.initial;
            final hasError = state.status == EimzoStatus.failure ||
                state.status == EimzoStatus.needsInstallation;

            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryAccent,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Imzolash jarayoni boshlandi. Iltimos, kuting...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasError) const SizedBox(height: 12),
                    if (hasError)
                      const Text(
                        'Jarayon yakunlanmadi. Qayta urinib ko\'rish uchun qayta yo\'naltirilmoqda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
