import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/expense_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class QuickLogScreen extends StatefulWidget {
  final int currentNavIndex;
  final ValueChanged<int>? onNavigate;

  const QuickLogScreen({
    super.key,
    this.currentNavIndex = 1,
    this.onNavigate,
  });

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService.instance;

  List<ExpenseModule> _modules = [];
  ExpenseModule? _activeModule;
  DateTime _selectedDate = DateTime.now();

  String _rawAmount = '0';
  final TextEditingController _noteController = TextEditingController();
  bool _showSavedBanner = false;

  // New Flow Module Builder State
  final TextEditingController _moduleNameController = TextEditingController();
  final TextEditingController _presetAmountController = TextEditingController();
  ModuleType _newModuleType = ModuleType.expense;
  String _selectedIconKey = 'fitness_center';
  int _selectedHueValue = 0xFF47F3BB;
  bool _isNewModuleFixed = true;

  late final AnimationController _cursorController;

  static const List<(String, String, IconData)> _iconCatalog = [
    ('fitness_center', 'Fitness', Icons.fitness_center_rounded),
    ('restaurant', 'Dining', Icons.restaurant_rounded),
    ('home', 'Housing', Icons.home_outlined),
    ('local_gas_station', 'Transport', Icons.local_gas_station_outlined),
    ('medication', 'Health', Icons.medication_outlined),
    ('bolt', 'Utilities', Icons.bolt_rounded),
    ('school', 'Education', Icons.school_outlined),
    ('work', 'Income', Icons.work_outline_rounded),
  ];

  static const List<(String, int)> _hueCatalog = [
    ('Emerald Wave', 0xFF47F3BB),
    ('Electric Cyan', 0xFF00DBE9),
    ('Deep Teal', 0xFF006C4F),
    ('Rose Bloom', 0xFFFFA4AC),
    ('Sunset Coral', 0xFFFFB4AB),
  ];

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _loadModules();
  }

  @override
  void dispose() {
    _cursorController.dispose();
    _noteController.dispose();
    _moduleNameController.dispose();
    _presetAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadModules({int? selectModuleId}) async {
    final list = await _db.getModules();
    if (!mounted) return;

    ExpenseModule? chosen;
    if (list.isNotEmpty) {
      if (selectModuleId != null) {
        chosen = list.firstWhere(
          (m) => m.id == selectModuleId,
          orElse: () => list.first,
        );
      } else if (_activeModule != null) {
        chosen = list.firstWhere(
          (m) => m.id == _activeModule!.id,
          orElse: () => list.first,
        );
      } else {
        // Default to Tuition Fee or first module
        chosen = list.firstWhere(
          (m) => m.name.toLowerCase().contains('tuition'),
          orElse: () => list.first,
        );
      }
    }

    setState(() {
      _modules = list;
      if (chosen != null) {
        _selectModule(chosen, updateState: false);
      }
    });
  }

  void _selectModule(ExpenseModule module, {bool updateState = true}) {
    void apply() {
      _activeModule = module;
      if (module.isFixed && module.defaultAmount != null) {
        _rawAmount = module.defaultAmount!.toStringAsFixed(0);
      } else {
        _rawAmount = '0';
      }
      _noteController.text = module.subtitle;
    }

    if (updateState) {
      setState(apply);
    } else {
      apply();
    }
  }

  String _formatDisplayAmount(String raw) {
    if (raw.isEmpty || raw == '0') return '0';
    final parts = raw.split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;
    final formattedInt = NumberFormat('#,##,##0', 'en_US').format(intPart);
    if (parts.length > 1) {
      return '$formattedInt.${parts[1]}';
    }
    return formattedInt;
  }

  void _onKeypadTap(String key) {
    HapticFeedback.lightImpact();
    setState(() {
      if (key == 'backspace') {
        if (_rawAmount.length > 1) {
          _rawAmount = _rawAmount.substring(0, _rawAmount.length - 1);
        } else {
          _rawAmount = '0';
        }
      } else if (key == '.') {
        if (!_rawAmount.contains('.')) {
          _rawAmount += '.';
        }
      } else {
        if (_rawAmount == '0') {
          _rawAmount = key;
        } else if (_rawAmount.length < 9) {
          _rawAmount += key;
        }
      }
    });
  }

  void _onQuickIncrement(double addValue) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = double.tryParse(_rawAmount) ?? 0;
      final updated = current + addValue;
      _rawAmount = updated % 1 == 0
          ? updated.toStringAsFixed(0)
          : updated.toStringAsFixed(2);
    });
  }

  Future<void> _pickTransactionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: TakaPulseTheme.darkTheme.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: TakaPulseColors.primary,
              onPrimary: TakaPulseColors.onPrimary,
              surface: TakaPulseColors.surfaceContainer,
              onSurface: TakaPulseColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
        );
      });
    }
  }

  Future<void> _handleSaveEntry() async {
    final module = _activeModule;
    final parsed = double.tryParse(_rawAmount) ?? 0;
    if (module == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF93000A),
          content: Text('Enter an amount greater than ৳0 before saving.'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    await _db.logTransaction(
      module: module,
      amount: parsed,
      note: _noteController.text,
      date: _selectedDate,
    );

    if (!mounted) return;
    setState(() {
      _showSavedBanner = true;
      if (!module.isFixed) _rawAmount = '0';
    });

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showSavedBanner = false);
    });
  }

  Future<void> _handleCreateCustomModule() async {
    final name = _moduleNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF93000A),
          content: Text('Please enter a module name first.'),
        ),
      );
      return;
    }

    final presetClean = _presetAmountController.text.replaceAll(',', '').trim();
    final presetVal =
        _isNewModuleFixed ? double.tryParse(presetClean) : null;

    final newModule = ExpenseModule(
      name: name,
      subtitle: _isNewModuleFixed
          ? 'Fixed monthly envelope'
          : (_newModuleType == ModuleType.income
              ? 'Custom income stream'
              : 'Variable spending module'),
      type: _newModuleType,
      isFixed: _isNewModuleFixed,
      defaultAmount: presetVal,
      badgeText: _isNewModuleFixed ? 'Fixed Monthly' : 'Variable',
      iconKey: _selectedIconKey,
      accentColorValue: _selectedHueValue,
    );

    final newId = await _db.insertModule(newModule);
    _moduleNameController.clear();
    _presetAmountController.clear();

    await _loadModules(selectModuleId: newId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: TakaPulseColors.surfaceContainerHighest,
        content: Text("Created '${newModule.name}' module!"),
      ),
    );
  }

  void _openModulePickerSheet() {
    showModalBottomSheet<void>(
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
              'Select Active Module',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _modules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final m = _modules[idx];
                  final accent = Color(m.accentColorValue);
                  final isSelected = m.id == _activeModule?.id;

                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: isSelected
                        ? accent.withOpacity(0.16)
                        : TakaPulseColors.surfaceContainerLow,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _resolveIcon(m.iconKey),
                        color: accent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      m.isFixed && m.defaultAmount != null
                          ? 'Fixed: ৳ ${_formatDisplayAmount(m.defaultAmount!.toStringAsFixed(0))}'
                          : m.subtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      m.type == ModuleType.income ? '+ Income' : '- Expense',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: m.type == ModuleType.income
                            ? TakaPulseColors.primary
                            : TakaPulseColors.tertiary,
                      ),
                    ),
                    onTap: () {
                      _selectModule(m);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AmbientScaffold(
      appBar: _buildFrostedAppBar(textTheme),
      bottomNavigationBar: _buildFloatingNavBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Interactive Keypad Glass Panel
            _buildKeypadHeroCard(textTheme),
            const SizedBox(height: 22),

            // Section Divider Header: Module Manager
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: TakaPulseColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Module Manager', style: textTheme.titleMedium),
                  ],
                ),
                Text('Custom Categories', style: textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 12),

            // 2. New Flow Module Glass Configuration Panel
            _buildNewModulePanel(textTheme),
            const SizedBox(height: 20),

            // 3. Available Modules Horizontal Capsule Deck
            _buildQuickSelectDeck(textTheme),
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

  Widget _buildKeypadHeroCard(TextTheme textTheme) {
    final module = _activeModule;
    final isIncome = module?.type == ModuleType.income;
    final accent =
        module != null ? Color(module.accentColorValue) : TakaPulseColors.primary;
    final formattedDisplay = _formatDisplayAmount(_rawAmount);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateText = isToday
        ? 'Today, ${DateFormat('MMM dd').format(_selectedDate)}'
        : DateFormat('MMM dd, yyyy').format(_selectedDate);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      tintColor: TakaPulseColors.surfaceContainerHigh,
      opacity: 0.65,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Module Switcher Capsule & Date Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: _openModulePickerSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TakaPulseColors.surfaceContainerHighest
                              .withOpacity(0.75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.20),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _resolveIcon(module?.iconKey ?? 'school'),
                                size: 14,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                module?.name ?? 'Select Module',
                                style: textTheme.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (module != null &&
                                module.isFixed &&
                                module.defaultAmount != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: TakaPulseColors.primaryContainer
                                      .withOpacity(0.20),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '৳ ${_formatDisplayAmount(module.defaultAmount!.toStringAsFixed(0))}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: TakaPulseColors.primary,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: TakaPulseColors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _pickTransactionDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: TakaPulseColors.surfaceContainerLow
                            .withOpacity(0.75),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 13,
                            color: TakaPulseColors.secondary,
                          ),
                          const SizedBox(width: 5),
                          Text(dateText, style: textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Hero Digital Currency Display
              Column(
                children: [
                  Text(
                    isIncome ? 'EARNING AMOUNT' : 'EXPENSE AMOUNT',
                    style: textTheme.labelSmall?.copyWith(letterSpacing: 1.4),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '৳',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: TakaPulseColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedDisplay,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: TakaPulseColors.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      FadeTransition(
                        opacity: _cursorController,
                        child: Container(
                          width: 2.5,
                          height: 28,
                          decoration: BoxDecoration(
                            color: TakaPulseColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    module?.subtitle ?? 'Tap digits below to enter amount',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Note Sunken Glass Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      TakaPulseColors.surfaceContainerLowest.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: TakaPulseColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _noteController,
                        style: textTheme.bodyMedium,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Short note (e.g. November installment)...',
                          hintStyle: textTheme.bodySmall?.copyWith(
                            color: TakaPulseColors.onSurfaceVariant
                                .withOpacity(0.45),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _noteController.clear(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color:
                            TakaPulseColors.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3x4 Glassmorphic Keypad Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.85,
                children: [
                  '1', '2', '3',
                  '4', '5', '6',
                  '7', '8', '9',
                  '.', '0', 'backspace',
                ].map((key) {
                  final isBackspace = key == 'backspace';
                  final isSpecial = key == '.' || isBackspace;
                  return Material(
                    color: TakaPulseColors.surfaceContainerHighest
                        .withOpacity(isSpecial ? 0.32 : 0.45),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _onKeypadTap(key),
                      child: Center(
                        child: isBackspace
                            ? const Icon(
                                Icons.backspace_outlined,
                                size: 20,
                                color: TakaPulseColors.tertiary,
                              )
                            : Text(
                                key,
                                style: textTheme.headlineSmall,
                              ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Quick Increment Pills Row
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _QuickChip(
                    label: '+৳500',
                    onTap: () => _onQuickIncrement(500),
                  ),
                  _QuickChip(
                    label: '+৳1,000',
                    onTap: () => _onQuickIncrement(1000),
                  ),
                  _QuickChip(
                    label: '+৳2,000',
                    onTap: () => _onQuickIncrement(2000),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _rawAmount = '0'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF93000A).withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Clear',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: TakaPulseColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Primary Action: Save Entry
              Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      TakaPulseColors.secondaryContainer,
                      TakaPulseColors.primaryContainer,
                      TakaPulseColors.primary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: TakaPulseColors.primaryContainer.withOpacity(0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _handleSaveEntry,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: TakaPulseColors.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Save ৳$formattedDisplay Entry',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: TakaPulseColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Animated Success Toast Overlay inside Keypad Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            top: _showSavedBanner ? 0 : -64,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showSavedBanner ? 1.0 : 0.0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: TakaPulseColors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 20,
                      color: Color(0xFF00573F),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Entry saved to ${module?.name ?? 'Ledger'}!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00573F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewModulePanel(TextTheme textTheme) {
    final activeIconMeta = _iconCatalog.firstWhere(
      (item) => item.$1 == _selectedIconKey,
      orElse: () => _iconCatalog.first,
    );
    final activeHueMeta = _hueCatalog.firstWhere(
      (item) => item.$2 == _selectedHueValue,
      orElse: () => _hueCatalog.first,
    );
    final previewName = _moduleNameController.text.trim().isEmpty
        ? 'Custom'
        : _moduleNameController.text.trim();

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: TakaPulseColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.category_outlined,
                  color: TakaPulseColors.secondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Flow Module', style: textTheme.titleMedium),
                    Text(
                      'Define monthly budgeting envelopes',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      TakaPulseColors.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Preset',
                  style: textTheme.labelSmall?.copyWith(
                    color: TakaPulseColors.secondaryFixed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Module Name Input
          Text(
            'MODULE NAME',
            style: textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: TakaPulseColors.surfaceContainerLowest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.label_outline_rounded,
                  size: 20,
                  color: TakaPulseColors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _moduleNameController,
                    onChanged: (_) => setState(() {}),
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'e.g. House Rent, Internet Bill, Freelance',
                      hintStyle: textTheme.bodySmall?.copyWith(
                        color:
                            TakaPulseColors.onSurfaceVariant.withOpacity(0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Flow Direction Pill Toggle
          Text(
            'FLOW DIRECTION',
            style: textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: TakaPulseColors.surfaceContainerLowest.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _newModuleType = ModuleType.income),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _newModuleType == ModuleType.income
                            ? TakaPulseColors.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.south_west_rounded,
                            size: 18,
                            color: _newModuleType == ModuleType.income
                                ? const Color(0xFF00573F)
                                : TakaPulseColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Earning (+)',
                            style: textTheme.labelMedium?.copyWith(
                              color: _newModuleType == ModuleType.income
                                  ? const Color(0xFF00573F)
                                  : TakaPulseColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _newModuleType = ModuleType.expense),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _newModuleType == ModuleType.expense
                            ? const Color(0xFF93000A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.north_east_rounded,
                            size: 18,
                            color: _newModuleType == ModuleType.expense
                                ? const Color(0xFFFFDADB)
                                : TakaPulseColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Spending (-)',
                            style: textTheme.labelMedium?.copyWith(
                              color: _newModuleType == ModuleType.expense
                                  ? const Color(0xFFFFDADB)
                                  : TakaPulseColors.onSurfaceVariant,
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
          const SizedBox(height: 14),

          // 3. Module Icon Selector Carousel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MODULE ICON',
                style: textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
              ),
              Text(
                activeIconMeta.$2,
                style: textTheme.labelSmall?.copyWith(
                  color: TakaPulseColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _iconCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final item = _iconCatalog[idx];
                final isSelected = _selectedIconKey == item.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconKey = item.$1),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TakaPulseColors.primaryContainer.withOpacity(0.22)
                          : TakaPulseColors.surfaceContainerLow
                              .withOpacity(0.85),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.$3,
                      size: 20,
                      color: isSelected
                          ? TakaPulseColors.primary
                          : TakaPulseColors.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 4. Accent Hue Swatches
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACCENT HUE',
                style: textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
              ),
              Text(
                activeHueMeta.$1,
                style: textTheme.labelSmall?.copyWith(
                  color: TakaPulseColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _hueCatalog.map((hue) {
              final isSelected = _selectedHueValue == hue.$2;
              return GestureDetector(
                onTap: () => setState(() => _selectedHueValue = hue.$2),
                child: AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(hue.$2),
                      shape: BoxShape.circle,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Color(hue.$2).withOpacity(0.55),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: TakaPulseColors.onPrimary,
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // 5. Fixed vs Variable Amount Logic
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TakaPulseColors.surfaceContainerLow.withOpacity(0.75),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fixed Monthly Amount',
                            style: textTheme.labelMedium,
                          ),
                          Text(
                            'Auto-prefills keypad for quick logging',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isNewModuleFixed,
                      activeColor: Colors.white,
                      activeTrackColor: TakaPulseColors.primaryContainer,
                      onChanged: (val) =>
                          setState(() => _isNewModuleFixed = val),
                    ),
                  ],
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isNewModuleFixed ? 1.0 : 0.35,
                  child: IgnorePointer(
                    ignoring: !_isNewModuleFixed,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'PRESET AMOUNT (৳)',
                          style:
                              textTheme.labelSmall?.copyWith(letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: TakaPulseColors.surfaceContainerLowest
                                .withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '৳',
                                style: textTheme.headlineSmall?.copyWith(
                                  color: TakaPulseColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _presetAmountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: textTheme.titleMedium,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'e.g. 2500',
                                    hintStyle: textTheme.bodySmall?.copyWith(
                                      color: TakaPulseColors.onSurfaceVariant
                                          .withOpacity(0.45),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Create Module CTA Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF363847),
                foregroundColor: TakaPulseColors.onSurface,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              onPressed: _handleCreateCustomModule,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                "Create '$previewName' Module",
                style: textTheme.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSelectDeck(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'QUICK SELECT MODULES',
              style: textTheme.labelMedium?.copyWith(
                color: TakaPulseColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'Tap to switch',
              style: textTheme.labelSmall?.copyWith(
                color: TakaPulseColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _modules.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, idx) {
              final m = _modules[idx];
              final isSelected = m.id == _activeModule?.id;
              final accent = Color(m.accentColorValue);

              return GestureDetector(
                onTap: () => _selectModule(m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? TakaPulseColors.secondaryContainer.withOpacity(0.20)
                        : TakaPulseColors.surfaceContainerHigh.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withOpacity(0.25)
                              : TakaPulseColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _resolveIcon(m.iconKey),
                          size: 16,
                          color: isSelected
                              ? accent
                              : TakaPulseColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: textTheme.labelMedium?.copyWith(
                              color: isSelected
                                  ? TakaPulseColors.secondaryFixed
                                  : TakaPulseColors.onSurface,
                            ),
                          ),
                          Text(
                            m.isFixed && m.defaultAmount != null
                                ? '৳ ${_formatDisplayAmount(m.defaultAmount!.toStringAsFixed(0))}'
                                : 'Variable',
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: isSelected
                                  ? TakaPulseColors.secondaryFixed
                                      .withOpacity(0.85)
                                  : TakaPulseColors.onSurfaceVariant
                                      .withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
        return Icons.restaurant_rounded;
      case 'directions_bus':
        return Icons.directions_bus_outlined;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_outlined;
      case 'medication':
        return Icons.medication_outlined;
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

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: TakaPulseColors.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TakaPulseColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}