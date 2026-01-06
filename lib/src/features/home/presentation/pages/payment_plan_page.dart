import 'dart:ui';

import 'package:ebozor/src/core/theme/app_colors.dart';
import 'package:ebozor/src/core/widgets/error_dialog.dart';
import 'package:ebozor/src/data/services/payme_service.dart';
import 'package:ebozor/src/data/services/payment_plan_service.dart';
import 'package:ebozor/src/features/payments/presentation/pages/payment_methods_page.dart';
import 'package:flutter/material.dart';

class PaymentPlanPage extends StatefulWidget {
  PaymentPlanPage({
    Key? key,
    required this.agreementId,
    this.agreementNumber,
    this.initialPlan,
    PaymentPlanService? service,
  })  : service = service ?? PaymentPlanService(),
        super(key: key);

  final int agreementId;
  final String? agreementNumber;
  final PaymentPlanService service;
  final ClientPaymentPlan? initialPlan;

  @override
  State<PaymentPlanPage> createState() => _PaymentPlanPageState();
}

class _PaymentPlanPageState extends State<PaymentPlanPage> {
  late Future<ClientPaymentPlan> _future;
  final Set<int> _selectedPlannedKeys = {};
  final PaymeService _paymeService = PaymeService();
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _future = widget.initialPlan != null
        ? Future.value(widget.initialPlan!)
        : widget.service.fetchPlan(agreementId: widget.agreementId);
  }

  Future<void> _refresh() async {
    setState(() {
      _selectedPlannedKeys.clear();
      _future = widget.service.fetchPlan(agreementId: widget.agreementId);
    });
    try {
      await _future;
    } catch (_) {
      // ignore refresh errors
    }
  }

  void _reload() {
    _refresh();
  }

  void _handlePlannedToggle(
    List<int> plannedKeys,
    int tappedKey,
    bool nextValue,
  ) {
    final tappedIndex = plannedKeys.indexOf(tappedKey);
    if (tappedIndex == -1) return;
    setState(() {
      if (nextValue) {
        // Avvalgilari yoqilmagan bo'lsa ham, ularni avtomatik yoqamiz.
        for (var i = 0; i <= tappedIndex; i++) {
          _selectedPlannedKeys.add(plannedKeys[i]);
        }
      } else {
        // Birini o'chirsak, undan keyingilar ham o'chadi.
        for (var i = tappedIndex; i < plannedKeys.length; i++) {
          _selectedPlannedKeys.remove(plannedKeys[i]);
        }
      }
    });
  }

  Future<void> _startPayment({
    required ClientPaymentPlan plan,
    required double total,
  }) async {
    if (_isPaying) return;
    if (plan.id <= 0) {
      await _showErrorDialog("To'lov rejasi ID topilmadi.");
      return;
    }
    if (total <= 0) {
      await _showErrorDialog("To'lov summasi topilmadi.");
      return;
    }

    setState(() => _isPaying = true);
    try {
      debugPrint(
        'Payme init payload => plan: ${plan.id}, amount: ${_formatAmountForApi(total)}',
      );
      final response = await _paymeService.initPayment(
        planId: plan.id,
        amount: _formatAmountForApi(total),
      );
      if (!mounted) return;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentMethodsPage(
            paymeUrl: response.paymeUrl,
          ),
        ),
      );
      if (!mounted) return;
      if (result == true) {
        await _refresh();
      }
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    await showErrorDialog(context, message);
  }

  void _handleErrorContinue() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final contractLabel =
        widget.agreementNumber ?? '#${widget.agreementId.toString()}';

    return Scaffold(
      appBar: AppBar(
        title: const Text("To'lov rejasi"),
      ),
      body: FutureBuilder<ClientPaymentPlan>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final message = snapshot.error
                    ?.toString()
                    .replaceFirst(RegExp(r'^Exception:\s*'), '') ??
                "To'lov rejasi yuklanmadi.";
            return _ErrorState(
              message: message,
              onContinue: _handleErrorContinue,
            );
          }

          final plan = snapshot.data;
          if (plan == null) {
            return _ErrorState(
              message: "To'lov rejasi ma'lumoti mavjud emas.",
              onContinue: _handleErrorContinue,
            );
          }
          final plannedKeys = _plannedKeys(plan.schedules);
          final onPlannedToggle = (int tappedKey, bool nextValue) {
            _handlePlannedToggle(plannedKeys, tappedKey, nextValue);
          };

          final selectedSchedules = plan.schedules
              .where((schedule) =>
                  _selectedPlannedKeys.contains(_scheduleKey(schedule)))
              .toList();
          final total = selectedSchedules.fold<double>(
            0,
            (sum, item) => sum + _parseAmount(item.amount),
          );
          final canPay = selectedSchedules.isNotEmpty && !_isPaying;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _PlanSummary(
                        contractLabel: contractLabel,
                        plan: plan,
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle(title: 'To\'lov jadvali'),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (plan.schedules.isEmpty) {
                            return const _EmptyScheduleState();
                          }
                          final isNarrow = constraints.maxWidth < 360;
                          final isCompact = constraints.maxWidth < 520;
                          if (isNarrow) {
                            return Column(
                              children: plan.schedules
                                  .map(
                                    (item) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _ScheduleCard(
                                        schedule: item,
                                        selectedPlannedKeys:
                                            _selectedPlannedKeys,
                                        onPlannedToggle: onPlannedToggle,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          }
                          final table = _ScheduleTable(
                            schedules: plan.schedules,
                            selectedPlannedKeys: _selectedPlannedKeys,
                            onPlannedToggle: onPlannedToggle,
                            isCompact: isCompact,
                          );
                          return table;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _PaymentFooterBar(
                selectedCount: selectedSchedules.length,
                totalAmount: _formatAmount(total),
                isLoading: _isPaying,
                onPay: canPay
                    ? () => _startPayment(plan: plan, total: total)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({
    required this.contractLabel,
    required this.plan,
  });

  final String contractLabel;
  final ClientPaymentPlan plan;

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        plan.isFullyPaid ? "To'liq to'langan" : "To'liq to'lanmagan";
    final statusColor =
        plan.isFullyPaid ? Colors.green : AppColors.primaryAccent;
    final totalAmount = _formatAmountString(plan.totalAmount);

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
            Text(
              'Shartnoma',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    contractLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(
                  text: statusLabel,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.payments,
                    label: 'Umumiy summa',
                    value: totalAmount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBox(
                    icon: Icons.calendar_month,
                    label: 'Oylar soni',
                    value: plan.monthsCount.toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaymentFooterBar extends StatelessWidget {
  const _PaymentFooterBar({
    required this.selectedCount,
    required this.totalAmount,
    required this.isLoading,
    required this.onPay,
  });

  final int selectedCount;
  final String totalAmount;
  final bool isLoading;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final isEnabled = selectedCount > 0 && onPay != null && !isLoading;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  selectedCount.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tanlangan oylar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jami: $totalAmount',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: isEnabled ? onPay : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('To\'lash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
    this.isCompact = false,
  });

  final String text;
  final Color color;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 10,
        vertical: isCompact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isCompact ? 11 : 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PlannedSwitch extends StatelessWidget {
  const _PlannedSwitch({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: Colors.green,
      inactiveTrackColor: Colors.grey.shade400,
      activeColor: Colors.white,
      inactiveThumbColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'To\'lov jadvali mavjud emas.',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({
    required this.schedules,
    required this.selectedPlannedKeys,
    required this.onPlannedToggle,
    this.isCompact = false,
  });

  final List<ClientSchedule> schedules;
  final Set<int> selectedPlannedKeys;
  final void Function(int tappedKey, bool nextValue) onPlannedToggle;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 12,
                vertical: isCompact ? 8 : 10,
              ),
              color: AppColors.accentLight,
              child: Row(
                children: [
                  _TableCell(
                    text: '№',
                    flex: 1,
                    isHeader: true,
                    isCompact: isCompact,
                  ),
                  _TableCell(
                    text: 'Muddat',
                    flex: isCompact ? 2 : 3,
                    isHeader: true,
                    isCompact: isCompact,
                  ),
                  _TableCell(
                    text: 'Summa',
                    flex: isCompact ? 2 : 3,
                    isHeader: true,
                    align: TextAlign.right,
                    isNumeric: true,
                    isCompact: isCompact,
                  ),
                  _TableCell(
                    text: 'To\'langan',
                    flex: isCompact ? 2 : 3,
                    isHeader: true,
                    align: TextAlign.right,
                    isNumeric: true,
                    isCompact: isCompact,
                  ),
                  _TableCell(
                    text: 'Holat',
                    flex: isCompact ? 2 : 3,
                    isHeader: true,
                    align: TextAlign.center,
                    isCompact: isCompact,
                  ),
                ],
              ),
            ),
            ...List.generate(
              schedules.length,
              (index) {
                final schedule = schedules[index];
                return _ScheduleTableRow(
                  schedule: schedule,
                  isLast: index == schedules.length - 1,
                  backgroundColor: index.isEven
                      ? Colors.white
                      : const Color(0xFFF7F9FC),
                  selectedPlannedKeys: selectedPlannedKeys,
                  onPlannedToggle: onPlannedToggle,
                  isCompact: isCompact,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTableRow extends StatelessWidget {
  const _ScheduleTableRow({
    required this.schedule,
    required this.isLast,
    required this.backgroundColor,
    required this.selectedPlannedKeys,
    required this.onPlannedToggle,
    this.isCompact = false,
  });

  final ClientSchedule schedule;
  final bool isLast;
  final Color backgroundColor;
  final Set<int> selectedPlannedKeys;
  final void Function(int tappedKey, bool nextValue) onPlannedToggle;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final statusText = _statusLabel(schedule.status);
    final color = _statusColor(schedule.status);
    final amount = _formatAmountString(schedule.amount);
    final paidAmount = _formatAmountString(schedule.paidAmount);
    final dueDate = schedule.dueDate.isNotEmpty ? schedule.dueDate : '-';
    final scheduleKey = _scheduleKey(schedule);
    final isPlanned = _isPlanned(schedule.status);
    final isActive = isPlanned && selectedPlannedKeys.contains(scheduleKey);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                ),
              ),
      ),
      child: Row(
        children: [
          _TableCell(
            text: schedule.order.toString(),
            flex: 1,
            isCompact: isCompact,
          ),
          Expanded(
            flex: isCompact ? 2 : 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dueDate,
                    style: TextStyle(fontSize: isCompact ? 12 : 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _TableCell(
            text: amount,
            flex: isCompact ? 2 : 3,
            align: TextAlign.right,
            isNumeric: true,
            isCompact: isCompact,
          ),
          _TableCell(
            text: paidAmount,
            flex: isCompact ? 2 : 3,
            align: TextAlign.right,
            isNumeric: true,
            isCompact: isCompact,
          ),
          Expanded(
            flex: isCompact ? 2 : 3,
            child: Align(
              alignment: Alignment.center,
              child: isPlanned
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _PlannedSwitch(
                        value: isActive,
                        onChanged: (next) => onPlannedToggle(scheduleKey, next),
                      ),
                    )
                  : _StatusPill(
                      text: statusText,
                      color: color,
                      isCompact: isCompact,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.text,
    required this.flex,
    this.align = TextAlign.left,
    this.isHeader = false,
    this.isNumeric = false,
    this.isCompact = false,
  });

  final String text;
  final int flex;
  final TextAlign align;
  final bool isHeader;
  final bool isNumeric;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isHeader
              ? (isCompact ? 11 : 12)
              : (isCompact ? 12 : 13),
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
          color: isHeader ? Colors.black87 : Colors.black87,
          fontFeatures: isNumeric ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.selectedPlannedKeys,
    required this.onPlannedToggle,
  });

  final ClientSchedule schedule;
  final Set<int> selectedPlannedKeys;
  final void Function(int tappedKey, bool nextValue) onPlannedToggle;

  double? _progressValue(num? progress) {
    if (progress == null) return null;
    final normalized = progress > 1 ? progress / 100 : progress.toDouble();
    if (normalized.isNaN || normalized.isInfinite) return null;
    return normalized.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _statusLabel(schedule.status);
    final color = _statusColor(schedule.status);
    final amount = _formatAmountString(schedule.amount);
    final paidAmount = _formatAmountString(schedule.paidAmount);
    final dueDate = schedule.dueDate.isNotEmpty ? schedule.dueDate : '-';
    final progressValue = _progressValue(schedule.progress);
    final scheduleKey = _scheduleKey(schedule);
    final isPlanned = _isPlanned(schedule.status);
    final isActive = isPlanned && selectedPlannedKeys.contains(scheduleKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  schedule.order.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                isPlanned
                    ? _PlannedSwitch(
                        value: isActive,
                        onChanged: (next) => onPlannedToggle(scheduleKey, next),
                      )
                    : _StatusPill(text: statusText, color: color),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.event,
              label: 'Muddat',
              value: dueDate,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.payments,
              label: 'To\'lov summasi',
              value: amount,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.check_circle_outline,
              label: 'To\'langan',
              value: paidAmount,
            ),
            if (progressValue != null) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progressValue,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: AppColors.primaryAccent,
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Text(
                'Progress: ${schedule.progress}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black45),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _statusColor(String? status) {
  if (status == null) return Colors.grey;
  switch (status.toLowerCase()) {
    case 'paid':
    case 'completed':
      return Colors.green;
    case 'planned':
      return AppColors.primaryAccent;
    case 'pending':
    case 'in_progress':
      return AppColors.primaryAccent;
    case 'overdue':
      return Colors.redAccent;
    default:
      return Colors.grey;
  }
}

String _statusLabel(String? status) {
  final value = status?.trim() ?? '';
  switch (value.toLowerCase()) {
    case 'paid':
    case 'completed':
      return "To'langan";
    case 'planned':
      return 'Kutilmoqda';
    case '':
      return 'Noma\'lum';
    default:
      return value;
  }
}

int _scheduleKey(ClientSchedule schedule) {
  if (schedule.id > 0) return schedule.id;
  return schedule.order;
}

bool _isPlanned(String? status) {
  return (status ?? '').trim().toLowerCase() == 'planned';
}

List<int> _plannedKeys(List<ClientSchedule> schedules) {
  final keys = <int>[];
  for (final schedule in schedules) {
    if (_isPlanned(schedule.status)) {
      keys.add(_scheduleKey(schedule));
    }
  }
  return keys;
}

double _parseAmount(String? raw) {
  if (raw == null) return 0;
  var cleaned = raw.replaceAll(RegExp(r'\s+'), '');
  if (cleaned.contains(',') && cleaned.contains('.')) {
    final lastDot = cleaned.lastIndexOf('.');
    final lastComma = cleaned.lastIndexOf(',');
    if (lastComma > lastDot) {
      cleaned = cleaned.replaceAll('.', '');
      cleaned = cleaned.replaceAll(',', '.');
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }
  } else if (cleaned.contains(',') && !cleaned.contains('.')) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  cleaned = cleaned.replaceAll(RegExp(r'[^0-9.-]'), '');
  return double.tryParse(cleaned) ?? 0;
}

String _formatAmount(double value) {
  final asInt = value.round();
  final negative = asInt < 0;
  final digits = asInt.abs().toString();
  final parts = <String>[];
  for (var i = digits.length; i > 0; i -= 3) {
    final start = (i - 3).clamp(0, i);
    parts.add(digits.substring(start, i));
  }
  final grouped = parts.reversed.join(' ');
  return negative ? '-$grouped' : grouped;
}

String _formatAmountString(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return '-';
  if (!RegExp(r'\d').hasMatch(trimmed)) return '-';
  return _formatAmount(_parseAmount(trimmed));
}

String _formatAmountForApi(double value) {
  return value.toStringAsFixed(0);
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onContinue});

  final String message;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Davom etish'),
            ),
          ],
        ),
      ),
    );
  }
}
