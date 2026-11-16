import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/backup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/quick_log_screen.dart';
import 'screens/reports_screen.dart';
import 'services/pdf_report_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge dark status bar for glassmorphism backdrop
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TakaPulseColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Schedule daily background check for automatic month-end PDF generation
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'takapulse-monthly-pdf-check',
    PdfReportService.monthEndTaskName,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  runApp(const TakaPulseApp());
}

class TakaPulseApp extends StatelessWidget {
  const TakaPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TakaPulse',
      debugShowCheckedModeBanner: false,
      theme: TakaPulseTheme.darkTheme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkMonthEndAutomation();
  }

  /// Automatically generates previous month's PDF statement when a new month begins
  Future<void> _checkMonthEndAutomation() async {
    final generated =
        await PdfReportService.instance.checkAndRunMonthEndExport();
    if (!mounted || generated == null) return;

    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        backgroundColor: TakaPulseColors.surfaceContainerHigh,
        content: Text(
          'Monthly PDF ready: ${generated.fileName}',
          style: const TextStyle(color: TakaPulseColors.onSurface),
        ),
        action: SnackBarAction(
          label: 'Send Now',
          textColor: TakaPulseColors.primary,
          onPressed: () {
            PdfReportService.instance.shareStatementPdf(previousMonth);
          },
        ),
      ),
    );
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return HomeScreen(
          currentNavIndex: 0,
          onNavigate: _onTabSelected,
        );
      case 1:
        return QuickLogScreen(
          currentNavIndex: 1,
          onNavigate: _onTabSelected,
        );
      case 2:
        return ReportsScreen(
          currentNavIndex: 2,
          onNavigate: _onTabSelected,
        );
      case 3:
        return BackupScreen(
          currentNavIndex: 3,
          onNavigate: _onTabSelected,
        );
      default:
        return HomeScreen(
          currentNavIndex: 0,
          onNavigate: _onTabSelected,
        );
    }
  }
}