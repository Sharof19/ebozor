import 'package:flutter/material.dart';

Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  VoidCallback? onContinue,
}) {
  final cleaned = message.trim();
  if (cleaned.isEmpty) {
    return Future.value();
  }
  return showDialog<void>(
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
              cleaned,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onContinue?.call();
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
