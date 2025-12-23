import 'package:ebozor/src/data/services/eimzo_service.dart';
import 'package:ebozor/src/data/services/my_key_service.dart';
import 'package:ebozor/src/core/storage/app_preferences.dart';
import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:ebozor/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'organization_info_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggingOut = false;
  bool _isFetchingMyKey = false;
  bool _hasMyKey = false;

  String? _name;
  String? _surname;
  String? _role;
  String? _organization;
  Map<String, String>? _certificateInfo;
  String? _myKeyStatus;

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
  }

  Future<void> _loadProfileInfo() async {
    final info = await SecureStorageService.readCertificateInfo();
    final myKey = await SecureStorageService.readMyKey();
    if (!mounted) return;
    setState(() {
      _name = info?['name'];
      _surname = info?['surname'];
      _role = info?['role'];
      _organization = info?['organization'];
      if (info != null) {
        _certificateInfo = info.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }
      if (myKey != null && myKey.isNotEmpty) {
        _hasMyKey = true;
        _myKeyStatus ??= 'Kalit olindi.';
      } else {
        _hasMyKey = false;
      }
    });
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    var succeeded = false;
    String? refreshTokenSnapshot;
    try {
      refreshTokenSnapshot = await SecureStorageService.readRefreshToken();
      await EimzoService().logout();
      await SecureStorageService.clearAuthData();
      await AppPreferences.clear();
      succeeded = true;
    } catch (e) {
      debugPrint(
        'Logout failed. Refresh token: ${refreshTokenSnapshot ?? 'mavjud emas'}; error: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Chiqish jarayonida xato: $e\nRefresh token: '
              '${refreshTokenSnapshot ?? 'mavjud emas'}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        if (succeeded) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
  }

  String get _headerName {
    final parts = <String>[];
    if (_surname != null && _surname!.trim().isNotEmpty) {
      parts.add(_surname!.trim());
    }
    if (_name != null && _name!.trim().isNotEmpty) {
      parts.add(_name!.trim());
    }
    return parts.isEmpty ? 'FOYDALANUVCHI' : parts.join(' ');
  }

  String _formatStatusText(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('.')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  void _openOrganizationInfo() {
    if (_certificateInfo == null || _certificateInfo!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ma\'lumotlar mavjud emas.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrganizationInfoPage(info: _certificateInfo!),
      ),
    );
  }

  Future<void> _obtainMyKey() async {
    if (_isFetchingMyKey) return;
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internet mavjud emas. Ulanishni tekshirib qayta urinib ko\'ring.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _isFetchingMyKey = true;
      _myKeyStatus = null;
    });

    var hasKey = _hasMyKey;
    String? statusMessage;

    try {
      final pkcs = await MyKeyService().createMyKey();
      if (pkcs != null && pkcs.isNotEmpty) {
        hasKey = true;
        statusMessage = 'Kalit olindi.';
      } else {
        statusMessage = 'Kalit olish bekor qilindi.';
      }
    } catch (e) {
      final cleaned = e.toString().replaceFirst(RegExp(r'^Exception:\\s*'), '');
      statusMessage = 'Kalit olishda xato: $cleaned';
    }

    if (!mounted) return;
    setState(() {
      _isFetchingMyKey = false;
      _hasMyKey = hasKey;
      _myKeyStatus = statusMessage;
    });
  }

  Future<void> _copyAccessToken() async {
    final token = await SecureStorageService.readAccessToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token topilmadi. Iltimos, qayta kiring.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token nusxalandi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileHeader(
                name: _headerName,
                role: _role?.trim(),
                organization: _organization?.trim(),
              ),
              const SizedBox(height: 16),
              _OrganizationInfoCard(
                info: _certificateInfo,
                onTap: _openOrganizationInfo,
              ),
              if (_myKeyStatus != null) ...[
                const SizedBox(height: 10),
                Text(
                  _formatStatusText(_myKeyStatus!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _myKeyStatus!.startsWith('Kalit olishda xato')
                        ? AppColors.error
                        : Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isFetchingMyKey ? null : _obtainMyKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isFetchingMyKey
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Kalit olinmoqda...'),
                        ],
                      )
                    : Text(_hasMyKey ? 'Kalitni yangilash' : 'Kalit olish'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _copyAccessToken,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryAccent,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text(
                  'Tokenni nusxalash',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isLoggingOut ? null : _logout,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: Colors.black.withValues(alpha: 0.08),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoggingOut
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.redAccent,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Chiqilmoqda...',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : const Text(
                        'Profildan chiqish',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationInfoCard extends StatelessWidget {
  const _OrganizationInfoCard({
    required this.info,
    required this.onTap,
  });

  final Map<String, String>? info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final organizationName = info?['organization']?.trim();
    final stir = info?['stir']?.trim();
    final locality = info?['locality'];
    final region = info?['region'];
    final locationParts = <String>[];
    if (locality != null && locality.trim().isNotEmpty) {
      locationParts.add(locality.trim());
    }
    if (region != null && region.trim().isNotEmpty) {
      locationParts.add(region.trim());
    }
    final location = locationParts.join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: AppColors.primaryAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Arenda oluvchi tashkilot haqidagi asosiy ma\'lumotlar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoItem(
              label: 'Kompaniya nomi',
              value: organizationName?.isNotEmpty == true
                  ? organizationName!
                  : 'Ma\'lumot mavjud emas',
            ),
            if (stir?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _InfoItem(label: 'STIR', value: stir!),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoItem(label: 'Manzil', value: location),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    this.role,
    this.organization,
  });

  final String name;
  final String? role;
  final String? organization;

  @override
  Widget build(BuildContext context) {
    final roleText = (role ?? '').trim();
    final organizationText = (organization ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFD9FF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (roleText.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  roleText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Kompaniya:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            organizationText.isNotEmpty ? organizationText : 'Ma\'lumot yo\'q',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
