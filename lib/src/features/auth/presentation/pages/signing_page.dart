import 'package:ebozor/src/core/theme/app_colors.dart';
import 'package:ebozor/src/core/widgets/error_dialog.dart';
import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SigningPage extends StatefulWidget {
  const SigningPage({super.key});

  @override
  State<SigningPage> createState() => _SigningPageState();
}

enum _SigningStatus {
  initial,
  loading,
  success,
  needsInstallation,
  failure,
}

class _SigningPageState extends State<SigningPage> {
  final EimzoService _service = EimzoService();
  _SigningStatus _status = _SigningStatus.initial;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    setState(() {
      _status = _SigningStatus.loading;
      _errorMessage = null;
    });

    try {
      final pkcs = await _service.startFlow();
      if (!mounted) return;
      if (pkcs == null || pkcs.isEmpty) {
        _status = _SigningStatus.needsInstallation;
        _errorMessage =
            "E-IMZO ilovasini o'rnatish yoki ishga tushirish talab etiladi.";
        await _showErrorDialog(_errorMessage!);
        _goToAuth();
      } else {
        _status = _SigningStatus.success;
        _goToMain();
      }
    } on TimeoutException {
      if (!mounted) return;
      _status = _SigningStatus.failure;
      await _showErrorDialog(
        "Javob kelmadi. Qayta urinib ko'ring.",
      );
      _goToAuth();
      return;
    } catch (e) {
      if (!mounted) return;
      _status = _SigningStatus.failure;
      if (e is EimzoTokenException) {
        _errorMessage = e.message;
        await _showTokenErrorDialog(
          _errorMessage?.isNotEmpty == true
              ? _errorMessage!
              : "Token olishda xatolik yuz berdi.",
          e.pkcs,
        );
        _goToAuth();
        return;
      }
      _errorMessage = _formatException(e);
      await _showErrorDialog(
        _errorMessage?.isNotEmpty == true
            ? _errorMessage!
            : "Jarayon yakunlanmadi. Qayta urinib ko'ring.",
      );
      _goToAuth();
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _formatException(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showErrorDialog(context, message);
  }

  Future<void> _showTokenErrorDialog(String message, String pkcs) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFFFE5E5),
                child: Icon(Icons.close, color: Colors.redAccent, size: 26),
              ),
              const SizedBox(height: 12),
              const Text(
                'Xatolik',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: pkcs));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PKCS nusxalandi.')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('PKCS nusxalash'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Davom etish'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToMain() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  void _goToAuth() {
    Navigator.pushReplacementNamed(context, '/auth');
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        _status == _SigningStatus.loading || _status == _SigningStatus.initial;
    final hasError = _status == _SigningStatus.failure ||
        _status == _SigningStatus.needsInstallation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                const Text(
                  'Imzolash jarayoni boshlandi. Iltimos, kuting...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
        ),
      ),
    );
  }
}
