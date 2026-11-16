import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_models.dart';
import '../services/database_service.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  final int currentNavIndex;
  final ValueChanged<int>? onNavigate;

  const ReportsScreen({
    super.key,
    this.currentNavIndex = 2,
    this.onNavigate,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final PdfReportService _pdfService = PdfReportService.instance;

  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  bool _isExporting = false;
  String _pdfSizeLabel = '142 KB';

  MonthlySummary _summary = const MonthlySummary(
    totalInflow: 0,
    totalOutflow: 0,
  );
  List<CategoryBreakdown> _breakdowns = [];

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _monthLabel => DateFormat('MMMM yyyy').format(_selectedMonth);
  String get _auditFileName =>
      '${DateFormat('MMMMyyyy').format(_selectedMonth).substring(0, 3)}${_selectedMonth.year}_Audit';

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    final summary = await _db.getMonthlySummary(_monthKey);
    final txs = await _db.getTransactionsForMonth(_monthKey);
    final categories =
        _pdfService.computeCategoryBreakdowns(txs, summary.totalOutflow);

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _breakdowns = categories;
      _isLoading = false;
    });
  }

  String _formatTaka(double value) {
    return NumberFormat('#,##,##0', 'en_US').format(value.round());
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
    _loadReportData();
  }

  Future<void> _openMonthPicker() async {
    final now = DateTime.now();
    final options = List.generate(
      12,
      (i) => DateTime(now.year, now.month - i, 1),
    );

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: TakaPulseColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TakaPulseColors.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Select Audit Month',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, idx) {
                  final m = options[idx];
                  final selected = m.year == _selectedMonth.year &&
                      m.month == _selectedMonth.month;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: selected
                        ? TakaPulseColors.primary.withOpacity(0.15)
                        : null,
                    title: Text(
                      DateFormat('MMMM yyyy').format(m),
                      style: TextStyle(
                        color: selected
                            ? TakaPulseColors.primary
                            : TakaPulseColors.onSurface,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
      _loadReportData();
    }
  }

  Future<void> _handleDownloadPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final info = await _pdfService.generateMonthlyStatementPdf(_selectedMonth);
      if (!mounted) return;
      setState(() => _pdfSizeLabel = info.sizeLabel);
      _showToast('Saved ${info.fileName} (${info.sizeLabel})');
    } catch (e) {
      _showToast('Failed to generate PDF: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleShareChannel(String channel) async {
    try {
      await _pdfService.shareStatementPdf(_selectedMonth, channelHint: channel);
    } catch (e) {
      _showToast('Could not share via $channel: $e');
    }
  }

  void _openFullscreenPreview(TextTheme textTheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TakaPulseColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: TakaPulseColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statement Preview',
                          style: textTheme.titleMedium,
                        ),
                        Text(
                          'TakaPulse_Statement_${DateFormat('MMM_yyyy').format(_selectedMonth)}.pdf',
                          style: textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TakaPulseColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TakaPulse Financial Summary',
                            style: textTheme.titleMedium?.copyWith(
                              color: TakaPulseColors.primary,
                            ),
                          ),
                          Text(
                            'Reporting Month: $_monthLabel',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TakaPulseColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AUDIT READY',
                          style: textTheme.labelSmall?.copyWith(
                            color: TakaPulseColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TakaPulseColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _previewStat(
                          'Net Inflow',
                          '৳ ${_formatTaka(_summary.totalInflow)}',
                          TakaPulseColors.primary,
                        ),
                        _previewStat(
                          'Total Expensed',
                          '৳ ${_formatTaka(_summary.totalOutflow)}',
                          const Color(0xFFFFA4AC),
                        ),
                        _previewStat(
                          'Net Saved',
                          '৳ ${_formatTaka(_summary.netBalance)}',
                          TakaPulseColors.secondaryFixed,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_breakdowns.isEmpty)
                    Text(
                      'No expenses recorded for $_monthLabel yet.',
                      style: textTheme.bodySmall,
                    )
                  else
                    ..._breakdowns.map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• ${b.name}',
                              style: textTheme.bodySmall,
                            ),
                            Text(
                              '৳ ${_formatTaka(b.amount)} (${b.percentage.toStringAsFixed(1)}%)',
                              style: textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TakaPulseColors.primary,
                  foregroundColor: TakaPulseColors.onPrimary,
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleDownloadPdf();
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  'Save PDF File',
                  style: textTheme.labelLarge?.copyWith(
                    color: TakaPulseColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: TakaPulseColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: TakaPulseColors.surfaceContainerHighest,
        content: Text(msg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AmbientScaffold(
      appBar: _buildFrostedAppBar(textTheme),
      bottomNavigationBar: _buildFloatingNavBar(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TakaPulseColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Month Selector Carousel + 3-Column KPI Chips
                  _buildMonthHeaderAndStats(textTheme),
                  const SizedBox(height: 22),

                  // 2. Spending Composition Donut Chart + Breakdown List
                  _buildSpendingComposition(textTheme),
                  const SizedBox(height: 22),

                  // 3. Statement & PDF Export Card
                  _buildStatementExportSection(textTheme),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildFrostedAppBar(TextTheme textTheme) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AppBar(
            backgroundColor: TakaPulseColors.background.withOpacity(0.70),
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        TakaPulseColors.secondaryContainer,
                        TakaPulseColors.primaryContainer,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: TakaPulseColors.onPrimaryFixed,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'TakaPulse',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: TakaPulseColors.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16, left: 4),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: TakaPulseColors.surfaceContainerHigh,
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: TakaPulseColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeaderAndStats(TextTheme textTheme) {
    final savingsPct = _summary.totalInflow > 0
        ? ((_summary.netBalance / _summary.totalInflow) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Column(
      children: [
        // Month Switcher Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CircleArrowButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => _shiftMonth(-1),
            ),
            GestureDetector(
              onTap: _openMonthPicker,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: TakaPulseColors.surfaceContainerHigh.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: TakaPulseColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _monthLabel,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: TakaPulseColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            _CircleArrowButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => _shiftMonth(1),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3-Column Quick Stat Chips Row
        Row(
          children: [
            Expanded(
              child: _StatChipCard(
                icon: Icons.arrow_downward_rounded,
                label: 'INFLOW',
                amount: '৳ ${_formatTaka(_summary.totalInflow)}',
                accentColor: TakaPulseColors.primary,
                tintColor: TakaPulseColors.surfaceContainer.withOpacity(0.65),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChipCard(
                icon: Icons.arrow_upward_rounded,
                label: 'OUTFLOW',
                amount: '৳ ${_formatTaka(_summary.totalOutflow)}',
                accentColor: const Color(0xFFFFA4AC),
                tintColor: TakaPulseColors.surfaceContainer.withOpacity(0.65),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatChipCard(
                icon: Icons.savings_outlined,
                label: 'SAVED',
                amount: '৳ ${_formatTaka(_summary.netBalance)}',
                subNote: '${savingsPct.toStringAsFixed(1)}% net',
                accentColor: TakaPulseColors.secondaryFixed,
                tintColor: TakaPulseColors.secondaryContainer.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpendingComposition(TextTheme textTheme) {
    final burnRate = _summary.burnRatioPercent;
    final topCategory =
        _breakdowns.isNotEmpty ? _breakdowns.first.name : 'No expenses yet';
    final endDay =
        DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final shortMonth = DateFormat('MMM').format(_selectedMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.donut_large_rounded,
                  color: TakaPulseColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text('Spending Composition', style: textTheme.headlineSmall),
              ],
            ),
            Text(
              '৳ ${_formatTaka(_summary.totalOutflow)} Total',
              style: textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Interactive Donut Chart Glass Card
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 136,
                    height: 136,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(136, 136),
                          painter: _DonutChartPainter(
                            breakdowns: _breakdowns,
                            trackColor: TakaPulseColors.surfaceContainerHighest
                                .withOpacity(0.45),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'BURN RATE',
                              style: textTheme.labelSmall?.copyWith(fontSize: 9),
                            ),
                            Text(
                              '${burnRate.toStringAsFixed(1)}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: TakaPulseColors.onSurface,
                              ),
                            ),
                            Text(
                              burnRate <= 65 ? 'Healthy' : 'Elevated',
                              style: textTheme.labelSmall?.copyWith(
                                color: burnRate <= 65
                                    ? TakaPulseColors.primary
                                    : TakaPulseColors.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _breakdowns.isEmpty
                        ? Text(
                            'Log expenses in Home to populate your breakdown chart.',
                            style: textTheme.bodySmall,
                          )
                        : Column(
                            children: _breakdowns.take(4).map((b) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(b.colorValue),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        b.name,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: TakaPulseColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${b.percentage.toStringAsFixed(1)}%',
                                      style: textTheme.labelMedium,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Layered Horizontal Ratio Bar
              Container(
                height: 10,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: TakaPulseColors.surfaceContainerLowest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: _breakdowns.isEmpty
                    ? const SizedBox.expand()
                    : Row(
                        children: _breakdowns.map((b) {
                          final flex = math.max(1, (b.percentage * 10).round());
                          return Expanded(
                            flex: flex,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: Color(b.colorValue),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('01 $shortMonth', style: textTheme.labelSmall),
                  Flexible(
                    child: Text(
                      'Top expense: $topCategory',
                      style: textTheme.labelSmall?.copyWith(
                        color: TakaPulseColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('$endDay $shortMonth', style: textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Per-Module Category Detail Cards
        ..._breakdowns.map((item) {
          final color = Color(item.colorValue);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              borderRadius: 18,
              padding: const EdgeInsets.all(14),
              opacity: 0.62,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _resolveIcon(item.iconKey),
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(item.subtitle, style: textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '৳ ${_formatTaka(item.amount)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: TakaPulseColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${item.percentage.toStringAsFixed(1)}%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 5,
                      width: double.infinity,
                      color: TakaPulseColors.surfaceContainerHighest
                          .withOpacity(0.45),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (item.percentage / 100).clamp(0.03, 1.0),
                        child: Container(color: color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatementExportSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: TakaPulseColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text('Statement & Export', style: textTheme.headlineSmall),
              ],
            ),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 14,
                  color: TakaPulseColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Verified Hash',
                  style: textTheme.labelSmall?.copyWith(
                    color: TakaPulseColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Document Header Strip
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA4AC).withOpacity(0.20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFFFFA4AC),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _auditFileName,
                                style: textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFFFFA4AC).withOpacity(0.28),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'PDF',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFFA4AC),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'A4 Audit Sheet • $_pdfSizeLabel • Ready',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _openFullscreenPreview(textTheme),
                    style: IconButton.styleFrom(
                      backgroundColor: TakaPulseColors.surfaceContainerHighest
                          .withOpacity(0.6),
                    ),
                    icon: const Icon(
                      Icons.open_in_full_rounded,
                      size: 18,
                      color: TakaPulseColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Miniature Document Viewport Preview Strip
              GestureDetector(
                onTap: () => _openFullscreenPreview(textTheme),
                child: Container(
                  height: 92,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        TakaPulseColors.surfaceContainerLowest.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: TakaPulseColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 90,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: TakaPulseColors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 44,
                            height: 7,
                            decoration: BoxDecoration(
                              color: TakaPulseColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _fauxBar(TakaPulseColors.primary.withOpacity(0.45)),
                          const SizedBox(width: 8),
                          _fauxBar(const Color(0xFFFFA4AC).withOpacity(0.45)),
                          const SizedBox(width: 8),
                          _fauxBar(
                            TakaPulseColors.secondaryFixed.withOpacity(0.45),
                          ),
                          const SizedBox(width: 8),
                          _fauxBar(
                            TakaPulseColors.onSurfaceVariant.withOpacity(0.35),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: TakaPulseColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Local Vault Statement',
                                style: textTheme.labelSmall,
                              ),
                            ],
                          ),
                          Text(
                            'Tap to Fullscreen Preview',
                            style: textTheme.labelSmall?.copyWith(
                              color: TakaPulseColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Direct Sharing Row: WhatsApp, Email, Native Share
              Text(
                'DIRECT SHARING',
                style: textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DirectSharePill(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WhatsApp',
                      color: const Color(0xFF25D366),
                      onTap: () => _handleShareChannel('WhatsApp'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DirectSharePill(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      color: TakaPulseColors.secondaryFixed,
                      onTap: () => _handleShareChannel('Email'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DirectSharePill(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: TakaPulseColors.onSurface,
                      neutralBackground: true,
                      onTap: () => _handleShareChannel('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Primary Gradient Download CTA Button
              Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      TakaPulseColors.secondaryContainer,
                      TakaPulseColors.primaryContainer,
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _handleDownloadPdf,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isExporting
                              ? Icons.hourglass_top_rounded
                              : Icons.download_rounded,
                          size: 20,
                          color: TakaPulseColors.onPrimaryFixed,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isExporting
                              ? 'Preparing PDF File...'
                              : 'Download PDF Statement',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: TakaPulseColors.onPrimaryFixed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fauxBar(Color color) {
    return Expanded(
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: TakaPulseColors.surfaceContainerHigh.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Container(
          height: 5,
          width: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  IconData _resolveIcon(String key) {
    switch (key) {
      case 'work':
        return Icons.work_outline_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'school':
        return Icons.school_outlined;
      case 'local_mall':
        return Icons.restaurant_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'directions_bus':
        return Icons.directions_car_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Widget _buildFloatingNavBar() {
    final items = [
      (Icons.home_outlined, 'Home'),
      (Icons.add_circle_outline_rounded, 'Add'),
      (Icons.bar_chart_rounded, 'Reports'),
      (Icons.cloud_sync_rounded, 'Backup'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: TakaPulseColors.surfaceContainer.withOpacity(0.75),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.65),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (index) {
                  final active = widget.currentNavIndex == index;
                  return GestureDetector(
                    onTap: () => widget.onNavigate?.call(index),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: active
                            ? TakaPulseColors.primaryContainer.withOpacity(0.20)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            items[index].$1,
                            size: 22,
                            color: active
                                ? TakaPulseColors.primary
                                : TakaPulseColors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[index].$2,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? TakaPulseColors.primary
                                  : TakaPulseColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TakaPulseColors.surfaceContainer.withOpacity(0.75),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: TakaPulseColors.onSurface, size: 22),
      ),
    );
  }
}

class _StatChipCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final String? subNote;
  final Color accentColor;
  final Color tintColor;

  const _StatChipCard({
    required this.icon,
    required this.label,
    required this.amount,
    this.subNote,
    required this.accentColor,
    required this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tintColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TakaPulseColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subNote != null)
            Text(
              subNote!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: TakaPulseColors.secondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _DirectSharePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool neutralBackground;
  final VoidCallback onTap;

  const _DirectSharePill({
    required this.icon,
    required this.label,
    required this.color,
    this.neutralBackground = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: neutralBackground
              ? TakaPulseColors.surfaceContainerHighest.withOpacity(0.65)
              : color.withOpacity(0.15),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: const StadiumBorder(),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategoryBreakdown> breakdowns;
  final Color trackColor;

  _DonutChartPainter({
    required this.breakdowns,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 14.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    if (breakdowns.isEmpty) return;

    double startAngle = -math.pi / 2;
    for (final item in breakdowns) {
      final sweepAngle = (item.percentage / 100) * 2 * math.pi;
      final arcPaint = Paint()
        ..color = Color(item.colorValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.breakdowns != breakdowns;
  }
}