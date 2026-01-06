import 'package:ebozor/src/core/storage/secure_storage_service.dart';
import 'package:ebozor/src/core/storage/app_preferences.dart';
import 'package:ebozor/src/core/theme/app_colors.dart';
import 'package:ebozor/src/core/widgets/error_dialog.dart';
import 'package:ebozor/src/data/services/client_agreements_service.dart';
import 'package:ebozor/src/data/services/payment_plan_service.dart';
import 'package:ebozor/src/data/services/sign_service.dart';
import 'package:ebozor/src/features/documents/presentation/pages/ready_contract_page.dart';
import 'package:ebozor/src/features/home/presentation/pages/payment_plan_page.dart';
import 'package:ebozor/src/features/navigation/presentation/pages/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final ClientAgreementsService _service = ClientAgreementsService();
  final SignService _signService = SignService();
  final PaymentPlanService _planService = PaymentPlanService();
  bool _isLoading = true;
  bool _isPlanLoading = false;
  String? _error;
  List<ClientAgreement> _agreements = const [];
  bool _isDemoMode = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final isDemo = await AppPreferences.isDemoMode();
    if (!mounted) return;
    if (isDemo) {
      setState(() {
        _isDemoMode = true;
        _isLoading = false;
        _agreements = _demoAgreements();
      });
      return;
    }
    _loadAgreements();
  }

  Future<void> _loadAgreements() async {
    if (_isDemoMode) {
      setState(() {
        _isLoading = false;
        _error = null;
        _agreements = _demoAgreements();
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchAgreements();
      if (!mounted) return;
      setState(() {
        _agreements = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openReadyContract(
    ClientAgreement agreement, {
    bool showSignActions = false,
  }) async {
    if (_isDemoMode) {
      showSignActions = false;
    }
    final html = agreement.readyContractHtml;
    final url = agreement.readyContractUrl;
    if (html != null && html.trim().isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (routeContext) => ReadyContractPage(
            agreement: agreement,
            showSignActions: showSignActions,
            onApprove:
                showSignActions ? (ctx) => _handleSign(ctx, agreement) : null,
            onReject: showSignActions
                ? (ctx, reason) => _handleReject(ctx, agreement, reason)
                : null,
          ),
        ),
      );
      return;
    }
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    }
    if (!mounted) return;
    await showErrorDialog(
      context,
      'Shartnoma havolasi mavjud emas.',
    );
  }

  Future<void> _openPaymentPlan(ClientAgreement agreement) async {
    if (_isDemoMode) {
      if (mounted) {
        await showErrorDialog(
          context,
          "Demo rejimida to'lov rejasi mavjud emas.",
        );
      }
      return;
    }
    if (_isPlanLoading) return;
    if (agreement.id <= 0) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        "Shartnoma identifikatori noto'g'ri.",
      );
      return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    setState(() => _isPlanLoading = true);

    try {
      final plan = await _planService.fetchPlan(agreementId: agreement.id);
      if (!mounted) return;
      setState(() => _isPlanLoading = false);
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => PaymentPlanPage(
            agreementId: agreement.id,
            agreementNumber: agreement.number,
            service: _planService,
            initialPlan: plan,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlanLoading = false);
      await _showPlanError("Shartnoma to'lov rejasi topilmadi.");
    } finally {
      if (mounted) {
        if (_isPlanLoading) {
          setState(() => _isPlanLoading = false);
        }
      }
    }
  }

  Future<void> _showPlanError(String message) async {
    await showErrorDialog(context, message);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Shartnomalar'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Shartnomalar'),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAgreements,
            child: _buildBody(context),
          ),
          if (_isPlanLoading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return _buildCenteredScroll(
        context,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() => _error = null);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Davom etish'),
              ),
            ],
          ),
        ),
      );
    }
    if (_agreements.isEmpty) {
      return _buildCenteredScroll(
        context,
        const Text(
          'Hozircha shartnomalar mavjud emas.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _agreements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agreement = _agreements[index];
        final pendingIndex = _firstPendingIndex(agreement.signatories);
        final canSign = !_isDemoMode &&
            pendingIndex >= 0 &&
            pendingIndex < agreement.signatories.length &&
            _isPending(agreement.signatories[pendingIndex]) &&
            agreement.signatories[pendingIndex].role.toLowerCase() == 'client';
        return _AgreementCard(
          agreement: agreement,
          onOpenContract: () => _openReadyContract(agreement),
          onOpenPlan: _isDemoMode ? null : () => _openPaymentPlan(agreement),
          onSign: canSign
              ? () => _openReadyContract(
                    agreement,
                    showSignActions: true,
                  )
              : null,
          canSign: canSign,
          pendingIndex: pendingIndex,
        );
      },
    );
  }

  Widget _buildCenteredScroll(BuildContext context, Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : MediaQuery.of(context).size.height * 0.5;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: height,
              child: Center(child: child),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSign(
    BuildContext pageContext,
    ClientAgreement agreement,
  ) async {
    if (_isDemoMode) {
      await showErrorDialog(
        pageContext,
        "Demo rejimida imzolash mavjud emas.",
      );
      return;
    }
    final navigator = Navigator.of(pageContext);
    final rootMessenger = ScaffoldMessenger.of(context);
    final agreementId = agreement.id;
    if (agreementId <= 0) {
      await showErrorDialog(
        pageContext,
        "Shartnoma identifikatori noto'g'ri.",
      );
      return;
    }
    final hasKey = await _ensureHasMyKey(pageContext);
    if (!hasKey) return;
    try {
      await _signService.signAgreement(agreementId: agreementId);
      if (!mounted) return;
      navigator.pop(true);
      rootMessenger.showSnackBar(
        const SnackBar(content: Text('Shartnoma muvaffaqiyatli imzolandi.')),
      );
      await _loadAgreements();
    } catch (e) {
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      await showErrorDialog(pageContext, "Imzolashda xato: $message");
    }
  }

  Future<void> _handleReject(
    BuildContext pageContext,
    ClientAgreement agreement,
    String reason,
  ) async {
    if (_isDemoMode) {
      await showErrorDialog(
        pageContext,
        "Demo rejimida rad etish mavjud emas.",
      );
      return;
    }
    final navigator = Navigator.of(pageContext);
    final rootMessenger = ScaffoldMessenger.of(context);
    final agreementId = agreement.id;
    if (agreementId <= 0) {
      await showErrorDialog(
        pageContext,
        "Shartnoma identifikatori noto'g'ri.",
      );
      return;
    }
    final hasKey = await _ensureHasMyKey(pageContext);
    if (!hasKey) return;
    try {
      await _signService.rejectAgreement(
        agreementId: agreementId,
        reason: reason,
      );
      if (!mounted) return;
      navigator.pop(true);
      rootMessenger.showSnackBar(
        const SnackBar(content: Text('Shartnoma rad etildi.')),
      );
      await _loadAgreements();
    } catch (e) {
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      await showErrorDialog(pageContext, "Rad etishda xato: $message");
    }
  }

  int _firstPendingIndex(List<AgreementSignatory> signatories) {
    for (var i = 0; i < signatories.length; i++) {
      if (_isPending(signatories[i])) {
        return i;
      }
    }
    return -1;
  }

  bool _isPending(AgreementSignatory signatory) {
    final status = signatory.status.toLowerCase();
    if (signatory.isSigned) return false;
    return status == 'pending' || status == 'in_progress';
  }

  Future<bool> _ensureHasMyKey(BuildContext ctx) async {
    if (_isDemoMode) {
      return false;
    }
    final pkcs = await SecureStorageService.readMyKey();
    if (pkcs != null && pkcs.isNotEmpty) {
      return true;
    }
    if (!mounted) return false;
    if (Navigator.of(ctx).canPop()) {
      Navigator.of(ctx).pop();
    }
    await showErrorDialog(
      context,
      'Avval profil sahifasida kalit oling.',
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 1),
      ),
    );
    return false;
  }

  List<ClientAgreement> _demoAgreements() {
    const demoHtml = '''
      <html>
        <body>
          <h2>Demo shartnoma</h2>
          <p>Bu demo rejimi uchun namuna shartnoma matni.</p>
          <p>Real shartnoma ma'lumotlari faqat E-IMZO orqali kirganda ko'rinadi.</p>
        </body>
      </html>
    ''';
    return const [
      ClientAgreement(
        id: 1,
        number: 'IJR-2025-000001',
        client: 'BEKBARAKA DEMO',
        contractTypeName: 'Ijara shartnomasi',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
        statusName: 'signed',
        isActive: true,
        signatories: [
          AgreementSignatory(
            name: 'Demo Foydalanuvchi',
            role: 'client',
            status: 'signed',
            isSigned: true,
          ),
          AgreementSignatory(
            name: 'Bek Baraka',
            role: 'lessor',
            status: 'signed',
            isSigned: true,
          ),
        ],
        readyContractHtml: demoHtml,
        readyContractName: "Shartnomani ko'rish",
      ),
      ClientAgreement(
        id: 2,
        number: 'IJR-2025-000002',
        client: 'DEMO COMPANY',
        contractTypeName: 'Ijara shartnomasi',
        startDate: '2025-02-01',
        endDate: '2026-01-31',
        statusName: 'pending',
        isActive: true,
        signatories: [
          AgreementSignatory(
            name: 'Demo Client',
            role: 'client',
            status: 'pending',
            isSigned: false,
          ),
          AgreementSignatory(
            name: 'Bek Baraka',
            role: 'lessor',
            status: 'in_progress',
            isSigned: false,
          ),
        ],
        readyContractHtml: demoHtml,
        readyContractName: "Shartnomani ko'rish",
      ),
    ];
  }
}

class _AgreementCard extends StatelessWidget {
  const _AgreementCard({
    required this.agreement,
    required this.onOpenContract,
    this.onSign,
    this.canSign = false,
    this.pendingIndex,
    this.onOpenPlan,
  });

  final ClientAgreement agreement;
  final VoidCallback onOpenContract;
  final VoidCallback? onSign;
  final bool canSign;
  final int? pendingIndex;
  final VoidCallback? onOpenPlan;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return const Color(0xFF2F80ED);
      case 'pending':
        return const Color(0xFFF2C94C);
      case 'signed':
        return const Color(0xFF27AE60);
      case 'rejected':
        return const Color(0xFFEB5757);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showSignButton = canSign && onSign != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (agreement.signatories.isNotEmpty) const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  agreement.number,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(agreement.statusName)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    agreement.statusName,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColor(agreement.statusName),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              agreement.contractTypeName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              agreement.client,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: Colors.black45),
                const SizedBox(width: 6),
                Text(
                  '${agreement.startDate}  →  ${agreement.endDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (agreement.signatories.isNotEmpty) ...[
              const Text(
                'Imzolovchilar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Column(
                children: () {
                  return agreement.signatories
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SignatoryIcon(
                                signatory: entry.value,
                                isActivePending:
                                    entry.key == (pendingIndex ?? -1),
                                colorBuilder: _statusColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.value.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${entry.value.role} • ${entry.value.status}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList();
                }(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (onOpenPlan != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onOpenPlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.schedule),
                      label: const Text('To\'lov rejasi'),
                    ),
                  ),
                if (onOpenPlan != null) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onOpenContract,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      agreement.readyContractName ?? 'Shartnomani ko\'rish',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
            if (showSignButton) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onSign,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  label: const Text(
                    'Imzolash',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignatoryIcon extends StatelessWidget {
  const _SignatoryIcon({
    required this.signatory,
    required this.isActivePending,
    required this.colorBuilder,
  });

  final AgreementSignatory signatory;
  final bool isActivePending;
  final Color Function(String status) colorBuilder;

  @override
  Widget build(BuildContext context) {
    final statusColor = colorBuilder(signatory.status);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5F7FF),
            Color(0xFFE6EAFF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9FA9C5).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: CircleAvatar(
          radius: 15,
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(
            isActivePending ? Icons.access_time : Icons.person,
            size: 16,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}
