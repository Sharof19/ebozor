import 'package:flutter/material.dart';

class OrganizationInfoPage extends StatelessWidget {
  const OrganizationInfoPage({super.key, required this.info});

  final Map<String, String> info;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tashkilot ma\'lumotlari'),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'Ma\'lumotlar topilmadi.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    entry.label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  subtitle: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  tileColor: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: entries.length,
            ),
    );
  }

  List<_InfoEntry> _buildEntries() {
    final surname = info['surname'];
    final name = info['name'];
    final fullName = [
      if (surname != null && surname.trim().isNotEmpty) surname.trim(),
      if (name != null && name.trim().isNotEmpty) name.trim(),
    ].join(' ').trim();

    final mapping = <String, String>{
      'organization': 'Tashkilot nomi',
      'stir': 'STIR',
      if (fullName.isNotEmpty) 'fullName': 'F.I.Sh.',
      'role': 'Lavozim',
      'locality': 'Tuman',
      'region': 'Viloyat',
      'uid': 'UID',
      'pinfl': 'PINFL',
    };

    final entries = <_InfoEntry>[];
    mapping.forEach((key, label) {
      if (key == 'fullName') {
        if (fullName.isNotEmpty) {
          entries.add(_InfoEntry(label: label, value: fullName));
        }
      } else {
        final value = info[key];
        if (value != null && value.trim().isNotEmpty) {
          entries.add(_InfoEntry(label: label, value: value.trim()));
        }
      }
    });

    return entries;
  }
}

class _InfoEntry {
  const _InfoEntry({required this.label, required this.value});
  final String label;
  final String value;
}
