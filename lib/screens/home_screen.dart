import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final int currentNavIndex;
  final ValueChanged<int>? onNavigate;

  const HomeScreen({
    super.key,
    this.currentNavIndex = 0,
    this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService.instance;

  DateTime _selectedMonth = DateTime.now();
  bool _hideBalances = false;
  bool _isLoading = true;

  MonthlySummary _summary = const MonthlySummary(
    totalInflow: 0,
    totalOutflow: 0,
  );
  List<ExpenseModule> _modules = [];
  List<ExpenseTransaction> _recentTransactions = [];
  Map<int, double> _todayModuleTotals = {};

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);
  String get _monthLabel => DateFormat('MMMM yyyy').format(_selectedMonth);

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    final summary = await _db.getMonthlySummary(_monthKey);
    final modules = await _db.getModules();
    final txs = await _db.getTransactionsForMonth(_monthKey, limit: 10);

    final Map<int, double> todayTotals = {};
    for (final m in modules) {
      if (m.id != null) {
        todayTotals[m.id!] = await _db.getTodaySpendingForModule(m.id!);
      }
    }

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _modules = modules;
      _recentTransactions = txs;
      _todayModuleTotals = todayTotals;
      _isLoading = false;
    });
  }

  String _formatTaka(double value) {
    final formatter = NumberFormat('#,##,##0', 'en_US');
    return formatter.format(value.round());
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final months = List.generate(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: TakaPulseColors.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Statement Month',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: months.length,
                itemBuilder: (_, index) {
                  final m = months[index];
                  final isSelected = m.year == _selectedMonth.year &&
                      m.month == _selectedMonth.month;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tileColor: isSelected
                        ? TakaPulseColors.primaryContainer.withOpacity(0.15)
                        : null,
                    leading: Icon(
                      Icons.calendar_month_rounded,
                      color: isSelected
                          ? TakaPulseColors.primary
                          : TakaPulseColors.onSurfaceVariant,
                    ),
                    title: Text(
                      DateFormat('MMMM yyyy').format(m),
                      style: TextStyle(
                        color: isSelected
                            ? TakaPulseColors.primary
                            : TakaPulseColors.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
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
      _refreshDashboard();
    }
  }

  /// Opens fast tap-to-log sheet (pre-filled if fixed amount is configured)
  Future<void> _openQuickLogSheet(ExpenseModule module) async {
    final amountController = TextEditingController(
      text: module.isFixed && module.defaultAmount != null
          ? module.defaultAmount!.toStringAsFixed(0)
          : '',
    );
    final noteController = TextEditingController();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TakaPulseColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final accent = Color(module.accentColorValue);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TakaPulseColors.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _resolveIcon(module.iconKey),
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          module.isFixed
                              ? 'Fixed Preset • Tap Log to confirm'
                              : module.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      module.type == ModuleType.income ? 'Earning' : 'Spending',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                autofocus: !module.isFixed,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: TakaPulseColors.onSurface,
                ),
                decoration: InputDecoration(
                  prefixText: '৳ ',
                  prefixStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: TakaPulseColors.primary,
                  ),
                  hintText: '0',
                  filled: true,
                  fillColor: TakaPulseColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: TakaPulseColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Optional note (e.g., bKash, DESCO, Lunch)',
                  hintStyle: const TextStyle(
                    color: TakaPulseColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: TakaPulseColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TakaPulseColors.primaryContainer,
                    foregroundColor: TakaPulseColors.onPrimaryFixed,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () async {
                    final parsed =
                        double.tryParse(amountController.text.trim());
                    if (parsed == null || parsed <= 0) return;

                    await _db.logTransaction(
                      module: module,
                      amount: parsed,
                      note: noteController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: Text(
                    module.type == ModuleType.income
                        ? 'Log Earning'
                        : 'Log Spending',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await _refreshDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: TakaPulseColors.surfaceContainerHighest,
            content: Text('Logged entry for ${module.name}'),
          ),
        );
      }
    }
  }

  /// Opens modal to add a reusable custom segment (Earning/Spending, Fixed/Variable)
  Future<void> _openCreateModuleModal() async {
    final nameCtrl = TextEditingController();
    final subtitleCtrl = TextEditingController();
    final fixedAmountCtrl = TextEditingController();

    ModuleType selectedType = ModuleType.expense;
    bool isFixed = false;
    String selectedIcon = 'receipt_long';
    int selectedColor = 0xFF47F3BB;

    final iconOptions = [
      ('work', Icons.work_outline_rounded),
      ('bolt', Icons.bolt_rounded),
      ('school', Icons.school_outlined),
      ('local_mall', Icons.local_mall_outlined),
      ('home', Icons.home_outlined),
      ('wifi', Icons.wifi_rounded),
      ('restaurant', Icons.restaurant_outlined),
      ('directions_bus', Icons.directions_bus_outlined),
    ];

    final colorOptions = [
      0xFF47F3BB, // Mint
      0xFF00EEFC, // Cyan
      0xFF7DF4FF, // Ice Blue
      0xFFFFCCCF, // Rose Coral
    ];

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TakaPulseColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            TakaPulseColors.onSurfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Create Custom Module',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 14),

                  // Income vs Expense Segmented Pills
                  Row(
                    children: [
                      Expanded(
                        child: _TypeChoiceChip(
                          label: 'Spending',
                          selected: selectedType == ModuleType.expense,
                          activeColor: TakaPulseColors.tertiary,
                          onTap: () => setModalState(
                            () => selectedType = ModuleType.expense,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeChoiceChip(
                          label: 'Earning',
                          selected: selectedType == ModuleType.income,
                          activeColor: TakaPulseColors.primary,
                          onTap: () => setModalState(
                            () => selectedType = ModuleType.income,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: TakaPulseColors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Module Name (e.g., House Rent, Gas Bill)',
                      filled: true,
                      fillColor: TakaPulseColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitleCtrl,
                    style: const TextStyle(color: TakaPulseColors.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Short Subtitle (e.g., Monthly Utility)',
                      filled: true,
                      fillColor: TakaPulseColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Fixed Monthly Preset Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Fixed Monthly Amount',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Pre-fills amount for one-tap logging',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: isFixed,
                    activeTrackColor: TakaPulseColors.primaryContainer,
                    onChanged: (val) => setModalState(() => isFixed = val),
                  ),

                  if (isFixed) ...[
                    TextField(
                      controller: fixedAmountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: TakaPulseColors.onSurface),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        labelText: 'Fixed Preset Amount',
                        filled: true,
                        fillColor: TakaPulseColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Icon Picker Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: iconOptions.map((item) {
                      final active = selectedIcon == item.$1;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedIcon = item.$1),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: active
                                ? Color(selectedColor).withOpacity(0.22)
                                : TakaPulseColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: active
                                ? Border.all(color: Color(selectedColor))
                                : null,
                          ),
                          child: Icon(
                            item.$2,
                            size: 20,
                            color: active
                                ? Color(selectedColor)
                                : TakaPulseColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Accent Color Swatches
                  Row(
                    children: colorOptions.map((hex) {
                      final active = selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = hex),
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Color(hex),
                            shape: BoxShape.circle,
                            border: active
                                ? Border.all(color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TakaPulseColors.primaryContainer,
                        foregroundColor: TakaPulseColors.onPrimaryFixed,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final fixedVal = isFixed
                            ? double.tryParse(fixedAmountCtrl.text.trim())
                            : null;

                        final newModule = ExpenseModule(
                          name: nameCtrl.text.trim(),
                          subtitle: subtitleCtrl.text.trim().isEmpty
                              ? (selectedType == ModuleType.income
                                  ? 'Custom Income'
                                  : 'Custom Expense')
                              : subtitleCtrl.text.trim(),
                          type: selectedType,
                          isFixed: isFixed,
                          defaultAmount: fixedVal,
                          badgeText: isFixed ? 'Fixed Monthly' : 'Variable',
                          iconKey: selectedIcon,
                          accentColorValue: selectedColor,
                        );

                        await _db.insertModule(newModule);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      },
                      child: Text(
                        'Save Module',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (created == true) {
      _refreshDashboard();
    }
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
          : RefreshIndicator(
              color: TakaPulseColors.primary,
              onRefresh: _refreshDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Top Summary Hero Glass Card
                    _buildHeroSummaryCard(textTheme),
                    const SizedBox(height: 18),

                    // 2. Quick Action Shortcuts Row
                    _buildQuickActionRow(textTheme),
                    const SizedBox(height: 22),

                    // 3. Quick Modules Grid + Create Custom Module
                    _buildQuickModulesSection(textTheme),
                    const SizedBox(height: 22),

                    // 4. Recent Activity Transactions List
                    _buildRecentActivitySection(textTheme),
                  ],
                ),
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

  Widget _buildHeroSummaryCard(TextTheme textTheme) {
    final netFormatted =
        _hideBalances ? '••••••' : _formatTaka(_summary.netBalance);
    final inflowFormatted =
        _hideBalances ? '••••••' : '৳ ${_formatTaka(_summary.totalInflow)}';
    final outflowFormatted =
        _hideBalances ? '••••••' : '৳ ${_formatTaka(_summary.totalOutflow)}';
    final burnPct = _summary.burnRatioPercent;

    return GlassCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(20),
      tintColor: TakaPulseColors.surfaceContainerHigh,
      opacity: 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector & Privacy Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: TakaPulseColors.surfaceContainer.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: TakaPulseColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(_monthLabel, style: textTheme.labelMedium),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: TakaPulseColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hideBalances = !_hideBalances),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        TakaPulseColors.surfaceContainerLowest.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hideBalances
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 15,
                        color: TakaPulseColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _hideBalances ? 'Hidden' : 'Active',
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Net Balance Header & Trend Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NET BALANCE',
                style: textTheme.labelMedium?.copyWith(
                  color: TakaPulseColors.onSurfaceVariant,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: TakaPulseColors.primaryContainer.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: TakaPulseColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live Ledger',
                      style: textTheme.labelSmall?.copyWith(
                        color: TakaPulseColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Main Taka Currency Display
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '৳',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: TakaPulseColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                netFormatted,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: TakaPulseColors.onSurface,
                  letterSpacing: -0.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              if (!_hideBalances)
                Text(
                  '.00',
                  style: textTheme.titleMedium?.copyWith(
                    color: TakaPulseColors.onSurfaceVariant.withOpacity(0.75),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Split Inflow / Outflow Sub-Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        TakaPulseColors.surfaceContainerLow.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: TakaPulseColors.primaryContainer
                                  .withOpacity(0.20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_outward_rounded,
                              size: 16,
                              color: TakaPulseColors.primary,
                            ),
                          ),
                          Text(
                            'Earned',
                            style: textTheme.labelSmall?.copyWith(
                              color: TakaPulseColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Total Inflow', style: textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        inflowFormatted,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: TakaPulseColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        TakaPulseColors.surfaceContainerLow.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA4AC).withOpacity(0.20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.call_received_rounded,
                              size: 16,
                              color: TakaPulseColors.tertiary,
                            ),
                          ),
                          Text(
                            'Spent',
                            style: textTheme.labelSmall?.copyWith(
                              color: TakaPulseColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Total Outflow', style: textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        outflowFormatted,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: TakaPulseColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monthly Burn Ratio Gauge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Monthly Burn Ratio', style: textTheme.labelSmall),
              Text(
                '${burnPct.toStringAsFixed(1)}% used',
                style: textTheme.labelSmall?.copyWith(
                  color: TakaPulseColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              width: double.infinity,
              color: TakaPulseColors.surfaceContainerHighest.withOpacity(0.5),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (burnPct / 100).clamp(0.02, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        TakaPulseColors.secondaryFixedDim,
                        TakaPulseColors.primary,
                        TakaPulseColors.primaryContainer,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow(TextTheme textTheme) {
    final actions = [
      (
        Icons.attach_money_rounded,
        'Add Taka',
        TakaPulseColors.primary,
        () => widget.onNavigate?.call(1),
      ),
      (
        Icons.outbound_outlined,
        'Reports',
        TakaPulseColors.secondaryContainer,
        () => widget.onNavigate?.call(2),
      ),
      (
        Icons.receipt_long_outlined,
        'New Module',
        const Color(0xFFFFB2B8),
        _openCreateModuleModal,
      ),
      (
        Icons.cloud_upload_outlined,
        'Drive Sync',
        TakaPulseColors.secondaryFixed,
        () => widget.onNavigate?.call(3),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: item.$4,
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: TakaPulseColors.surfaceContainer.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Icon(item.$1, color: item.$3, size: 22),
                ),
                const SizedBox(height: 6),
                Text(item.$2, style: textTheme.labelSmall),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickModulesSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Modules',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tap module to log expense or income',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            GestureDetector(
              onTap: _openCreateModuleModal,
              child: Row(
                children: [
                  Text(
                    'Manage',
                    style: textTheme.labelMedium?.copyWith(
                      color: TakaPulseColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.tune_rounded,
                    size: 16,
                    color: TakaPulseColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2-Column Modular Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _modules.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.04,
          ),
          itemBuilder: (context, index) {
            final module = _modules[index];
            return _buildModuleCard(module, textTheme);
          },
        ),
        const SizedBox(height: 12),

        // + Create Custom Module Action Strip
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openCreateModuleModal,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: TakaPulseColors.surfaceContainerLow.withOpacity(0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: TakaPulseColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: TakaPulseColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Create Custom Module',
                  style: textTheme.labelLarge?.copyWith(
                    color: TakaPulseColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(ExpenseModule module, TextTheme textTheme) {
    final accent = Color(module.accentColorValue);
    final todayTotal =
        module.id != null ? (_todayModuleTotals[module.id!] ?? 0) : 0.0;

    return GestureDetector(
      onTap: () => _openQuickLogSheet(module),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(14),
        tintColor: TakaPulseColors.surfaceContainerHigh,
        opacity: 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _resolveIcon(module.iconKey),
                    color: accent,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    module.badgeText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.name,
                  style: textTheme.titleMedium?.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  module.subtitle,
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                if (module.isFixed && module.defaultAmount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '৳ ${_formatTaka(module.defaultAmount!)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        todayTotal > 0 ? 'Today:' : 'Last:',
                        style: textTheme.labelSmall,
                      ),
                      Text(
                        '৳ ${_formatTaka(todayTotal > 0 ? todayTotal : (module.defaultAmount ?? 0))}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: module.type == ModuleType.income
                              ? TakaPulseColors.primary
                              : TakaPulseColors.onSurface,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Recent Activity',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: TakaPulseColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => widget.onNavigate?.call(2),
              child: Row(
                children: [
                  Text(
                    'See All',
                    style: textTheme.labelMedium?.copyWith(
                      color: TakaPulseColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: TakaPulseColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        GlassCard(
          borderRadius: 24,
          padding: EdgeInsets.zero,
          tintColor: TakaPulseColors.surfaceContainerHigh,
          opacity: 0.65,
          child: _recentTransactions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: TakaPulseColors.onSurfaceVariant,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No transactions logged for $_monthLabel yet.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: TakaPulseColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap any Quick Module above to add your first entry.',
                        style: textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentTransactions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: TakaPulseColors.surfaceContainerHighest
                        .withOpacity(0.45),
                  ),
                  itemBuilder: (context, index) {
                    final tx = _recentTransactions[index];
                    final isIncome = tx.type == ModuleType.income;
                    final accent = Color(tx.accentColorValue);
                    final amountColor = isIncome
                        ? TakaPulseColors.primary
                        : TakaPulseColors.tertiary;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              _resolveIcon(tx.iconKey),
                              color: accent,
                              size: 22,
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
                                        tx.title,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (tx.isFixedEntry) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              TakaPulseColors.surfaceContainer,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Fixed',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: TakaPulseColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormat('MMM dd, h:mm a').format(tx.timestamp)} • ${tx.channelOrNote}',
                                  style: textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _hideBalances
                                    ? '••••'
                                    : '${isIncome ? '+' : '-'}৳ ${_formatTaka(tx.amount)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: amountColor,
                                ),
                              ),
                              Text(
                                tx.categoryLabel,
                                style: textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
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
        return Icons.local_mall_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'directions_bus':
        return Icons.directions_bus_outlined;
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

class _TypeChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _TypeChoiceChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withOpacity(0.20)
              : TakaPulseColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? activeColor : TakaPulseColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}