import 'dart:math' as math;

import 'package:ebozor/src/data/services/client_agreements_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ReadyContractPage extends StatefulWidget {
  const ReadyContractPage({
    super.key,
    required this.agreement,
    this.onApprove,
    this.onReject,
    this.showSignActions = false,
  });

  final ClientAgreement agreement;
  final Future<void> Function(BuildContext context)? onApprove;
  final Future<void> Function(BuildContext context, String reason)? onReject;
  final bool showSignActions;

  @override
  State<ReadyContractPage> createState() => _ReadyContractPageState();
}

class _ReadyContractPageState extends State<ReadyContractPage> {
  bool _isSigning = false;
  bool _isRejecting = false;

  Future<bool> _ensureInternet(BuildContext context) async {
    final hasInternet = await InternetConnection().hasInternetAccess;
    if (!hasInternet && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet mavjud emas. Ulanishni tekshirib qayta urinib ko\'ring.'),
        ),
      );
    }
    return hasInternet;
  }

  @override
  Widget build(BuildContext context) {
    final htmlContent = _sanitizeHtml(
      _decodeHtmlEntities(widget.agreement.readyContractHtml),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.agreement.number,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              8,
              16,
              8,
              widget.showSignActions ? 64 : 12,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ContractHtmlCard(htmlContent: htmlContent),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.showSignActions
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEB5757),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            (_isRejecting || _isSigning) ? null : _handleReject,
                        child: _isRejecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Rad etish'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F80ED),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: (_isSigning || _isRejecting)
                            ? null
                            : () => _handleSign(context),
                        child: _isSigning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Imzolash'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _handleSign(BuildContext context) async {
    if (_isSigning || _isRejecting) return;
    final hasInternet = await _ensureInternet(context);
    if (!hasInternet) return;

    final messenger = ScaffoldMessenger.of(context);
    final callback = widget.onApprove;
    if (callback == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Imzolash harakati mavjud emas.')),
      );
      return;
    }
    setState(() => _isSigning = true);
    try {
      await callback(context);
    } catch (e) {
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Imzolashda xato: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSigning = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isRejecting || _isSigning) return;
    final hasInternet = await _ensureInternet(context);
    if (!hasInternet) return;

    final callback = widget.onReject;
    if (callback == null) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Rad etish harakati mavjud emas.')),
      );
      return;
    }
    if (_isRejecting) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rad etishni tasdiqlaysizmi?'),
          content: const Text('Tasdiqlashdan so\'ng shartnoma rad etiladi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tasdiqlash'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirm != true) {
      return;
    }
    setState(() => _isRejecting = true);

    const reason = 'Sababsiz';

    try {
      debugPrint('Rad etish sababi yuborilmoqda: $reason');
      await callback(context, reason);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Shartnoma rad etildi.')),
      );
    } catch (e) {
      final message = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Rad etishda xato: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRejecting = false);
      }
    }
  }
}

class _ContractHtmlCard extends StatelessWidget {
  const _ContractHtmlCard({required this.htmlContent});

  final String? htmlContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;

        final contentWidth = math.max(availableWidth - 16, 240.0);

        final html = Html(
          data: htmlContent,
          shrinkWrap: true,
          extensions: const [TableHtmlExtension()],
          style: {
            'html': Style(
              fontSize: FontSize(11),
              color: const Color(0xFF2D2D2D),
              lineHeight: const LineHeight(1.85),
              fontFamily: 'Roboto',
              width: Width(contentWidth, Unit.px),
            ),
            'body': Style(
              padding: HtmlPaddings.zero,
              margin: Margins.zero,
              width: Width(contentWidth, Unit.px),
              height: Height.auto(),
            ),
            'table': Style(
              width: Width(contentWidth, Unit.px),
              height: Height.auto(),
              margin: Margins.symmetric(vertical: 16),
              border: Border.all(
                color: Colors.transparent,
                width: 0,
              ),
              display: Display.block,
            ),
            'th': Style(
              padding: HtmlPaddings.all(12),
              backgroundColor: null,
              border: Border.all(
                color: Colors.transparent,
                width: 0,
              ),
              fontWeight: FontWeight.w600,
              textAlign: TextAlign.center,
              whiteSpace: WhiteSpace.normal,
            ),
            'td': Style(
              padding: HtmlPaddings.all(12),
              border: Border.all(
                color: Colors.transparent,
                width: 0,
              ),
              textAlign: TextAlign.left,
              whiteSpace: WhiteSpace.normal,
            ),
            'p': Style(
              margin: Margins.symmetric(vertical: 12),
              textAlign: TextAlign.justify,
            ),
            'strong': Style(fontWeight: FontWeight.w700),
          },
        );

        return ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: availableWidth, maxWidth: availableWidth),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: htmlContent == null || htmlContent!.isEmpty
                    ? const Center(
                        child: Text(
                          'Shartnoma mazmuni mavjud emas.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : html,
              ),
            ),
          ),
        );
      },
    );
  }
}

String? _sanitizeHtml(String? value) => value?.trim();

String? _decodeHtmlEntities(String? value) {
  if (value == null) return null;
  final decoded = value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', '\'')
      .replaceAll('&nbsp;', ' ');
  return decoded
      .replaceAll(RegExp(r'(<p>\s*</p>\s*)+$', caseSensitive: false), '')
      .replaceAll(RegExp(r'(\s|\u00A0)+$'), '')
      .trim();
}
