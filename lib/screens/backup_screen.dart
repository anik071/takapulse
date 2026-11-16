import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../services/drive_backup_service.dart';

class BackupScreen extends StatefulWidget {
  final int currentNavIndex;
  final ValueChanged<int>? onNavigate;

  const BackupScreen({
    super.key,
    this.currentNavIndex = 3,
    this.onNavigate,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen>
    with SingleTickerProviderStateMixin {
  final DriveBackupService _backupService = DriveBackupService();

  GoogleSignInAccount? _account;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _showSyncToast = false;

  // Auto-Backup Engine toggle states
  bool _wifiOnly = true;
  bool _dailySync = true;
  bool _includePdf = false;

  String _lastBackupText = 'Yesterday at 11:42 PM';
  int _txCount = 482;
  int _moduleCount = 8;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initScreen();
  }

  Future<void> _initScreen() async {
    final settings = await _backupService.loadSettings();
    final silentUser = await _backupService.signInSilently();
    if (!mounted) return;
    setState(() {
      _wifiOnly = settings[DriveBackupService.keyWifiOnly] ?? true;
      _dailySync = settings[DriveBackupService.keyDailySync] ?? true;
      _includePdf = settings[DriveBackupService.keyIncludePdf] ?? false;
      _account = silentUser;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleSignInOrSwitch() async {
    try {
      if (_account != null) {
        await _backupService.signOut();
      }
      final user = await _backupService.signIn();
      if (mounted) {
        setState(() => _account = user);
      }
    } catch (e) {
      _showSnack('Google Sign-In failed: $e', isError: true);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TakaPulseColors.surfaceContainer,
        title: const Text('Disconnect Google Drive?'),
        content: const Text(
          'Automatic daily cloud backups will pause until you sign back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: TakaPulseColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _backupService.signOut();
      if (mounted) setState(() => _account = null);
    }
  }

  Future<void> _handleBackupNow() async {
    if (_isBackingUp) return;
    setState(() => _isBackingUp = true);

    try {
      final success = await _backupService.backupDatabaseToDrive(
        includePdfs: _includePdf,
      );
      if (!mounted) return;

      if (success) {
        setState(() {
          _account = _backupService.currentUser ?? _account;
          _lastBackupText = 'Just now';
          _showSyncToast = true;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showSyncToast = false);
        });
      }
    } catch (e) {
      _showSnack('Backup failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleRestore() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);

    try {
      final success = await _backupService.restoreDatabaseFromDrive();
      if (!mounted) return;
      _showSnack(
        success
            ? 'Records restored from Google Drive!'
            : 'No backup snapshot found in Drive.',
        isError: !success,
      );
    } catch (e) {
      _showSnack('Restore failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFF93000A)
            : TakaPulseColors.surfaceContainerHigh,
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
            // Delight Sync Toast Banner
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showSyncToast
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildSyncToast(textTheme),
                    )
                  : const SizedBox.shrink(),
            ),

            // 1. Google Account Profile Card
            _buildGoogleProfileCard(textTheme),
            const SizedBox(height: 20),

            // 2. Cloud Storage Status Card
            _buildStorageStatusCard(textTheme),
            const SizedBox(height: 20),

            // 3. Primary & Secondary CTAs
            _buildActionButtons(textTheme),
            const SizedBox(height: 20),

            // 4. Auto-Backup Engine Card
            _buildAutoBackupCard(textTheme),
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
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: TakaPulseColors.surfaceContainerHigh,
                  backgroundImage: _account?.photoUrl != null
                      ? NetworkImage(_account!.photoUrl!)
                      : null,
                  child: _account?.photoUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 18,
                          color: TakaPulseColors.primary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncToast(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TakaPulseColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TakaPulseColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: TakaPulseColors.primaryContainer.withOpacity(0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: TakaPulseColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TakaPulse vault synced to Google Drive!',
              style: textTheme.labelMedium?.copyWith(
                color: TakaPulseColors.primary,
              ),
            ),
          ),
          Text('Just now', style: textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildGoogleProfileCard(TextTheme textTheme) {
    final isConnected = _account != null;
    final displayName = _account?.displayName ?? 'Samira Rahman';
    final email = _account?.email ?? 'samira.rahman@gmail.com';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: TakaPulseColors.surfaceContainerHigh.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_to_drive_rounded,
                      size: 15,
                      color: TakaPulseColors.secondaryFixed,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Drive Connected' : 'Local Mode',
                      style: textTheme.labelSmall?.copyWith(
                        color: TakaPulseColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: TakaPulseColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: Tween<double>(begin: 0.45, end: 1.0)
                          .animate(_pulseController),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: TakaPulseColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: TakaPulseColors.primary.withOpacity(0.8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Connected' : 'Ready to Link',
                      style: textTheme.labelSmall?.copyWith(
                        color: TakaPulseColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Avatar & User Details
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: TakaPulseColors.surfaceContainerHighest,
                      image: _account?.photoUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_account!.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _account?.photoUrl == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 30,
                            color: TakaPulseColors.primary,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: TakaPulseColors.surfaceContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 15,
                        color: TakaPulseColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'TakaPulse Personal Vault',
                      style: textTheme.labelSmall?.copyWith(
                        color: TakaPulseColors.secondaryFixedDim,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Switch Account & Sign Out Strip
          Row(
            children: [
              Expanded(
                child: _SecondaryPillButton(
                  icon: Icons.switch_account_outlined,
                  label: isConnected ? 'Switch Account' : 'Sign in with Google',
                  backgroundColor:
                      TakaPulseColors.surfaceContainerHighest.withOpacity(0.45),
                  foregroundColor: TakaPulseColors.onSurface,
                  onTap: _handleSignInOrSwitch,
                ),
              ),
              if (isConnected) ...[
                const SizedBox(width: 10),
                _SecondaryPillButton(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  backgroundColor:
                      TakaPulseColors.surfaceContainerHighest.withOpacity(0.25),
                  foregroundColor: TakaPulseColors.error,
                  onTap: _handleSignOut,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStorageStatusCard(TextTheme textTheme) {
    return GlassCard(
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: TakaPulseColors.secondaryContainer.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_queue_rounded,
                  color: TakaPulseColors.secondaryFixed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Storage Allocated', style: textTheme.titleMedium),
                    Text(
                      'TakaPulse Snapshot Folder',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '4.2 MB',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TakaPulseColors.primary,
                    ),
                  ),
                  Text('of 15 GB free', style: textTheme.labelSmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Gradient Progress Bar
          Container(
            height: 10,
            width: double.infinity,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: TakaPulseColors.surfaceContainerHighest.withOpacity(0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.05,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [
                        TakaPulseColors.secondaryFixedDim,
                        TakaPulseColors.primary,
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: TakaPulseColors.primary,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.02% Drive capacity', style: textTheme.labelSmall),
              Text(
                '14.99 GB available',
                style: textTheme.labelSmall?.copyWith(
                  color: TakaPulseColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Telemetry Detail Rows
          _buildTelemetryRow(
            textTheme: textTheme,
            icon: Icons.cloud_upload_outlined,
            iconColor: TakaPulseColors.secondaryFixedDim,
            title: 'Last Backup',
            subtitle: _lastBackupText,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TakaPulseColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Auto-sync', style: textTheme.labelSmall),
            ),
          ),
          const SizedBox(height: 8),
          _buildTelemetryRow(
            textTheme: textTheme,
            icon: Icons.dataset_outlined,
            iconColor: TakaPulseColors.primary,
            title: 'Total Records Synced',
            subtitle: '$_txCount transactions, $_moduleCount modules',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TakaPulseColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Complete',
                style: textTheme.labelSmall?.copyWith(
                  color: TakaPulseColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTelemetryRow(
            textTheme: textTheme,
            icon: Icons.enhanced_encryption_rounded,
            iconColor: TakaPulseColors.primary,
            title: 'Encryption Standards',
            subtitle: 'AES-256 Client-Side Encrypted',
            trailing: const Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: TakaPulseColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow({
    required TextTheme textTheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TakaPulseColors.surfaceContainerHigh.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.labelMedium),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildActionButtons(TextTheme textTheme) {
    return Column(
      children: [
        // Primary Glowing Gradient Button
        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                TakaPulseColors.secondaryContainer,
                TakaPulseColors.primaryContainer,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: TakaPulseColors.primaryContainer.withOpacity(0.42),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _handleBackupNow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isBackingUp)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: TakaPulseColors.onPrimaryFixed,
                      ),
                    )
                  else
                    const Icon(
                      Icons.cloud_upload_outlined,
                      size: 23,
                      color: TakaPulseColors.onPrimaryFixed,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _isBackingUp
                        ? 'Securing snapshot...'
                        : 'Backup Now to Drive',
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
        const SizedBox(height: 12),

        // Secondary Restore Button
        SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  TakaPulseColors.surfaceContainerHigh.withOpacity(0.75),
              foregroundColor: TakaPulseColors.onSurface,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            onPressed: _handleRestore,
            icon: _isRestoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: TakaPulseColors.secondaryFixed,
                    ),
                  )
                : const Icon(
                    Icons.cloud_download_outlined,
                    size: 20,
                    color: TakaPulseColors.secondaryFixed,
                  ),
            label: Text(
              _isRestoring ? 'Merging Vault...' : 'Restore from Drive',
              style: textTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: TakaPulseColors.tertiary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                'Will safely merge cloud archive with local TakaPulse changes',
                style: textTheme.labelSmall?.copyWith(
                  color: TakaPulseColors.onSurfaceVariant.withOpacity(0.85),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoBackupCard(TextTheme textTheme) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto-Backup Engine', style: textTheme.titleMedium),
                  Text(
                    'Set automated cloud syncing triggers',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: TakaPulseColors.surfaceContainerHighest.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: TakaPulseColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildEngineToggle(
            textTheme: textTheme,
            icon: Icons.wifi_rounded,
            iconColor: TakaPulseColors.primary,
            title: 'Auto Backup on Wi-Fi',
            subtitle: 'Preserve mobile cellular data bundles',
            value: _wifiOnly,
            onChanged: (val) {
              setState(() => _wifiOnly = val);
              _backupService.saveSetting(DriveBackupService.keyWifiOnly, val);
            },
          ),
          const SizedBox(height: 14),
          _buildEngineToggle(
            textTheme: textTheme,
            icon: Icons.schedule_rounded,
            iconColor: TakaPulseColors.secondaryFixed,
            title: 'Daily Scheduled Sync',
            subtitle: 'Syncs automatically every morning (2:00 AM)',
            value: _dailySync,
            onChanged: (val) {
              setState(() => _dailySync = val);
              _backupService.saveSetting(DriveBackupService.keyDailySync, val);
            },
          ),
          const SizedBox(height: 14),
          _buildEngineToggle(
            textTheme: textTheme,
            icon: Icons.picture_as_pdf_outlined,
            iconColor: TakaPulseColors.tertiary,
            title: 'Include PDF Statements',
            subtitle: 'Saves generated monthly expense summaries',
            value: _includePdf,
            onChanged: (val) {
              setState(() => _includePdf = val);
              _backupService.saveSetting(DriveBackupService.keyIncludePdf, val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEngineToggle({
    required TextTheme textTheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: TakaPulseColors.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.labelMedium),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: TakaPulseColors.primaryContainer,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: TakaPulseColors.surfaceContainerHighest,
        ),
      ],
    );
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

class _SecondaryPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _SecondaryPillButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
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