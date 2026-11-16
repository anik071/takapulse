import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class BackupMetadata {
  final String lastBackupLabel;
  final String fileSizeLabel;
  final int transactionCount;
  final int moduleCount;

  const BackupMetadata({
    required this.lastBackupLabel,
    required this.fileSizeLabel,
    required this.transactionCount,
    required this.moduleCount,
  });
}

class DriveBackupService {
  static const String _dbFileName = 'takapulse_vault.db';
  static const String _backupDriveName = 'takapulse_vault_backup.db';

  // Preference keys for Auto-Backup Engine toggles
  static const String keyWifiOnly = 'backup_wifi_only';
  static const String keyDailySync = 'backup_daily_sync';
  static const String keyIncludePdf = 'backup_include_pdf';
  static const String keyLastBackupTime = 'backup_last_timestamp';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() async {
    return await _googleSignIn.signInSilently();
  }

  Future<GoogleSignInAccount?> signIn() async {
    return await _googleSignIn.signIn();
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (account == null) return null;
    final headers = await account.authHeaders;
    return drive.DriveApi(GoogleAuthClient(headers));
  }

  /// Uploads local SQLite DB (and optional PDFs) to Drive's hidden appDataFolder
  Future<bool> backupDatabaseToDrive({bool includePdfs = false}) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    final dbFolder = await getDatabasesPath();
    final dbFile = File(p.join(dbFolder, _dbFileName));
    if (!await dbFile.exists()) return false;

    // Search for existing backup in appDataFolder to overwrite cleanly
    final existingFiles = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupDriveName' and trashed = false",
      $fields: 'files(id, name)',
    );

    final media = drive.Media(dbFile.openRead(), await dbFile.length());

    if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
      final fileId = existingFiles.files!.first.id!;
      await driveApi.files.update(
        drive.File()..name = _backupDriveName,
        fileId,
        uploadMedia: media,
      );
    } else {
      final driveFile = drive.File()
        ..name = _backupDriveName
        ..parents = ['appDataFolder'];
      await driveApi.files.create(driveFile, uploadMedia: media);
    }

    // Optionally upload generated monthly PDF statements
    if (includePdfs) {
      await _uploadMonthlyPdfs(driveApi);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastBackupTime, DateTime.now().toIso8601String());
    return true;
  }

  Future<void> _uploadMonthlyPdfs(drive.DriveApi driveApi) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(docsDir.path, 'statements'));
    if (!await pdfDir.exists()) return;

    for (final entity in pdfDir.listSync()) {
      if (entity is File && entity.path.endsWith('.pdf')) {
        final pdfName = p.basename(entity.path);
        final existing = await driveApi.files.list(
          spaces: 'appDataFolder',
          q: "name = '$pdfName' and trashed = false",
          $fields: 'files(id)',
        );
        final media = drive.Media(entity.openRead(), await entity.length());
        if (existing.files != null && existing.files!.isNotEmpty) {
          await driveApi.files.update(
            drive.File()..name = pdfName,
            existing.files!.first.id!,
            uploadMedia: media,
          );
        } else {
          await driveApi.files.create(
            drive.File()
              ..name = pdfName
              ..parents = ['appDataFolder'],
            uploadMedia: media,
          );
        }
      }
    }
  }

  /// Downloads backup DB from Drive appDataFolder and replaces local SQLite file
  Future<bool> restoreDatabaseFromDrive({
    Future<void> Function()? onBeforeOverwrite,
    Future<void> Function()? onAfterRestore,
  }) async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) return false;

    final fileList = await driveApi.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupDriveName' and trashed = false",
      $fields: 'files(id, name)',
    );

    if (fileList.files == null || fileList.files!.isEmpty) return false;

    final fileId = fileList.files!.first.id!;
    final response = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final dbFolder = await getDatabasesPath();
    final targetFile = File(p.join(dbFolder, _dbFileName));

    // Close active SQLite connection before replacing file
    if (onBeforeOverwrite != null) await onBeforeOverwrite();

    final sink = targetFile.openWrite();
    await response.stream.pipe(sink);
    await sink.close();

    // Re-initialize SQLite database
    if (onAfterRestore != null) await onAfterRestore();
    return true;
  }

  Future> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      keyWifiOnly: prefs.getBool(keyWifiOnly) ?? true,
      keyDailySync: prefs.getBool(keyDailySync) ?? true,
      keyIncludePdf: prefs.getBool(keyIncludePdf) ?? false,
    };
  }

  Future<void> saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}