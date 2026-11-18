import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;
import 'package:another_telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto/crypto.dart';

const _pink = Color(0xFFFF2D68);
const _deepPink = Color(0xFFD41467);
const _pagePink = Color(0xFFFFF4F8);
const _navy = Color(0xFF172033);
const _green = Color(0xFF008F65);
final _navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier(ThemeMode.light);
const _shakeChannel = MethodChannel('proteqt/shake');
bool _shakeFlowActive = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  _themeModeNotifier.value = preferences.getBool('dark_theme') == true ? ThemeMode.dark : ThemeMode.light;
  runApp(const ProteqtApp());
  unawaited(EvidenceTransferService.instance.load());
  _shakeChannel.setMethodCallHandler((call) async {
    if (call.method == 'shakeDetected') {
      await _handleBackgroundShake();
    }
  });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeSafetyReminderService());
  });
}

Future<void> _initializeSafetyReminderService() async {
  try {
    await SafetyReminderService.initialize();
  } catch (error, stackTrace) {
    debugPrint('SafetyReminderService startup failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class ProteqtApp extends StatelessWidget {
  const ProteqtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'PROTEQT',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _pink),
          scaffoldBackgroundColor: _pagePink,
          fontFamily: 'Arial',
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _pink, brightness: Brightness.dark),
          fontFamily: 'Arial',
          useMaterial3: true,
        ),
        home: const _AppGate(),
      ),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  Future<SafetyProfile?>? _profile;

  @override
  void initState() {
    super.initState();
    final completer = Completer<SafetyProfile?>();
    _profile = completer.future;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        completer.complete(await SafetyProfile.load());
      } catch (error, stackTrace) {
        debugPrint('SafetyProfile startup load failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        completer.complete(null);
      }
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SafetyProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: _pink)));
          }
          final profile = snapshot.data;
          return profile == null
              ? RegistrationScreen(onSaved: (saved) => setState(() => _profile = Future.value(saved)))
              : HomeScreen(profile: profile);
        },
      );
}

class SafetyProfile {
  const SafetyProfile({required this.fullName, required this.mobileNumber, required this.dateOfBirth, required this.bloodGroup, required this.emergencyName, required this.emergencyPhone, required this.sosEmergencyNumber, required this.notes});

  final String fullName;
  final String mobileNumber;
  final String dateOfBirth;
  final String bloodGroup;
  final String emergencyName;
  final String emergencyPhone;
  final String sosEmergencyNumber;
  final String notes;

  static const _registered = 'profile_registered';

  static Future<SafetyProfile?> load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_registered) ?? false)) return null;
    return SafetyProfile(
      fullName: preferences.getString('full_name') ?? '',
      mobileNumber: preferences.getString('mobile_number') ?? '',
      dateOfBirth: preferences.getString('date_of_birth') ?? '',
      bloodGroup: preferences.getString('blood_group') ?? '',
      emergencyName: preferences.getString('emergency_name') ?? '',
      emergencyPhone: preferences.getString('emergency_phone') ?? '',
      sosEmergencyNumber: preferences.getString('sos_emergency_number') ?? '',
      notes: preferences.getString('notes') ?? '',
    );
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_registered, true);
    await Future.wait([
      preferences.setString('full_name', fullName),
      preferences.setString('mobile_number', mobileNumber),
      preferences.setString('date_of_birth', dateOfBirth),
      preferences.setString('blood_group', bloodGroup),
      preferences.setString('emergency_name', emergencyName),
      preferences.setString('emergency_phone', emergencyPhone),
      preferences.setString('sos_emergency_number', sosEmergencyNumber),
      preferences.setString('notes', notes),
    ]);
  }

  SafetyProfile copyWith({String? sosEmergencyNumber}) => SafetyProfile(
        fullName: fullName,
        mobileNumber: mobileNumber,
        dateOfBirth: dateOfBirth,
        bloodGroup: bloodGroup,
        emergencyName: emergencyName,
        emergencyPhone: emergencyPhone,
        sosEmergencyNumber: sosEmergencyNumber ?? this.sosEmergencyNumber,
        notes: notes,
      );
}

class HistoryEvent {
  const HistoryEvent({required this.id, required this.eventType, required this.timestamp, required this.description, this.latitude, this.longitude, this.accuracy, this.evidence = const []});

  final int id;
  final String eventType;
  final DateTime timestamp;
  final String description;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final List<EvidenceRecord> evidence;

  factory HistoryEvent.fromMap(Map<String, Object?> map) => HistoryEvent(
        id: map['id'] as int,
        eventType: map['eventType'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        description: map['description'] as String,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        accuracy: (map['accuracy'] as num?)?.toDouble(),
      );
}

class EvidenceRecord {
  const EvidenceRecord({required this.id, required this.filePath, required this.evidenceType, required this.timestamp, required this.historyEventId, this.relatedEventType, this.latitude, this.longitude});

  final int id;
  final String filePath;
  final String evidenceType;
  final DateTime timestamp;
  final int historyEventId;
  final String? relatedEventType;
  final double? latitude;
  final double? longitude;

  factory EvidenceRecord.fromMap(Map<String, Object?> map) => EvidenceRecord(
        id: map['id'] as int,
        filePath: map['filePath'] as String,
        evidenceType: map['evidenceType'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        historyEventId: map['historyEventId'] as int,
        relatedEventType: map['relatedEventType'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );
}

class HistoryDatabase {
  HistoryDatabase._();

  static final HistoryDatabase instance = HistoryDatabase._();
  static const _databaseName = 'proteqt_history.db';
  static const _tableName = 'history';
  static const _evidenceTableName = 'evidence';
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasesPath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasesPath, _databaseName),
      version: 2,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eventType TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            description TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            accuracy REAL
          )
        ''');
        await database.execute('''
          CREATE TABLE $_evidenceTableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filePath TEXT NOT NULL,
            evidenceType TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            historyEventId INTEGER NOT NULL,
            latitude REAL,
            longitude REAL,
            FOREIGN KEY(historyEventId) REFERENCES $_tableName(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('ALTER TABLE $_tableName ADD COLUMN latitude REAL');
          await database.execute('ALTER TABLE $_tableName ADD COLUMN longitude REAL');
          await database.execute('ALTER TABLE $_tableName ADD COLUMN accuracy REAL');
          await database.execute('''
            CREATE TABLE $_evidenceTableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              filePath TEXT NOT NULL,
              evidenceType TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              historyEventId INTEGER NOT NULL,
              latitude REAL,
              longitude REAL,
              FOREIGN KEY(historyEventId) REFERENCES $_tableName(id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
    return _database!;
  }

  Future<int?> insertEvent({required String eventType, required String description, double? latitude, double? longitude, double? accuracy}) async {
    try {
      final database = await this.database;
      return await database.insert(_tableName, {
        'eventType': eventType,
        'timestamp': DateTime.now().toIso8601String(),
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      });
    } catch (_) {
      return null;
    }
  }

  Future<List<HistoryEvent>> getEvents() async {
    try {
      final database = await this.database;
      final rows = await database.query(_tableName, orderBy: 'timestamp DESC, id DESC');
      final events = <HistoryEvent>[];
      for (final row in rows) {
        final event = HistoryEvent.fromMap(row);
        events.add(HistoryEvent(id: event.id, eventType: event.eventType, timestamp: event.timestamp, description: event.description, latitude: event.latitude, longitude: event.longitude, accuracy: event.accuracy, evidence: await getEvidenceForEvent(event.id)));
      }
      return events;
    } catch (_) {
      return const <HistoryEvent>[];
    }
  }

  Future<List<EvidenceRecord>> getAllEvidence() async {
    try {
      final database = await this.database;
      final rows = await database.rawQuery('SELECT e.*, h.eventType AS relatedEventType FROM $_evidenceTableName e LEFT JOIN $_tableName h ON h.id = e.historyEventId ORDER BY e.timestamp DESC, e.id DESC');
      return rows.map(EvidenceRecord.fromMap).toList();
    } catch (_) {
      return const <EvidenceRecord>[];
    }
  }

  Future<List<EvidenceRecord>> getEvidenceForEvent(int eventId) async {
    try {
      final database = await this.database;
      final rows = await database.rawQuery('SELECT e.*, h.eventType AS relatedEventType FROM $_evidenceTableName e LEFT JOIN $_tableName h ON h.id = e.historyEventId WHERE e.historyEventId = ? ORDER BY e.timestamp DESC, e.id DESC', [eventId]);
      return rows.map(EvidenceRecord.fromMap).toList();
    } catch (_) {
      return const <EvidenceRecord>[];
    }
  }

  Future<bool> insertEvidence({required String filePath, required String evidenceType, required int historyEventId, double? latitude, double? longitude}) async {
    try {
      final database = await this.database;
      await database.insert(_evidenceTableName, {
        'filePath': filePath,
        'evidenceType': evidenceType,
        'timestamp': DateTime.now().toIso8601String(),
        'historyEventId': historyEventId,
        'latitude': latitude,
        'longitude': longitude,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteEvidence(int evidenceId) async {
    try {
      final database = await this.database;
      await database.delete(_evidenceTableName, where: 'id = ?', whereArgs: [evidenceId]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> clear() async {
    try {
      final database = await this.database;
      await database.delete(_tableName);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class EvidenceTransferService {
  EvidenceTransferService._();

  static final instance = EvidenceTransferService._();
  static const _enabledKey = 'evidence_transfer_enabled';
  static const _tokenKey = 'evidence_transfer_pairing_token';
  static const port = 8765;
  final status = ValueNotifier<String>('Transfer server disabled.');
  final evidenceChanged = ValueNotifier<int>(0);
  HttpServer? _server;
  String? _token;
  final Set<String> _receivedHashes = <String>{};
  DateTime? _lastHardwareAlertAt;
  bool _hardwareAlertInFlight = false;

  bool get enabled => _server != null;
  String get pairingToken => _token ?? '';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _token = preferences.getString(_tokenKey);
    if (_token == null || _token!.length < 32) {
      _token = _newToken();
      await preferences.setString(_tokenKey, _token!);
    }
    _receivedHashes.addAll(preferences.getStringList('evidence_transfer_hashes') ?? const []);
    if (preferences.getBool(_enabledKey) == true) {
      await start();
    }
  }

  Future<void> start() async {
    if (_server != null) return;
    try {
      _token ??= _newToken();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _server!.listen(_handleRequest, onError: (Object error, StackTrace stack) {
        status.value = 'Transfer server error: $error';
      });
      final address = await _localAddress();
      status.value = 'Ready on $address:$port. Pairing required.';
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_enabledKey, true);
    } catch (error) {
      _server = null;
      status.value = 'Unable to start transfer server: $error';
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    status.value = 'Transfer server disabled.';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, false);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method == 'GET' && request.uri.path == '/status') {
      await _respond(request, HttpStatus.ok, {'enabled': enabled, 'port': port});
      return;
    }
    if (request.method != 'POST' || (request.uri.path != '/pair' && request.uri.path != '/upload' && request.uri.path != '/hardware-alert')) {
      await _respond(request, HttpStatus.notFound, {'error': 'Not found'});
      return;
    }
    if (!_authorized(request)) {
      await _respond(request, HttpStatus.unauthorized, {'error': 'Pairing required'});
      return;
    }
    if (request.uri.path == '/pair') {
      status.value = 'Windows sender paired successfully.';
      await _respond(request, HttpStatus.ok, {'paired': true});
      return;
    }
    if (request.uri.path == '/hardware-alert') {
      await _handleHardwareAlert(request);
      return;
    }
    await _receiveUpload(request);
  }

  Future<void> _handleHardwareAlert(HttpRequest request) async {
    final now = DateTime.now();
    final lastAlertAt = _lastHardwareAlertAt;
    if (_hardwareAlertInFlight || (lastAlertAt != null && now.difference(lastAlertAt) < const Duration(seconds: 30))) {
      await _respond(request, HttpStatus.tooManyRequests, {
        'error': 'Hardware alert already handled recently',
        'duplicate': true,
        'retryAfterSeconds': 30,
      });
      return;
    }

    final profile = await SafetyProfile.load();
    if (profile == null) {
      await _respond(request, HttpStatus.unprocessableEntity, {'error': 'Safety profile is not configured'});
      return;
    }
    final phone = profile.emergencyPhone.trim();
    if (phone.isEmpty) {
      await _respond(request, HttpStatus.unprocessableEntity, {'error': 'Emergency phone is not configured'});
      return;
    }

    _hardwareAlertInFlight = true;
    _lastHardwareAlertAt = now;
    try {
      final permissionResults = await Future.wait<PermissionStatus>([
        Permission.sms.request(),
        Permission.phone.request(),
      ]);
      final smsPermissionGranted = permissionResults[0].isGranted;
      final phonePermissionGranted = permissionResults[1].isGranted;
      final smsFuture = smsPermissionGranted ? _sendHardwareAlertSms(phone) : Future.value(false);
      final callFuture = phonePermissionGranted ? _callHardwareAlert(phone) : Future.value(false);
      final results = await Future.wait<bool>([smsFuture, callFuture]);
      final smsSent = results[0];
      final callStarted = results[1];
      await HistoryDatabase.instance.insertEvent(
        eventType: smsSent && callStarted ? 'HARDWARE_ALERT_SENT' : 'HARDWARE_ALERT_FAILED',
        description: 'Hardware alert requested. SMS: ${smsSent ? 'sent' : 'failed'}; call: ${callStarted ? 'initiated' : 'failed'}.',
      );
      await _respond(request, smsSent && callStarted ? HttpStatus.ok : HttpStatus.multiStatus, {
        'sms': {'success': smsSent, 'permissionGranted': smsPermissionGranted},
        'call': {'success': callStarted, 'permissionGranted': phonePermissionGranted},
      });
    } catch (error, stackTrace) {
      debugPrint('Hardware alert failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await HistoryDatabase.instance.insertEvent(
        eventType: 'HARDWARE_ALERT_FAILED',
        description: 'Hardware alert failed unexpectedly: $error',
      );
      await _respond(request, HttpStatus.internalServerError, {
        'error': 'Hardware alert could not be completed',
        'sms': {'success': false},
        'call': {'success': false},
      });
    } finally {
      _hardwareAlertInFlight = false;
    }
  }

  Future<bool> _sendHardwareAlertSms(String phone) async {
    try {
      final completer = Completer<bool>();
      await Telephony.instance.sendSms(
        to: phone,
        message: 'PROTEQT EMERGENCY ALERT: I need help. Please contact me immediately.',
        statusListener: (status) {
          if (!completer.isCompleted) completer.complete(status == SendStatus.SENT);
        },
      );
      return await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
    } catch (error, stackTrace) {
      debugPrint('Hardware alert SMS failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> _callHardwareAlert(String phone) async {
    try {
      return await FlutterPhoneDirectCaller.callNumber(phone) ?? false;
    } catch (error, stackTrace) {
      debugPrint('Hardware alert call failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  bool _authorized(HttpRequest request) {
    final supplied = request.headers.value('x-proteqt-token');
    final expected = _token;
    if (supplied == null || expected == null || supplied.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= supplied.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }

  Future<void> _receiveUpload(HttpRequest request) async {
    final fileName = Uri.decodeComponent(request.headers.value('x-filename') ?? 'camera_photo.jpg');
    final extension = path.extension(fileName).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(extension)) {
      await _respond(request, HttpStatus.unsupportedMediaType, {'error': 'Only JPG, JPEG, PNG, and WEBP are accepted'});
      return;
    }
    final contentLength = request.headers.contentLength;
    if (contentLength > 25 * 1024 * 1024) {
      await _respond(request, HttpStatus.requestEntityTooLarge, {'error': 'File is too large'});
      return;
    }
    final bytes = Uint8List.fromList(await request.fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk)));
    if (bytes.isEmpty) {
      await _respond(request, HttpStatus.badRequest, {'error': 'Empty file'});
      return;
    }
    final hash = sha256.convert(bytes).toString();
    final suppliedHash = request.headers.value('x-sha256');
    if (suppliedHash == null || suppliedHash.toLowerCase() != hash) {
      await _respond(request, HttpStatus.unprocessableEntity, {'error': 'Integrity verification failed'});
      return;
    }
    if (_receivedHashes.contains(hash)) {
      status.value = 'Duplicate skipped: $fileName';
      await _respond(request, HttpStatus.ok, {'stored': false, 'duplicate': true});
      return;
    }
    final stored = await _saveReceivedEvidence(bytes, fileName);
    if (!stored) {
      status.value = 'Transfer failed while saving $fileName.';
      await _respond(request, HttpStatus.internalServerError, {'error': 'Unable to save evidence'});
      return;
    }
    _receivedHashes.add(hash);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('evidence_transfer_hashes', _receivedHashes.toList());
    evidenceChanged.value++;
    status.value = 'Received and verified: $fileName';
    await _respond(request, HttpStatus.ok, {'stored': true, 'sha256': hash});
  }

  Future<bool> _saveReceivedEvidence(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final evidenceDirectory = Directory(path.join(directory.path, 'evidence'));
      await evidenceDirectory.create(recursive: true);
      final safeName = path.basename(fileName);
      final savedPath = path.join(evidenceDirectory.path, '${DateTime.now().millisecondsSinceEpoch}_$safeName');
      await File(savedPath).writeAsBytes(bytes, flush: true);
      final savedHash = sha256.convert(await File(savedPath).readAsBytes()).toString();
      if (savedHash != sha256.convert(bytes).toString()) return false;
      final eventId = await HistoryDatabase.instance.insertEvent(eventType: 'EVIDENCE_TRANSFERRED', description: 'Photo transferred from Windows sender: $safeName.');
      return eventId != null && await HistoryDatabase.instance.insertEvidence(filePath: savedPath, evidenceType: 'PHOTO', historyEventId: eventId);
    } catch (_) {
      return false;
    }
  }

  Future<void> _respond(HttpRequest request, int statusCode, Map<String, Object> body) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<String> _localAddress() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
    return 'this phone IP';
  }

  String _newToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

Future<Position?> _tryGetSafetyPosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Permission.location.status;
    if (!permission.isGranted) return null;
    return await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  } catch (_) {
    return null;
  }
}

class SilentAlertResult {
  const SilentAlertResult({required this.sent, this.position});

  final bool sent;
  final Position? position;
}

Future<SilentAlertResult> _sendSilentAlertSms(SafetyProfile profile) async {
  final phone = profile.emergencyPhone.trim();
  if (phone.isEmpty) return const SilentAlertResult(sent: false);
  final permission = await Permission.sms.request();
  if (!permission.isGranted) return const SilentAlertResult(sent: false);
  final position = await _tryGetSafetyPosition();
  var message = 'PROTEQT ALERT: I need help. Please contact me immediately.';
  if (position != null) {
    message += '\n\nMy current location:\nhttps://maps.google.com/?q=${position.latitude},${position.longitude}';
  }
  try {
    final completer = Completer<bool>();
    await Telephony.instance.sendSms(to: phone, message: message, statusListener: (status) {
      if (!completer.isCompleted) completer.complete(status == SendStatus.SENT);
    });
    return SilentAlertResult(sent: await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false), position: position);
  } catch (_) {
    return const SilentAlertResult(sent: false);
  }
}

Future<void> _handleBackgroundShake() async {
  if (_shakeFlowActive) return;
  final context = _navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  final profile = await SafetyProfile.load();
  if (profile == null || !context.mounted) return;
  final preferences = await SharedPreferences.getInstance();
  if (!context.mounted) return;
  final testMode = preferences.getBool('shake_alert_test_mode') ?? true;
  await _runShakeAlertFlow(context, profile, testMode);
}

Future<String> _runShakeAlertFlow(BuildContext context, SafetyProfile profile, bool testMode) async {
  if (_shakeFlowActive) return 'duplicate';
  _shakeFlowActive = true;
  try {
    await HistoryDatabase.instance.insertEvent(eventType: 'SHAKE_ALERT_DETECTED', description: 'Shake-to-Alert motion detected.');
    if (!context.mounted) return 'unavailable';
    var cancelled = false;
    Timer? countdownTimer;
    var secondsRemaining = 5;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
            if (secondsRemaining == 1) {
              timer.cancel();
              if (Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop(true);
            } else {
              setDialogState(() => secondsRemaining--);
            }
          });
          return AlertDialog(
            title: const Text('Possible emergency detected'),
            content: Text('A safety alert will be sent in $secondsRemaining seconds. Cancel if this was accidental.'),
            actions: [
              TextButton(
                onPressed: () {
                  cancelled = true;
                  countdownTimer?.cancel();
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    countdownTimer?.cancel();
    if (cancelled || result == false || !context.mounted) {
      await HistoryDatabase.instance.insertEvent(eventType: 'SHAKE_ALERT_CANCELLED', description: 'Shake-to-Alert was cancelled.');
      return 'cancelled';
    }
    if (testMode) {
      await HistoryDatabase.instance.insertEvent(eventType: 'SHAKE_ALERT_TEST', description: 'Shake-to-Alert test mode prevented a real alert.');
      return 'test';
    }
    final resultAlert = await _sendSilentAlertSms(profile);
    await HistoryDatabase.instance.insertEvent(
      eventType: resultAlert.sent ? 'SHAKE_ALERT_SENT' : 'SHAKE_ALERT_FAILED',
      description: resultAlert.sent ? 'Shake-to-Alert SMS send attempt completed.' : 'Shake-to-Alert could not send an SMS.',
      latitude: resultAlert.position?.latitude,
      longitude: resultAlert.position?.longitude,
      accuracy: resultAlert.position?.accuracy,
    );
    return resultAlert.sent ? 'sent' : 'failed';
  } finally {
    _shakeFlowActive = false;
  }
}

const _checkinNotificationId = 7001;
const _checkinTimeoutNotificationId = 7002;

class SafetyReminderSettings {
  const SafetyReminderSettings({
    required this.enabled,
    required this.intervalSeconds,
    required this.timeoutSeconds,
    required this.automaticSms,
  });

  final bool enabled;
  final int intervalSeconds;
  final int timeoutSeconds;
  final bool automaticSms;

  static const defaultIntervalSeconds = 60;
  static const defaultTimeoutSeconds = 60;

  SafetyReminderSettings copyWith({bool? enabled, int? intervalSeconds, int? timeoutSeconds, bool? automaticSms}) => SafetyReminderSettings(
        enabled: enabled ?? this.enabled,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
        automaticSms: automaticSms ?? this.automaticSms,
      );
}

class SafetyReminderService {
  SafetyReminderService._();

  static final _notifications = FlutterLocalNotificationsPlugin();
  static const _settingsKey = 'safety_reminder_settings';
  static const _automaticSmsConsentKey = 'safety_reminder_sms_consent';
  static const _pendingKey = 'safety_reminder_pending';
  static const _deferredCallKey = 'safety_reminder_deferred_call';
  static bool _notificationsInitialized = false;
  static final Set<String> _processingCheckins = <String>{};
  static SafetyReminderSettings settings = const SafetyReminderSettings(
    enabled: false,
    intervalSeconds: SafetyReminderSettings.defaultIntervalSeconds,
    timeoutSeconds: SafetyReminderSettings.defaultTimeoutSeconds,
    automaticSms: false,
  );
  static Timer? _timeoutTimer;
  static bool _automaticSmsConsent = false;

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    await _ensureNotificationsInitialized();
    final preferences = await SharedPreferences.getInstance();
    await _loadSettings(preferences);
    _automaticSmsConsent = preferences.getBool(_automaticSmsConsentKey) ?? settings.automaticSms;
    if (preferences.getBool(_automaticSmsConsentKey) == null) {
      await preferences.setBool(_automaticSmsConsentKey, _automaticSmsConsent);
    }
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel('safety_checkins', 'Safety Check-ins', description: 'PROTEQT safety check-in notifications', importance: Importance.max));
    await _processDeferredCall();
    if (settings.enabled) {
      await _recoverPendingCheckin();
      await _scheduleNext();
    }
  }

  static Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: safetyReminderNotificationBackgroundCallback,
    );
    _notificationsInitialized = true;
  }

  static Future<void> _loadSettings(SharedPreferences preferences) async {
    final encoded = preferences.getString(_settingsKey);
    if (encoded == null) return;
    final map = jsonDecode(encoded) as Map<String, dynamic>;
    settings = SafetyReminderSettings(
      enabled: map['enabled'] as bool? ?? false,
      intervalSeconds: (map['intervalSeconds'] as num?)?.toInt() ?? SafetyReminderSettings.defaultIntervalSeconds,
      timeoutSeconds: (map['timeoutSeconds'] as num?)?.toInt() ?? SafetyReminderSettings.defaultTimeoutSeconds,
      automaticSms: map['automaticSms'] as bool? ?? false,
    );
  }

  static Future<void> saveSettings(SafetyReminderSettings value) async {
    settings = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_settingsKey, jsonEncode({
      'enabled': value.enabled,
      'intervalSeconds': value.intervalSeconds,
      'timeoutSeconds': value.timeoutSeconds,
      'automaticSms': value.automaticSms,
    }));
    await _notifications.cancel(_checkinNotificationId);
    await _notifications.cancel(_checkinTimeoutNotificationId);
    _timeoutTimer?.cancel();
    if (value.enabled) {
      await preferences.remove(_pendingKey);
      await _scheduleNext();
    } else {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_pendingKey);
    }
  }

  static Future<void> _scheduleNext() async {
    if (!settings.enabled) return;
    final pending = await _loadPending();
    if (pending != null && pending['processed'] != true) return;
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final scheduledAt = DateTime.now().add(Duration(seconds: settings.intervalSeconds));
    final next = {'id': id, 'scheduledAt': scheduledAt.toIso8601String(), 'presentedAt': null, 'processed': false, 'response': null, 'responseAt': null, 'smsAttempted': false, 'smsResult': null, 'smsAt': null, 'callResult': null, 'callAt': null};
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingKey, jsonEncode(next));
    await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_NOTIFICATION_SCHEDULED', description: 'Safety check-in $id scheduled for ${scheduledAt.toLocal()}.');
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(
      Duration(seconds: settings.intervalSeconds + settings.timeoutSeconds),
      () => processAction('timeout', 'checkin:$id'),
    );
    await _notifications.zonedSchedule(
      _checkinNotificationId,
      'PROTEQT — Safety Check-in',
      'Are you safe right now? Please confirm your safety.',
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'safety_checkins',
          'Safety Check-ins',
          channelDescription: 'PROTEQT safety check-in notifications',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.reminder,
          actions: [
            AndroidNotificationAction('safe', "I'M SAFE", showsUserInterface: true, cancelNotification: true),
            AndroidNotificationAction('unsafe', 'NOT SAFE', showsUserInterface: true, cancelNotification: true),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'checkin:$id',
    );
  }

  static Future<Map<String, dynamic>?> _loadPending() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pendingKey);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> _recoverPendingCheckin() async {
    final pending = await _loadPending();
    if (pending == null || pending['processed'] == true) return;
    final scheduledAt = DateTime.tryParse(pending['scheduledAt'] as String? ?? '');
    if (scheduledAt == null || DateTime.now().isBefore(scheduledAt.add(Duration(seconds: settings.timeoutSeconds)))) return;
    await processAction('timeout', 'checkin:${pending['id']}');
  }

  static Future<void> _handleNotificationResponse(NotificationResponse response) async {
    final action = response.actionId ?? '';
    if (action.isEmpty && response.payload?.startsWith('checkin:') == true) {
      final profile = await SafetyProfile.load();
      final context = _navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (profile != null && _navigatorKey.currentState != null && currentRoute != '/safety-reminders') {
        _navigatorKey.currentState!.push(MaterialPageRoute(settings: const RouteSettings(name: '/safety-reminders'), builder: (_) => SafetyRemindersScreen(profile: profile)));
      }
      return;
    }
    await processAction(action.isEmpty ? 'open' : action, response.payload);
  }

  static Future<void> processAction(String action, String? payload, {bool allowUiOperations = true}) async {
    if (action == 'open' || payload == null || !payload.startsWith('checkin:')) return;
    final checkinId = payload.substring('checkin:'.length);
    if (!_processingCheckins.add(checkinId)) return;
    final pending = await _loadPending();
    try {
      if (pending == null || pending['id'] != checkinId || pending['processed'] == true) return;
      await _notifications.cancel(_checkinNotificationId);
      final response = action == 'safe' || action == 'unsafe' ? action : 'timeout';
      pending['processed'] = true;
      pending['response'] = response;
      pending['processedAt'] = DateTime.now().toIso8601String();
      pending['responseAt'] = pending['processedAt'];
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_pendingKey, jsonEncode(pending));
      if (response == 'safe') {
        await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_SAFE', description: 'Safety check-in $checkinId answered: I am safe.');
      } else if (response == 'unsafe') {
        await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_UNSAFE', description: 'Safety check-in $checkinId answered: not safe.');
        try {
          await _attemptEscalation(checkinId, 'PROTEQT SAFETY ALERT\n\nThe user selected NOT SAFE and may need assistance. Please try to contact them immediately.');
        } catch (_) {
          await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_SMS_FAILED', description: 'Emergency SMS attempt for safety check-in $checkinId failed unexpectedly.');
        }
        await _attemptDirectCall(checkinId, allowUiOperations: allowUiOperations);
      } else {
        await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_TIMEOUT', description: 'Safety check-in $checkinId timed out without a response.');
        if (_automaticSmsConsent) {
          try {
            await _attemptEscalation(checkinId, 'PROTEQT SAFETY CHECK-IN\n\nThe user did not respond to a scheduled safety check-in and may need assistance. Please try to contact them immediately.');
          } catch (_) {
            await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_SMS_FAILED', description: 'Emergency SMS attempt for safety check-in $checkinId failed unexpectedly.');
          }
        } else {
          await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_SMS_NOT_CONSENTED', description: 'Automatic timeout SMS was not sent because consent has not been granted.');
          await _notifySmsConsentRequired();
        }
      }
      await _scheduleNext();
    } finally {
      _processingCheckins.remove(checkinId);
    }
  }

  static Future<void> _attemptEscalation(String checkinId, String message) async {
    final pending = await _loadPending();
    if (pending == null || pending['id'] != checkinId || pending['smsAttempted'] == true) return;
    pending['smsAttempted'] = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingKey, jsonEncode(pending));
    final profile = await SafetyProfile.load();
    if (profile == null || profile.emergencyPhone.trim().isEmpty) {
      pending['smsResult'] = 'missing_contact';
      pending['smsAt'] = DateTime.now().toIso8601String();
      await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_CONTACT_MISSING', description: 'No emergency contact was available for safety check-in $checkinId.');
      await preferences.setString(_pendingKey, jsonEncode(pending));
      return;
    }
    final permission = await Permission.sms.request();
    if (!permission.isGranted) {
      pending['smsResult'] = 'permission_denied';
      pending['smsAt'] = DateTime.now().toIso8601String();
      await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_SMS_FAILED', description: 'SMS permission was denied for safety check-in $checkinId.');
      await preferences.setString(_pendingKey, jsonEncode(pending));
      return;
    }
    final position = await _tryGetSafetyPosition();
    final location = position == null ? '' : '\n\nCurrent location: https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    var sent = false;
    try {
      final completer = Completer<bool>();
      await Telephony.instance.sendSms(to: profile.emergencyPhone.trim(), message: '$message$location', statusListener: (status) {
        if (!completer.isCompleted) completer.complete(status == SendStatus.SENT);
      });
      sent = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
    } catch (_) {}
    await HistoryDatabase.instance.insertEvent(
      eventType: sent ? 'CHECKIN_SMS_ATTEMPTED' : 'CHECKIN_SMS_FAILED',
      description: sent ? 'Emergency SMS attempt for safety check-in $checkinId completed.' : 'Emergency SMS attempt for safety check-in $checkinId failed.',
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
    );
    pending['smsResult'] = sent ? 'sent' : 'failed';
    pending['smsAt'] = DateTime.now().toIso8601String();
    await preferences.setString(_pendingKey, jsonEncode(pending));
  }

  static Future<void> _attemptDirectCall(String checkinId, {required bool allowUiOperations}) async {
    final profile = await SafetyProfile.load();
    final number = profile?.sosEmergencyNumber.trim() ?? '';
    if (number.isEmpty) {
      await _updatePendingCallState('missing_number');
      await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_CALL_MISSING', description: 'No SOS Emergency Number was configured for safety check-in $checkinId.');
      if (allowUiOperations) await _notifyMissingSosNumber();
      return;
    }
    if (!allowUiOperations) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_deferredCallKey, jsonEncode({'checkinId': checkinId, 'number': number}));
      await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_CALL_DEFERRED', description: 'SOS call for safety check-in $checkinId was deferred until the main app isolate was available.');
      await _updatePendingCallState('deferred');
      return;
    }
    var initiated = false;
    var result = 'failed';
    try {
      final permission = await Permission.phone.request();
      if (permission.isGranted) {
        initiated = await FlutterPhoneDirectCaller.callNumber(number) ?? false;
        result = initiated ? 'initiated' : 'failed';
      } else {
        result = 'permission_denied';
        await HistoryDatabase.instance.insertEvent(eventType: 'CHECKIN_CALL_FAILED', description: 'Phone permission was denied for safety check-in $checkinId.');
      }
    } catch (_) {
      initiated = false;
    }
    await _updatePendingCallState(result);
    await HistoryDatabase.instance.insertEvent(
      eventType: initiated ? 'CHECKIN_CALL_ATTEMPTED' : 'CHECKIN_CALL_FAILED',
      description: initiated ? 'SOS call was initiated for safety check-in $checkinId.' : 'SOS call could not be initiated for safety check-in $checkinId.',
    );
  }

  static Future<void> _processDeferredCall() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_deferredCallKey);
    if (raw == null) return;
    await preferences.remove(_deferredCallKey);
    final call = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    await _attemptDirectCall(call['checkinId'] as String, allowUiOperations: true);
  }

  static Future<void> _updatePendingCallState(String result) async {
    final pending = await _loadPending();
    if (pending == null) return;
    pending['callResult'] = result;
    pending['callAt'] = DateTime.now().toIso8601String();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingKey, jsonEncode(pending));
  }

  static Future<void> _notifyMissingSosNumber() async {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure an SOS Emergency Number in Profile to place emergency calls.')));
    }
  }

  static Future<void> _notifySmsConsentRequired() async {
    final context = _navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable Automatic emergency SMS in Safety Reminders to allow timeout alerts.')));
    }
  }
}

@pragma('vm:entry-point')
Future<void> safetyReminderNotificationBackgroundCallback(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
  tz.initializeTimeZones();
  await SafetyReminderService._ensureNotificationsInitialized();
  final preferences = await SharedPreferences.getInstance();
  await SafetyReminderService._loadSettings(preferences);
  SafetyReminderService._automaticSmsConsent = preferences.getBool(SafetyReminderService._automaticSmsConsentKey) ?? SafetyReminderService.settings.automaticSms;
  final action = response.actionId ?? '';
  await SafetyReminderService.processAction(action.isEmpty ? 'open' : action, response.payload, allowUiOperations: false);
}

class SafetyRemindersScreen extends StatefulWidget {
  const SafetyRemindersScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<SafetyRemindersScreen> createState() => _SafetyRemindersScreenState();
}

class _SafetyRemindersScreenState extends State<SafetyRemindersScreen> {
  late SafetyReminderSettings _settings;
  late final TextEditingController _intervalController;
  late final TextEditingController _timeoutController;
  String _intervalPreset = '1 minute';
  String _intervalUnit = 'Minutes';
  String _timeoutPreset = '1 minute';
  String _permissionStatus = 'Checking...';
  DateTime? _nextCheckin;

  static const _intervals = <String, int>{'10 seconds': 10, '15 seconds': 15, '30 seconds': 30, '45 seconds': 45, '1 minute': 60, '5 minutes': 300, '15 minutes': 900, '30 minutes': 1800, '1 hour': 3600, '2 hours': 7200};
  static const _timeouts = <String, int>{'30 seconds': 30, '1 minute': 60, '2 minutes': 120, '5 minutes': 300};

  @override
  void initState() {
    super.initState();
    _settings = SafetyReminderService.settings;
    _intervalController = TextEditingController();
    _timeoutController = TextEditingController();
    _intervalPreset = _intervals.entries.firstWhere((entry) => entry.value == _settings.intervalSeconds, orElse: () => const MapEntry('Custom', 0)).key;
    _timeoutPreset = _timeouts.entries.firstWhere((entry) => entry.value == _settings.timeoutSeconds, orElse: () => const MapEntry('Custom', 0)).key;
    _loadPermissions();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    final permission = await Permission.notification.status;
    if (mounted) setState(() => _permissionStatus = permission.isGranted ? 'Allowed' : 'Not allowed');
  }

  int? _customSeconds(TextEditingController controller, String unit) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return null;
    return value * (unit == 'Seconds' ? 1 : unit == 'Minutes' ? 60 : 3600);
  }

  Future<void> _save() async {
    var interval = _intervals[_intervalPreset];
    if (_intervalPreset == 'Custom') interval = _customSeconds(_intervalController, _intervalUnit);
    var timeout = _timeouts[_timeoutPreset];
    if (_timeoutPreset == 'Custom') timeout = _customSeconds(_timeoutController, 'Minutes');
    if (interval == null || timeout == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid positive custom intervals.')));
      return;
    }
    final updated = _settings.copyWith(intervalSeconds: interval, timeoutSeconds: timeout);
    await SafetyReminderService.saveSettings(updated);
    if (!mounted) return;
    setState(() {
      _settings = updated;
      _nextCheckin = updated.enabled ? DateTime.now().add(Duration(seconds: updated.intervalSeconds)) : null;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safety reminder settings saved.')));
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      final permission = await Permission.notification.request();
      if (!permission.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification permission is required for Safety Check-ins.')));
        return;
      }
    }
    final updated = _settings.copyWith(enabled: value);
    await SafetyReminderService.saveSettings(updated);
    if (mounted) setState(() { _settings = updated; _nextCheckin = value ? DateTime.now().add(Duration(seconds: updated.intervalSeconds)) : null; });
  }

  Future<void> _toggleSms(bool value) async {
    if (value) {
      final consent = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Enable automatic SMS?'), content: const Text('If you do not respond, PROTEQT will attempt one SMS to your saved Emergency Contact. Sending is not guaranteed and requires SMS permission.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I Consent'))])) ?? false;
      if (!consent) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(SafetyReminderService._automaticSmsConsentKey, true);
    }
    final updated = _settings.copyWith(automaticSms: value);
    await SafetyReminderService.saveSettings(updated);
    if (mounted) setState(() => _settings = updated);
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.profile.emergencyPhone.trim().isEmpty ? 'Missing — add one in Profile' : '${widget.profile.emergencyName} (${widget.profile.emergencyPhone})';
    return Scaffold(
      appBar: AppBar(title: const Text('Safety Reminders')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _Panel(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Safety Check-ins', style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w800)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable Safety Check-ins'), value: _settings.enabled, onChanged: _toggleEnabled)])),
          const SizedBox(height: 12),
          _Panel(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Check-in frequency', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
            DropdownButton<String>(isExpanded: true, value: _intervalPreset, items: [..._intervals.keys, 'Custom'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _intervalPreset = value!)),
            if (_intervalPreset == 'Custom') Row(children: [Expanded(child: TextField(controller: _intervalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Value'))), const SizedBox(width: 10), DropdownButton<String>(value: _intervalUnit, items: ['Seconds', 'Minutes', 'Hours'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _intervalUnit = value!))]),
            const SizedBox(height: 12),
            const Text('No-response timeout', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
            DropdownButton<String>(isExpanded: true, value: _timeoutPreset, items: [..._timeouts.keys, 'Custom'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _timeoutPreset = value!)),
            if (_timeoutPreset == 'Custom') TextField(controller: _timeoutController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutes')),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Save Settings')),
          ])),
          const SizedBox(height: 12),
          _Panel(padding: const EdgeInsets.all(18), child: Column(children: [
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Automatic emergency SMS'), subtitle: const Text('Requires explicit consent. One attempt is made after a timeout.'), value: _settings.automaticSms, onChanged: _toggleSms),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Next scheduled check-in'), subtitle: Text(_nextCheckin == null ? 'Not scheduled' : _nextCheckin!.toLocal().toString())),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Emergency contact'), subtitle: Text(contact)),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Notification permission'), subtitle: Text(_permissionStatus)),
          ])),
          const SizedBox(height: 12),
          const Text('Android may delay short intervals because of battery optimization, exact-alarm restrictions, notification permission, locked-device policies, or manufacturer restrictions. SMS and location also depend on permissions, SIM, and mobile service. A timeout indicates no response; it does not prove danger or guarantee SMS delivery.', style: TextStyle(color: Color(0xFF596275), height: 1.4)),
        ],
      ),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.initial, required this.onSaved});

  final SafetyProfile? initial;
  final ValueChanged<SafetyProfile> onSaved;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _fullName = TextEditingController(text: widget.initial?.fullName);
  late final _mobile = TextEditingController(text: widget.initial?.mobileNumber);
  late final _dob = TextEditingController(text: widget.initial?.dateOfBirth);
  late final _blood = TextEditingController(text: widget.initial?.bloodGroup);
  late final _emergencyName = TextEditingController(text: widget.initial?.emergencyName);
  late final _emergencyPhone = TextEditingController(text: widget.initial?.emergencyPhone);
  late final _sosEmergencyNumber = TextEditingController(text: widget.initial?.sosEmergencyNumber);
  late final _notes = TextEditingController(text: widget.initial?.notes);
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_fullName, _mobile, _dob, _blood, _emergencyName, _emergencyPhone, _sosEmergencyNumber, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final profile = SafetyProfile(fullName: _fullName.text.trim(), mobileNumber: _mobile.text.trim(), dateOfBirth: _dob.text.trim(), bloodGroup: _blood.text.trim(), emergencyName: _emergencyName.text.trim(), emergencyPhone: _emergencyPhone.text.trim(), sosEmergencyNumber: _sosEmergencyNumber.text.trim(), notes: _notes.text.trim());
    try {
      await profile.save();
      if (mounted) widget.onSaved(profile);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save your safety profile. Please try again.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.initial == null ? 'Safety Profile' : 'Edit Profile')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Keep your details ready for an emergency.', style: TextStyle(color: _navy, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                _field(_fullName, 'Full Name'),
                _field(_mobile, 'Mobile Number', keyboard: TextInputType.phone),
                _field(_dob, 'Date of Birth / Age'),
                _field(_blood, 'Blood Group'),
                _field(_emergencyName, 'Emergency Contact Name'),
                _field(_emergencyPhone, 'Emergency Contact Phone Number', keyboard: TextInputType.phone),
                _field(_sosEmergencyNumber, 'SOS Emergency Number', keyboard: TextInputType.phone, required: false),
                _field(_notes, 'Medical / Safety Notes (Optional)', required: false, maxLines: 3),
                const SizedBox(height: 12),
                FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Safety Profile')),
              ],
            ),
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, {bool required = true, TextInputType? keyboard, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(controller: controller, keyboardType: keyboard, maxLines: maxLines, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), validator: required ? (value) => value == null || value.trim().isEmpty ? 'Required' : null : null),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SafetyProfile _profile;
  bool _isSafe = true;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  void _demo(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editProfile() async {
    final profile = await Navigator.of(context).push<SafetyProfile>(MaterialPageRoute(builder: (_) => RegistrationScreen(initial: _profile, onSaved: (profile) => Navigator.of(context).pop(profile))));
    if (mounted && profile != null) setState(() => _profile = profile);
  }

  Future<void> _call112() async {
    final permission = await Permission.phone.request();
    if (!permission.isGranted) {
      if (mounted) _demo(context, 'Phone permission is required to call 112.');
      return;
    }
    final called = await FlutterPhoneDirectCaller.callNumber('112') ?? false;
    if (!called) {
      if (mounted) _demo(context, 'Unable to place the call.');
      return;
    }
    final position = await _tryGetSafetyPosition();
    await HistoryDatabase.instance.insertEvent(eventType: 'CALL_112_INITIATED', description: 'Emergency call to 112 initiated.', latitude: position?.latitude, longitude: position?.longitude, accuracy: position?.accuracy);
  }

  Future<void> _sendSilentAlert() async {
    if (_profile.emergencyPhone.trim().isEmpty) {
      _demo(context, 'Add an emergency contact in Profile first.');
      return;
    }
    final result = await _sendSilentAlertSms(_profile);
    if (!mounted) return;
    if (result.sent) {
      await HistoryDatabase.instance.insertEvent(eventType: 'SILENT_ALERT_SENT', description: 'Silent alert SMS sent.', latitude: result.position?.latitude, longitude: result.position?.longitude, accuracy: result.position?.accuracy);
    }
    if (mounted) _demo(context, result.sent ? 'Silent alert sent successfully.' : 'Unable to send the silent alert.');
  }

  Future<void> _confirmSos() async {
    var sosNumber = _profile.sosEmergencyNumber.trim();
    if (sosNumber.isEmpty) {
      final configuredNumber = await _showSosNumberDialog();
      if (!mounted) return;
      if (configuredNumber == null) return;
      sosNumber = configuredNumber;
      _profile = _profile.copyWith(sosEmergencyNumber: sosNumber);
    }

    final permission = await Permission.phone.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      _demo(context, 'Phone permission is required for SOS calling.');
      return;
    }

    try {
      final called = await FlutterPhoneDirectCaller.callNumber(sosNumber) ?? false;
      if (!called) {
        if (!mounted) return;
        _demo(context, 'Unable to initiate the SOS call.');
        return;
      }
      final position = await _tryGetSafetyPosition();
      await HistoryDatabase.instance.insertEvent(eventType: 'SOS_CONFIRMED', description: 'SOS call initiated.', latitude: position?.latitude, longitude: position?.longitude, accuracy: position?.accuracy);
    } catch (_) {
      if (mounted) _demo(context, 'Unable to initiate the SOS call.');
    }
  }

  Future<void> _toggleSafetyStatus() async {
    if (!mounted) return;
    final isSafe = !_isSafe;
    setState(() => _isSafe = isSafe);
    final position = await _tryGetSafetyPosition();
    await HistoryDatabase.instance.insertEvent(
      eventType: isSafe ? 'SAFETY_STATUS_SAFE' : 'SAFETY_STATUS_UNSAFE',
      description: isSafe ? 'Safety status changed to safe.' : 'Safety status changed to unsafe.',
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
    );
  }

  Future<void> _openHistory() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()));
  }

  Future<void> _openSafetyReminders() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyRemindersScreen(profile: _profile)));
  }

  Future<void> _openSafetyCenter() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyCenterScreen(profile: _profile)));
  }

  Future<void> _openShakeToAlert() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShakeToAlertScreen(profile: _profile)));
  }

  Future<void> _openConnectedDevices() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConnectedDevicesScreen()));
  }

  Future<void> _openSettings() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(profile: _profile)));
  }

  Future<void> _openAbout() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutProteqtScreen()));
  }

  Future<void> _openLiveLocation() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveLocationScreen(emergencyPhone: _profile.emergencyPhone)));
  }

  Future<void> _openEvidence() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EvidenceScreen()));
  }

  Future<void> _openTrustedContacts() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrustedContactsScreen(profile: _profile)));
  }

  Future<void> _openVoiceTrigger() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceTriggerScreen(profile: _profile)));
  }

  void _handleMenuSelection(String option) {
    switch (option) {
      case 'Settings':
        _openSettings();
        return;
      case 'Safety Center':
        _openSafetyCenter();
        return;
      case 'Shake-to-Alert':
        _openShakeToAlert();
        return;
      case 'Connected Devices':
        _openConnectedDevices();
        return;
      case 'About PROTEQT':
        _openAbout();
        return;
    }
  }

  Future<void> _openFakeCall() async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FakeCallSetupScreen()));
  }

  Future<String?> _showSosNumberDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          String? errorText;
          return StatefulBuilder(
            builder: (context, dialogSetState) => AlertDialog(
              title: const Text('SOS Emergency Number'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Phone number', border: const OutlineInputBorder(), errorText: errorText),
                onChanged: (_) {
                  if (errorText != null) dialogSetState(() => errorText = null);
                },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final number = controller.text.trim();
                    if (!_isValidPhoneNumber(number)) {
                      dialogSetState(() => errorText = 'Enter a valid phone number');
                      return;
                    }
                    final preferences = await SharedPreferences.getInstance();
                    await preferences.setString('sos_emergency_number', number);
                    if (dialogContext.mounted) Navigator.pop(dialogContext, number);
                  },
                  child: const Text('Save and Call'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  bool _isValidPhoneNumber(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^\+?[0-9][0-9\s().-]{6,20}$').hasMatch(value.trim()) && digits.length >= 7 && digits.length <= 15;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _ProteqtDrawer(onSelected: _handleMenuSelection),
      body: Stack(
        children: [
          const _BackgroundShapes(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Builder(
                          builder: (context) =>                           _Header(onBell: _openSafetyReminders, onMenu: () => Scaffold.of(context).openDrawer()),
                        ),
                        const SizedBox(height: 18),
                        SafetyStatusCard(isSafe: _isSafe, onTap: _toggleSafetyStatus),
                        const _DeviceStatusIndicator(connected: true),
                        const SizedBox(height: 16),
                        _SosSection(onCall: _call112, onSilentAlert: _sendSilentAlert, onSos: _confirmSos),
                        const SizedBox(height: 16),
                        _FeatureGrid(onTap: _demo, onLiveLocation: _openLiveLocation, onTrustedContacts: _openTrustedContacts, onVoiceTrigger: _openVoiceTrigger, onFakeCall: _openFakeCall),
                        const SizedBox(height: 18),
                        EvidenceVaultCard(onTap: _openEvidence),
                        const SizedBox(height: 18),
                        const SafetyTipsCard(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: BottomNavigation(onTap: (label) {
                    if (label == 'Profile') {
                      _editProfile();
                    } else if (label == 'Reports') {
                      _openHistory();
                    } else if (label == 'Safety') {
                      _openSafetyCenter();
                    } else if (label == 'Location') {
                      _openLiveLocation();
                    } else {
                      return;
                    }
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<HistoryEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = HistoryDatabase.instance.getEvents();
  }

  Future<void> _clearHistory() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Clear History'),
            content: const Text('Delete all safety history events?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Clear')),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    final cleared = await HistoryDatabase.instance.clear();
    if (!mounted) return;
    if (cleared) {
      setState(() => _events = Future.value(const <HistoryEvent>[]));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to clear history.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(onPressed: _clearHistory, tooltip: 'Clear history', icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: FutureBuilder<List<HistoryEvent>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _pink));
            }
            final events = snapshot.data ?? const <HistoryEvent>[];
            if (events.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('No safety history yet.', style: TextStyle(color: _navy, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HistoryTile(event: events[index]),
            );
          },
        ),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});

  final HistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _eventColor(event.eventType);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x140E1830), blurRadius: 12, offset: Offset(0, 5))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _circleIcon(_eventIcon(event.eventType), color, color.withAlpha(30), size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_eventTitle(event.eventType), style: const TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_formatHistoryTime(event.timestamp), style: const TextStyle(color: Color(0xFF596275), fontSize: 12)),
                const SizedBox(height: 6),
                Text(event.description, style: const TextStyle(color: _navy, fontSize: 14)),
                if (event.latitude != null && event.longitude != null) ...[
                  const SizedBox(height: 8),
                  const Text('Location Captured', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
                  TextButton.icon(onPressed: () => _openSavedLocation(context, event.latitude!, event.longitude!), icon: const Icon(Icons.map_outlined, size: 17), label: const Text('View Location')),
                ],
                if (event.evidence.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Evidence Available', style: TextStyle(color: _deepPink, fontSize: 12, fontWeight: FontWeight.w700)),
                  TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvidenceViewerScreen(records: event.evidence))), icon: const Icon(Icons.photo_library_outlined, size: 17), label: const Text('View Evidence')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _eventIcon(String eventType) => switch (eventType) {
      'SAFETY_STATUS_SAFE' => Icons.verified_user,
      'SAFETY_STATUS_UNSAFE' => Icons.warning_rounded,
      'SOS_CONFIRMED' => Icons.notifications_active,
      'SILENT_ALERT_SENT' => Icons.campaign,
      'CALL_112_INITIATED' => Icons.phone,
      'EVIDENCE_CAPTURED' => Icons.photo_library,
      _ => Icons.history,
    };

Color _eventColor(String eventType) => switch (eventType) {
      'SAFETY_STATUS_SAFE' => _green,
      'SAFETY_STATUS_UNSAFE' => Colors.red,
      'SOS_CONFIRMED' => _deepPink,
      'SILENT_ALERT_SENT' => const Color(0xFFF07824),
      'CALL_112_INITIATED' => _pink,
      'EVIDENCE_CAPTURED' => _pink,
      _ => _navy,
    };

String _eventTitle(String eventType) => switch (eventType) {
      'SAFETY_STATUS_SAFE' => 'You Are Safe',
      'SAFETY_STATUS_UNSAFE' => 'Not Feeling Safe',
      'SOS_CONFIRMED' => 'SOS Confirmed',
      'SILENT_ALERT_SENT' => 'Silent Alert Sent',
      'CALL_112_INITIATED' => '112 Call Initiated',
      'EVIDENCE_CAPTURED' => 'Evidence Captured',
      _ => eventType,
    };

String _formatHistoryTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

Future<void> _openSavedLocation(BuildContext context, double latitude, double longitude) async {
  await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'), mode: LaunchMode.externalApplication);
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        body: FutureBuilder<List<HistoryEvent>>(
          future: HistoryDatabase.instance.getEvents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _pink));
            }
            final events = snapshot.data ?? const <HistoryEvent>[];
            if (events.isEmpty) {
              return const Center(child: Text('No notifications yet.', style: TextStyle(color: _navy, fontWeight: FontWeight.w700)));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HistoryTile(event: events[index]),
            );
          },
        ),
      );
}

class SafetyCenterScreen extends StatefulWidget {
  const SafetyCenterScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<SafetyCenterScreen> createState() => _SafetyCenterScreenState();
}

class _SafetyCenterScreenState extends State<SafetyCenterScreen> {
  static const _nicknameKey = 'about_me_nickname';
  static const _bioKey = 'about_me_bio';
  static const _infoKey = 'about_me_info';
  final _nickname = TextEditingController();
  final _bio = TextEditingController();
  final _info = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAboutMe();
  }

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    _info.dispose();
    super.dispose();
  }

  Future<void> _loadAboutMe() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    _nickname.text = preferences.getString(_nicknameKey) ?? '';
    _bio.text = preferences.getString(_bioKey) ?? '';
    _info.text = preferences.getString(_infoKey) ?? '';
    setState(() {});
  }

  Future<void> _editAboutMe() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('About Me'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nickname, decoration: const InputDecoration(labelText: 'Nickname (optional)')),
              TextField(controller: _bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Short bio (optional)')),
              TextField(controller: _info, maxLines: 3, decoration: const InputDecoration(labelText: 'Useful personal information (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    if (result != true) return;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_nicknameKey, _nickname.text.trim()),
      preferences.setString(_bioKey, _bio.text.trim()),
      preferences.setString(_infoKey, _info.text.trim()),
    ]);
    if (mounted) setState(() {});
  }

  Future<bool> _isReady() async {
    final preferences = await SharedPreferences.getInstance();
    final contacts = preferences.getString('trusted_contacts');
    final hasContact = contacts != null && (jsonDecode(contacts) as List).isNotEmpty;
    final location = await Permission.location.status;
    return widget.profile.emergencyPhone.trim().isNotEmpty && hasContact && location.isGranted;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Safety Center')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<bool>(
              future: _isReady(),
              builder: (context, snapshot) {
                final ready = snapshot.data == true;
                return _Panel(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      _circleIcon(ready ? Icons.verified_user : Icons.warning_rounded, ready ? _green : Colors.orange, ready ? const Color(0xFFC8F7E7) : const Color(0xFFFFE8C7), size: 58),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ready ? 'Emergency Ready' : 'Action Needed', style: const TextStyle(color: _navy, fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(ready ? 'Your emergency contact, trusted contact, and location permission are configured.' : 'Add an emergency contact and trusted contact and allow location access.', style: const TextStyle(color: Color(0xFF596275)))])),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: _deepPink),
                title: const Text('About Me', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
                subtitle: Text(_nickname.text.trim().isEmpty ? widget.profile.fullName : _nickname.text.trim()),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editAboutMe,
              ),
            ),
            _DestinationCard(icon: Icons.groups_outlined, title: 'Emergency Contacts', subtitle: 'View, add, edit, or remove trusted contacts.', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrustedContactsScreen(profile: widget.profile)))),
            _DestinationCard(icon: Icons.location_on_outlined, title: 'Location Sharing', subtitle: 'Get your current location and share it.', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LiveLocationScreen(emergencyPhone: widget.profile.emergencyPhone)))),
            _DestinationCard(icon: Icons.notifications_active_outlined, title: 'Safety Reminders', subtitle: 'Configure check-ins and reminder actions.', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyRemindersScreen(profile: widget.profile)))),
            const SizedBox(height: 8),
            const Text('Safety Tips', style: TextStyle(color: _deepPink, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const SafetyTipsCard(),
          ],
        ),
      );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(icon, color: _deepPink),
          title: Text(title, style: const TextStyle(color: _navy, fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

class ShakeToAlertScreen extends StatefulWidget {
  const ShakeToAlertScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<ShakeToAlertScreen> createState() => _ShakeToAlertScreenState();
}

class _ShakeToAlertScreenState extends State<ShakeToAlertScreen> {
  static const _enabledKey = 'shake_alert_enabled';
  static const _sensitivityKey = 'shake_alert_sensitivity';
  static const _testModeKey = 'shake_alert_test_mode';
  bool _enabled = false;
  bool _testMode = true;
  String _sensitivity = 'Medium';
  String _status = 'Shake-to-Alert is off.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = preferences.getBool(_enabledKey) ?? false;
      _sensitivity = preferences.getString(_sensitivityKey) ?? 'Medium';
      _testMode = preferences.getBool(_testModeKey) ?? true;
    });
    if (_enabled) await _startService();
  }

  Future<void> _setEnabled(bool value) async {
    if (value) {
      final permission = await Permission.activityRecognition.request();
      if (!permission.isGranted) {
        if (mounted) setState(() => _status = 'Motion activity permission is required.');
        return;
      }
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      _status = value ? 'Monitoring continues in the background.' : 'Shake-to-Alert is off.';
    });
    if (value) {
      await _startService();
    } else {
      await _stopService();
    }
  }

  Future<void> _startService() async {
    try {
      await _shakeChannel.invokeMethod<void>('start', {'sensitivity': _sensitivity, 'testMode': _testMode});
      if (mounted) setState(() => _status = 'Monitoring continues in the background.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Unable to start motion monitoring: $error');
    }
  }

  Future<void> _stopService() async {
    try {
      await _shakeChannel.invokeMethod<void>('stop');
    } catch (error) {
      if (mounted) setState(() => _status = 'Unable to stop motion monitoring: $error');
    }
  }

  Future<void> _setTestMode(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_testModeKey, value);
    if (mounted) setState(() => _testMode = value);
    if (_enabled) await _startService();
  }

  Future<void> _setSensitivity(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sensitivityKey, value);
    if (mounted) setState(() => _sensitivity = value);
    if (_enabled) await _startService();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Shake-to-Alert')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SwitchListTile(title: const Text('Enable Shake-to-Alert'), subtitle: Text(_status), value: _enabled, onChanged: _setEnabled),
            DropdownButtonFormField<String>(initialValue: _sensitivity, decoration: const InputDecoration(labelText: 'Sensitivity', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'Low', child: Text('Low')), DropdownMenuItem(value: 'Medium', child: Text('Medium')), DropdownMenuItem(value: 'High', child: Text('High'))], onChanged: (value) { if (value != null) _setSensitivity(value); }),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('Test Mode'), subtitle: const Text('When enabled, motion detection never sends an SMS or places a call.'), value: _testMode, onChanged: _setTestMode),
            const SizedBox(height: 12),
            const Text('Android keeps a persistent service notification while monitoring. Detection is intended to work in the background and while locked, but must be verified on the target device.', style: TextStyle(color: Color(0xFF596275))),
          ],
        ),
      );
}

class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  List<ScanResult> _devices = [];
  bool _scanning = false;
  String? _error;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() { _scanning = true; _error = null; _devices = []; });
    final scanPermission = await Permission.bluetoothScan.request();
    final connectPermission = await Permission.bluetoothConnect.request();
    if (!scanPermission.isGranted || !connectPermission.isGranted) {
      if (mounted) setState(() { _scanning = false; _error = 'Bluetooth permission was denied.'; });
      return;
    }
    try {
      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() => _devices = results);
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (error) {
      if (mounted) setState(() => _error = 'Bluetooth discovery is unavailable: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to connect: $error')));
    }
  }

  Future<void> _disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to disconnect: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Connected Devices'), actions: [IconButton(onPressed: _scanning ? null : _scan, icon: const Icon(Icons.refresh))]),
        body: StreamBuilder<BluetoothAdapterState>(
          stream: FlutterBluePlus.adapterState,
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state != BluetoothAdapterState.on) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(state == null ? 'Checking Bluetooth availability...' : 'Bluetooth is ${state.name}. Turn it on to discover devices.', textAlign: TextAlign.center)));
            }
            if (_error != null) return Center(child: Text(_error!, textAlign: TextAlign.center));
            if (_devices.isEmpty && !_scanning) return const Center(child: Text('No nearby Bluetooth devices found.'));
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_scanning) const LinearProgressIndicator(color: _pink),
                for (final result in _devices)
                  StreamBuilder<BluetoothConnectionState>(
                    stream: result.device.connectionState,
                    builder: (context, connection) {
                      final connected = connection.data == BluetoothConnectionState.connected;
                      final name = result.device.platformName.trim().isEmpty ? result.device.remoteId.str : result.device.platformName;
                      return Card(child: ListTile(leading: const Icon(Icons.devices_other, color: _deepPink), title: Text(name), subtitle: Text(connected ? 'Connected' : 'Available'), trailing: IconButton(onPressed: () => connected ? _disconnect(result.device) : _connect(result.device), icon: Icon(connected ? Icons.link_off : Icons.link))));
                    },
                  ),
                const Padding(padding: EdgeInsets.only(top: 12), child: Text('Bluetooth discovery and pairing do not guarantee file transfer. No file is added to the Evidence Vault unless a supported transfer completes successfully.', style: TextStyle(color: Color(0xFF596275)))),
              ],
            );
          },
        ),
      );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkTheme = false;
  bool _confirmActions = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkTheme = preferences.getBool('dark_theme') ?? false;
      _confirmActions = preferences.getBool('confirm_actions') ?? true;
    });
  }

  Future<void> _setTheme(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('dark_theme', value);
    _themeModeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    if (mounted) setState(() => _darkTheme = value);
  }

  Future<void> _setConfirmActions(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('confirm_actions', value);
    if (mounted) setState(() => _confirmActions = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            ListTile(title: const Text('Safety Reminders'), subtitle: const Text('Configure check-ins and automatic SMS consent.'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyRemindersScreen(profile: widget.profile)))),
            ListTile(title: const Text('Privacy & Security'), subtitle: const Text('Permissions are requested only when a feature needs them. No unsupported app lock is provided.'), onTap: () => showLicensePage(context: context, applicationName: 'PROTEQT Privacy & Security')),
            SwitchListTile(title: const Text('App Theme'), subtitle: Text(_darkTheme ? 'Dark' : 'Light'), value: _darkTheme, onChanged: _setTheme),
            SwitchListTile(title: const Text('Confirm safety actions'), value: _confirmActions, onChanged: _setConfirmActions),
            ListTile(title: const Text('Edit Safety Profile'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegistrationScreen(initial: widget.profile, onSaved: (profile) => Navigator.of(context).pop(profile))))),
            ListTile(title: const Text('About PROTEQT'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutProteqtScreen()))),
          ],
        ),
      );
}

class AboutProteqtScreen extends StatelessWidget {
  const AboutProteqtScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('About PROTEQT')),
        body: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final info = snapshot.data;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.shield, color: _pink, size: 78),
                const SizedBox(height: 12),
                const Center(child: Text('PROTEQT', style: TextStyle(color: _pink, fontSize: 32, fontWeight: FontWeight.w900))),
                const Center(child: Text('Stay Alert. Stay Protected.', style: TextStyle(color: Color(0xFF596275), fontSize: 16))),
                const SizedBox(height: 18),
                Text(info == null ? 'Loading version information...' : 'Version ${info.version} (${info.buildNumber})', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                const Text('PROTEQT helps you prepare safety contacts, share your location, record safety history, and use configured emergency actions.', style: TextStyle(color: _navy, fontSize: 16)),
                const SizedBox(height: 18),
                const Text('Privacy information', style: TextStyle(color: _deepPink, fontSize: 18, fontWeight: FontWeight.w800)),
                const Text('Your profile, contacts, settings, history, and evidence are stored on this device. Location, phone, SMS, microphone, camera, notification, and Bluetooth permissions are used only by the corresponding feature and may be denied.'), 
                const SizedBox(height: 18),
                const Text('Terms and Conditions', style: TextStyle(color: _deepPink, fontSize: 18, fontWeight: FontWeight.w800)),
                const Text('PROTEQT is a safety support tool and does not replace emergency services. Confirm your numbers, permissions, and device capabilities before relying on any feature.'),
                const SizedBox(height: 18),
                OutlinedButton.icon(onPressed: () => showLicensePage(context: context, applicationName: 'PROTEQT'), icon: const Icon(Icons.code), label: const Text('Flutter Open-Source Licenses')),
              ],
            );
          },
        ),
      );
}

class EvidenceVaultCard extends StatelessWidget {
  const EvidenceVaultCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: _Panel(
          height: 170,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _circleIcon(Icons.photo_library_outlined, _pink, const Color(0xFFFFE3ED), size: 58),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Evidence Vault', style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w800)),
                    SizedBox(height: 8),
                    Text('Automatically save and manage safety evidence', style: TextStyle(color: Color(0xFF596275), fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _pink, size: 30),
            ],
          ),
        ),
      );
}

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  late Future<List<EvidenceRecord>> _evidence;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _reload();
    EvidenceTransferService.instance.evidenceChanged.addListener(_onEvidenceChanged);
  }

  void _reload() {
    _evidence = HistoryDatabase.instance.getAllEvidence();
  }

  void _onEvidenceChanged() {
    if (mounted) setState(_reload);
  }

  @override
  void dispose() {
    EvidenceTransferService.instance.evidenceChanged.removeListener(_onEvidenceChanged);
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _saveEvidence(String filePath, String type) async {
    if (!mounted) return;
    String savedPath = filePath;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final evidenceDirectory = Directory(path.join(directory.path, 'evidence'));
      await evidenceDirectory.create(recursive: true);
      savedPath = path.join(evidenceDirectory.path, '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}');
      await File(filePath).copy(savedPath);
    } catch (_) {}
    if (!mounted) return;
    final position = await _tryGetSafetyPosition();
    if (!mounted) return;
    final eventId = await HistoryDatabase.instance.insertEvent(
      eventType: 'EVIDENCE_CAPTURED',
      description: '${_evidenceTitle(type)} evidence captured.',
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
    );
    if (!mounted) return;
    final inserted = eventId != null && await HistoryDatabase.instance.insertEvidence(filePath: savedPath, evidenceType: type, historyEventId: eventId, latitude: position?.latitude, longitude: position?.longitude);
    if (!mounted) return;
    if (!inserted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to save evidence.')));
      return;
    }
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_evidenceTitle(type)} saved.')));
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (!mounted || file == null) return;
    await _saveEvidence(file.path, 'PHOTO');
  }

  Future<void> _recordVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 5));
    if (!mounted || file == null) return;
    await _saveEvidence(file.path, 'VIDEO');
  }

  Future<void> _toggleAudio() async {
    if (_recording) {
      final filePath = await _recorder.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (filePath != null) await _saveEvidence(filePath, 'AUDIO');
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required to record audio.')));
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, 'evidence_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(const RecordConfig(), path: filePath);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _chooseFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (!mounted || result == null || result.files.single.path == null) return;
    final extension = result.files.single.extension?.toLowerCase() ?? '';
    final type = ['jpg', 'jpeg', 'png', 'gif'].contains(extension)
        ? 'PHOTO'
        : ['mp4', 'mov', 'm4v'].contains(extension)
            ? 'VIDEO'
            : ['mp3', 'wav', 'm4a', 'aac', 'ogg'].contains(extension)
                ? 'AUDIO'
                : 'FILE';
    await _saveEvidence(result.files.single.path!, type);
  }

  Future<void> _viewAll() async {
    final records = await HistoryDatabase.instance.getAllEvidence();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvidenceViewerScreen(records: records)));
  }

  Future<void> _deleteEvidence(EvidenceRecord record) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Evidence?'),
            content: const Text('Are you sure you want to permanently delete this evidence?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('DELETE')),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) return;
    final deleted = await HistoryDatabase.instance.deleteEvidence(record.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to delete evidence.')));
      return;
    }
    try {
      final file = File(record.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Evidence Vault')),
        body: FutureBuilder<List<EvidenceRecord>>(
          future: _evidence,
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <EvidenceRecord>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: EvidenceTransferService.instance.status,
                  builder: (context, status, _) => _Panel(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Windows Photo Transfer', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
                          subtitle: const Text('Receive verified photos from a paired Windows sender on this Wi-Fi network.'),
                          value: EvidenceTransferService.instance.enabled,
                          onChanged: (value) => value ? EvidenceTransferService.instance.start() : EvidenceTransferService.instance.stop(),
                        ),
                        Text(status, style: const TextStyle(color: Color(0xFF596275), fontSize: 12)),
                        if (EvidenceTransferService.instance.enabled) ...[
                          const SizedBox(height: 8),
                          SelectableText('Pairing token: ${EvidenceTransferService.instance.pairingToken}', style: const TextStyle(color: _navy, fontSize: 12)),
                          const SizedBox(height: 4),
                          const Text('Use this token only with your paired Windows sender. The receiver accepts no unauthenticated uploads.', style: TextStyle(color: Color(0xFF596275), fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Take Photo')),
                    OutlinedButton.icon(onPressed: _recordVideo, icon: const Icon(Icons.videocam_outlined), label: const Text('Record Video')),
                    OutlinedButton.icon(onPressed: _toggleAudio, icon: Icon(_recording ? Icons.stop : Icons.mic_none), label: Text(_recording ? 'Stop Audio' : 'Record Audio')),
                    OutlinedButton.icon(onPressed: _chooseFile, icon: const Icon(Icons.attach_file), label: const Text('Choose File')),
                    FilledButton.icon(onPressed: _viewAll, icon: const Icon(Icons.photo_library_outlined), label: const Text('View All Evidence')),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator(color: _pink))
                else if (records.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No evidence saved yet.', style: TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.w700))))
                else
                  ...records.map((record) => _EvidenceListTile(record: record, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvidencePreviewScreen(record: record))), onDelete: () => _deleteEvidence(record))),
              ],
            );
          },
        ),
      );
}

class _EvidenceListTile extends StatelessWidget {
  const _EvidenceListTile({required this.record, required this.onTap, this.onDelete});

  final EvidenceRecord record;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        leading: record.evidenceType == 'PHOTO'
            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(record.filePath), width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: _pink, size: 30)))
            : Icon(_evidenceIcon(record.evidenceType), color: _pink, size: 30),
        title: Text(path.basename(record.filePath), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
        subtitle: Text('${_formatHistoryTime(record.timestamp)}\nEvent: ${record.relatedEventType ?? 'Unknown'}${record.latitude == null ? '' : '\nLocation: ${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}'}'),
        trailing: onDelete == null
          ? const Icon(Icons.chevron_right)
          : Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: onDelete, tooltip: 'Delete evidence', icon: const Icon(Icons.delete_outline, color: Colors.red)), const Icon(Icons.chevron_right)]),
      );
}

class EvidenceViewerScreen extends StatelessWidget {
  const EvidenceViewerScreen({super.key, required this.records});

  final List<EvidenceRecord> records;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Evidence')),
        body: records.isEmpty
            ? const Center(child: Text('No evidence saved yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: records.length,
                itemBuilder: (context, index) => _EvidenceListTile(record: records[index], onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvidencePreviewScreen(record: records[index])))),
              ),
      );
}

class EvidencePreviewScreen extends StatefulWidget {
  const EvidencePreviewScreen({super.key, required this.record});

  final EvidenceRecord record;

  @override
  State<EvidencePreviewScreen> createState() => _EvidencePreviewScreenState();
}

class _EvidencePreviewScreenState extends State<EvidencePreviewScreen> {
  VideoPlayerController? _video;
  final _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    if (widget.record.evidenceType == 'VIDEO') {
      _video = VideoPlayerController.file(File(widget.record.filePath))..initialize().then((_) { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _openFile() async {
    final uri = Uri.file(widget.record.filePath);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    Widget body;
    if (record.evidenceType == 'PHOTO') {
      body = Image.file(File(record.filePath), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Center(child: Text('Unable to open photo.')));
    } else if (record.evidenceType == 'VIDEO' && _video?.value.isInitialized == true) {
      body = Column(mainAxisAlignment: MainAxisAlignment.center, children: [AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!)), IconButton(onPressed: () => setState(() => _video!.value.isPlaying ? _video!.pause() : _video!.play()), icon: Icon(_video!.value.isPlaying ? Icons.pause : Icons.play_arrow))]);
    } else if (record.evidenceType == 'AUDIO') {
      body = Center(child: FilledButton.icon(onPressed: () => _audio.play(DeviceFileSource(record.filePath)), icon: const Icon(Icons.play_arrow), label: const Text('Play Audio')));
    } else {
      body = Center(child: FilledButton.icon(onPressed: _openFile, icon: const Icon(Icons.open_in_new), label: const Text('Open File')));
    }
    return Scaffold(appBar: AppBar(title: Text(_evidenceTitle(record.evidenceType))), body: body);
  }
}

IconData _evidenceIcon(String type) => switch (type) {
      'PHOTO' => Icons.photo,
      'VIDEO' => Icons.videocam,
      'AUDIO' => Icons.mic,
      _ => Icons.insert_drive_file,
    };

String _evidenceTitle(String type) => switch (type) {
      'PHOTO' => 'Photo',
      'VIDEO' => 'Video',
      'AUDIO' => 'Audio',
      _ => 'File',
    };

class TrustedContact {
  const TrustedContact({required this.name, required this.phone, required this.primary});

  final String name;
  final String phone;
  final bool primary;

  Map<String, Object?> toMap() => {'name': name, 'phone': phone, 'primary': primary};

  factory TrustedContact.fromMap(Map<String, dynamic> map) => TrustedContact(name: map['name'] as String, phone: map['phone'] as String, primary: map['primary'] as bool? ?? false);
}

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  static const _storageKey = 'trusted_contacts';
  List<TrustedContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (!mounted) return;
    setState(() => _contacts = raw == null ? [] : (jsonDecode(raw) as List).map((item) => TrustedContact.fromMap(Map<String, dynamic>.from(item as Map))).toList());
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(_contacts.map((contact) => contact.toMap()).toList()));
  }

  bool _validPhone(String value) => RegExp(r'^\+?[0-9][0-9\s().-]{6,20}$').hasMatch(value.trim()) && value.replaceAll(RegExp(r'\D'), '').length >= 7;

  Future<void> _editContact({TrustedContact? existing, int? index}) async {
    final result = await showDialog<TrustedContact>(
      context: context,
      builder: (_) => _TrustedContactDialog(existing: existing, initiallyPrimary: existing?.primary ?? _contacts.isEmpty, validPhone: _validPhone),
    );
    if (!mounted || result == null) return;
    final duplicate = _contacts.any((contact) => contact.phone == result.phone && contact != existing);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That phone number is already saved.')));
      return;
    }
    final updated = [..._contacts];
    if (result.primary) {
      for (var i = 0; i < updated.length; i++) {
        updated[i] = TrustedContact(name: updated[i].name, phone: updated[i].phone, primary: false);
      }
    }
    if (index == null) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    setState(() => _contacts = updated);
    await _save();
  }

  Future<void> _delete(int index) async {
    setState(() => _contacts = [..._contacts]..removeAt(index));
    await _save();
  }

  Future<void> _call(String phone) async {
    final permission = await Permission.phone.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone permission is required.')));
      return;
    }
    await FlutterPhoneDirectCaller.callNumber(phone);
  }

  Future<void> _sendAlert() async {
    if (widget.profile.emergencyPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure an Emergency Contact in Profile first.')));
      return;
    }
    final result = await _sendSilentAlertSms(widget.profile);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.sent ? 'Silent alert sent.' : 'Unable to send the silent alert.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Trusted Contacts'), actions: [IconButton(onPressed: () => _editContact(), icon: const Icon(Icons.person_add_alt_1))]),
        body: _contacts.isEmpty
            ? const Center(child: Text('No trusted contacts saved yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _contacts.length,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(contact.primary ? Icons.star : Icons.person, color: contact.primary ? _pink : _navy),
                      title: Text(contact.name),
                      subtitle: Text('${contact.phone}${contact.primary ? '\nPRIMARY TRUSTED CONTACT' : ''}'),
                      isThreeLine: contact.primary,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') _editContact(existing: contact, index: index);
                          if (action == 'delete') _delete(index);
                          if (action == 'call') _call(contact.phone);
                          if (action == 'alert') _sendAlert();
                        },
                        itemBuilder: (_) => const [PopupMenuItem(value: 'call', child: Text('Call')), PopupMenuItem(value: 'alert', child: Text('Send Silent Alert')), PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                      ),
                    ),
                  );
                },
              ),
      );
}

class _TrustedContactDialog extends StatefulWidget {
  const _TrustedContactDialog({this.existing, required this.initiallyPrimary, required this.validPhone});

  final TrustedContact? existing;
  final bool initiallyPrimary;
  final bool Function(String) validPhone;

  @override
  State<_TrustedContactDialog> createState() => _TrustedContactDialogState();
}

class _TrustedContactDialogState extends State<_TrustedContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late bool _primary = widget.initiallyPrimary;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || !mounted) return;
    Navigator.of(context).pop(TrustedContact(name: _name.text.trim(), phone: _phone.text.trim(), primary: _primary));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'Add Trusted Contact' : 'Edit Trusted Contact'),
        content: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Contact name'), validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'), validator: (value) => value == null || !widget.validPhone(value) ? 'Enter a valid phone number' : null),
            SwitchListTile(title: const Text('Primary Trusted Contact'), value: _primary, onChanged: (value) { if (mounted) setState(() => _primary = value); }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () { if (mounted) Navigator.of(context).pop(); }, child: const Text('Cancel')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}

class VoiceTriggerScreen extends StatefulWidget {
  const VoiceTriggerScreen({super.key, required this.profile});

  final SafetyProfile profile;

  @override
  State<VoiceTriggerScreen> createState() => _VoiceTriggerScreenState();
}

class _VoiceTriggerScreenState extends State<VoiceTriggerScreen> {
  static const _phraseKey = 'voice_trigger_phrase';
  static const _enabledKey = 'voice_trigger_enabled';
  final _speech = speech.SpeechToText();
  final _phraseController = TextEditingController();
  bool _enabled = false;
  bool _listening = false;
  bool _available = false;
  String _status = 'Voice Trigger OFF';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _speech.stop();
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    _phraseController.text = preferences.getString(_phraseKey) ?? 'Help me';
    setState(() => _enabled = preferences.getBool(_enabledKey) ?? false);
  }

  Future<void> _setEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
    if (!mounted) return;
    setState(() {
      _enabled = value;
      if (!value) _status = 'Voice Trigger OFF';
    });
    if (!value && _listening) await _stopListening();
  }

  Future<void> _savePhrase() async {
    final phrase = _phraseController.text.trim();
    if (phrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an emergency phrase first.')));
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_phraseKey, phrase);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency phrase saved.')));
  }

  String _normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _startListening() async {
    if (!_enabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable Voice Trigger first.')));
      return;
    }
    final available = await _speech.initialize(onStatus: (status) {
      if (!mounted) return;
      if (status == 'notListening') setState(() => _listening = false);
    }, onError: (error) {
      if (mounted) setState(() => _status = 'Listening error: ${error.errorMsg}');
    });
    if (!mounted) return;
    if (!available) {
      setState(() {
        _available = false;
        _status = 'Speech recognition unavailable';
      });
      return;
    }
    setState(() {
      _available = true;
      _listening = true;
      _status = 'Voice Trigger ACTIVE';
    });
    await _speech.listen(onResult: (result) {
      if (!mounted) return;
      final phrase = _normalize(_phraseController.text);
      final words = _normalize(result.recognizedWords);
      if (phrase.isNotEmpty && words.contains(phrase)) _triggerAlert();
    });
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _status = _enabled ? 'Voice Trigger ON, not listening' : 'Voice Trigger OFF';
    });
  }

  Future<void> _triggerAlert() async {
    await _stopListening();
    final result = await _sendSilentAlertSms(widget.profile);
    if (!mounted) return;
    if (result.sent) {
      await HistoryDatabase.instance.insertEvent(eventType: 'SILENT_ALERT_SENT', description: 'Voice Trigger activated Silent Alert.', latitude: result.position?.latitude, longitude: result.position?.longitude, accuracy: result.position?.accuracy);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.sent ? 'Voice Trigger sent a silent alert.' : 'Voice Trigger could not send the alert.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Voice Trigger')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_listening ? 'Voice Trigger ACTIVE' : _enabled ? 'Voice Trigger ON' : 'Voice Trigger OFF', style: TextStyle(color: _listening ? _green : Colors.red, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            SwitchListTile(title: const Text('Enable Voice Trigger'), value: _enabled, onChanged: _setEnabled),
            TextField(controller: _phraseController, decoration: const InputDecoration(labelText: 'Custom emergency phrase', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            FilledButton(onPressed: _savePhrase, child: const Text('Save Phrase')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _listening ? _stopListening : _startListening, icon: Icon(_listening ? Icons.stop : Icons.mic), label: Text(_listening ? 'Stop Listening' : 'Start Listening')),
            const SizedBox(height: 12),
            Text(_status, style: const TextStyle(color: Color(0xFF596275))),
            if (!_available && _listening) const Text('Speech recognition is unavailable on this device.', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 18),
            const Text('Listening is active only while this screen is open and you start it.', style: TextStyle(color: Color(0xFF596275))),
          ],
        ),
      );
}

class FakeCallSetupScreen extends StatefulWidget {
  const FakeCallSetupScreen({super.key});

  @override
  State<FakeCallSetupScreen> createState() => _FakeCallSetupScreenState();
}

class _FakeCallSetupScreenState extends State<FakeCallSetupScreen> {
  final _name = TextEditingController(text: 'Mom');
  final _number = TextEditingController(text: 'Incoming call');
  int _delay = 5;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _start() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a caller name.')));
      return;
    }
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fake call starting in $_delay seconds.')));
    _timer = Timer(Duration(seconds: _delay), () {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FakeIncomingCallScreen(callerName: _name.text.trim(), callerNumber: _number.text.trim())));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fake Call')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Caller name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _number, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Caller number', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(initialValue: _delay, decoration: const InputDecoration(labelText: 'Delay', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 5, child: Text('5 seconds')), DropdownMenuItem(value: 10, child: Text('10 seconds')), DropdownMenuItem(value: 30, child: Text('30 seconds'))], onChanged: (value) { if (value != null) setState(() => _delay = value); }),
            const SizedBox(height: 20),
            FilledButton(onPressed: _start, child: const Text('START FAKE CALL')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _timer == null ? null : () { _timer?.cancel(); setState(() => _timer = null); }, child: const Text('Cancel Countdown')),
          ],
        ),
      );
}

class FakeIncomingCallScreen extends StatefulWidget {
  const FakeIncomingCallScreen({super.key, required this.callerName, required this.callerNumber});

  final String callerName;
  final String callerNumber;

  @override
  State<FakeIncomingCallScreen> createState() => _FakeIncomingCallScreenState();
}

class _FakeIncomingCallScreenState extends State<FakeIncomingCallScreen> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF172033),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle, color: Colors.white, size: 100),
              const SizedBox(height: 18),
              const Text('Incoming call', style: TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 10),
              Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
              Text(widget.callerNumber, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 90),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                FloatingActionButton(backgroundColor: Colors.red, onPressed: () => Navigator.pop(context), child: const Icon(Icons.call_end)),
                FloatingActionButton(backgroundColor: _green, onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FakeActiveCallScreen(callerName: widget.callerName))), child: const Icon(Icons.call)),
              ]),
            ],
          ),
        ),
      );
}

class FakeActiveCallScreen extends StatefulWidget {
  const FakeActiveCallScreen({super.key, required this.callerName});

  final String callerName;

  @override
  State<FakeActiveCallScreen> createState() => _FakeActiveCallScreenState();
}

class _FakeActiveCallScreenState extends State<FakeActiveCallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speaker = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _seconds++); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF172033),
        body: SafeArea(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.account_circle, color: Colors.white, size: 100),
            const SizedBox(height: 18),
            const Text('Calling...', style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 8),
            Text(widget.callerName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
            Text('${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 80),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(onPressed: () => setState(() => _muted = !_muted), icon: Icon(_muted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 30)),
              IconButton(onPressed: () => setState(() => _speaker = !_speaker), icon: Icon(_speaker ? Icons.volume_up : Icons.volume_down, color: Colors.white, size: 30)),
              FloatingActionButton(backgroundColor: Colors.red, onPressed: () => Navigator.pop(context), child: const Icon(Icons.call_end)),
            ]),
          ]),
        ),
      );
}

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key, required this.emergencyPhone});

  final String emergencyPhone;

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  Position? _position;
  DateTime? _lastUpdated;
  String? _error;
  bool _loading = true;
  bool _showSettingsButton = false;

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _showSettingsButton = false;
    });

    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!servicesEnabled) {
      setState(() {
        _loading = false;
        _error = 'Location services are disabled. Enable GPS to get your current location.';
        _showSettingsButton = true;
      });
      return;
    }

    final permission = await Permission.location.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      setState(() {
        _loading = false;
        _error = permission.isPermanentlyDenied
            ? 'Location permission is permanently denied. Enable it in app settings to continue.'
            : 'Location permission is required to show your current location.';
        _showSettingsButton = permission.isPermanentlyDenied;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      if (!mounted) return;
      setState(() {
        _position = position;
        _lastUpdated = DateTime.now();
        _loading = false;
        _error = null;
      });
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Location services were disabled before GPS could be read.';
        _showSettingsButton = true;
      });
    } on PermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Location permission was denied. Enable it in app settings to continue.';
        _showSettingsButton = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'GPS is unavailable right now. Please try refreshing your location.';
      });
    }
  }

  Future<void> _openSettings() async {
    if (!mounted) return;
    final permission = await Permission.location.status;
    if (!mounted) return;
    if (permission.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await Geolocator.openLocationSettings();
    }
  }

  Future<void> _shareLocation() async {
    final position = _position;
    if (position == null || !mounted) return;
    final link = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    await SharePlus.instance.share(ShareParams(text: 'My current location: $link'));
  }

  Future<void> _openMaps() async {
    final position = _position;
    if (position == null || !mounted) return;
    final link = Uri.parse('https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}');
    await launchUrl(link, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendLocationSms() async {
    await _refreshLocation();
    if (!mounted) return;
    final position = _position;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to get your current location.')));
      return;
    }
    final phone = widget.emergencyPhone.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configure an Emergency Contact in Profile first.')));
      return;
    }
    final permission = await Permission.sms.request();
    if (!mounted) return;
    if (!permission.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS permission is required to send your location.')));
      return;
    }
    final link = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
    final message = 'PROTEQT Live Location\n\nI need help.\n\nMy current location:\n$link\n\nTime: ${DateTime.now()}';
    try {
      final completer = Completer<bool>();
      await Telephony.instance.sendSms(to: phone, message: message, statusListener: (status) {
        if (!completer.isCompleted) completer.complete(status == SendStatus.SENT);
      });
      final sent = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (!mounted) return;
      if (sent) {
        await HistoryDatabase.instance.insertEvent(eventType: 'SILENT_ALERT_SENT', description: 'Live location SMS sent to the Emergency Contact.', latitude: position.latitude, longitude: position.longitude, accuracy: position.accuracy);
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sent ? 'Live location sent successfully.' : 'Unable to send live location.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to send live location.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    return Scaffold(
      appBar: AppBar(title: const Text('Live Location')),
      body: _loading && position == null
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : position == null
              ? _LocationError(message: _error ?? 'Unable to get your current location.', showSettings: _showSettingsButton, onSettings: _openSettings, onRefresh: _refreshLocation)
              : Column(
                  children: [
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(position.latitude, position.longitude),
                          initialZoom: 16,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.proteqt',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(position.latitude, position.longitude),
                                width: 48,
                                height: 48,
                                child: const Icon(Icons.location_pin, color: _pink, size: 46),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Latitude: ${position.latitude.toStringAsFixed(6)}', style: const TextStyle(color: _navy, fontSize: 14)),
                          Text('Longitude: ${position.longitude.toStringAsFixed(6)}', style: const TextStyle(color: _navy, fontSize: 14)),
                          Text('Accuracy: ${position.accuracy.toStringAsFixed(1)} m', style: const TextStyle(color: Color(0xFF596275), fontSize: 13)),
                          Text('Last updated: ${_lastUpdated == null ? 'Unknown' : _formatHistoryTime(_lastUpdated!)}', style: const TextStyle(color: Color(0xFF596275), fontSize: 13)),
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(onPressed: _loading ? null : _refreshLocation, icon: const Icon(Icons.refresh), label: const Text('Refresh Location'))),
                          const SizedBox(width: 10),
                          Expanded(child: FilledButton.icon(onPressed: _shareLocation, icon: const Icon(Icons.share), label: const Text('Share Location'))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(onPressed: _openMaps, icon: const Icon(Icons.map_outlined), label: const Text('Open in Maps'))),
                          const SizedBox(width: 10),
                          Expanded(child: FilledButton.icon(onPressed: _sendLocationSms, icon: const Icon(Icons.sms_outlined), label: const Text('Send Live Location via SMS'))),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.message, required this.showSettings, required this.onSettings, required this.onRefresh});

  final String message;
  final bool showSettings;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, color: _pink, size: 54),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              if (showSettings) ...[
                FilledButton.icon(onPressed: onSettings, icon: const Icon(Icons.settings), label: const Text('Open Settings')),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh Location')),
            ],
          ),
        ),
      );
}

class _BackgroundShapes extends StatelessWidget {
  const _BackgroundShapes();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -90, right: -70, child: _blob(260, const Color(0xFFFFE7F0))),
          Positioned(top: 330, left: -130, child: _blob(250, const Color(0xFFFFEAF2))),
          Positioned(bottom: 100, right: -100, child: _blob(280, const Color(0xFFFFE0ED))),
        ],
      ),
    );
  }

  static Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBell, required this.onMenu});

  final VoidCallback onBell;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: onMenu, icon: const Icon(Icons.menu, size: 30, color: _navy)),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(onPressed: onBell, icon: const Icon(Icons.notifications_active_outlined, size: 30, color: _navy)),
                Positioned(right: 8, top: 7, child: _dot(_pink, 9)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 9),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'PROTE', style: TextStyle(color: _navy)),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: SizedBox(
                    width: 47,
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('O', style: TextStyle(color: _pink, fontSize: 52, fontWeight: FontWeight.w900, height: .9, letterSpacing: -2)),
                        Icon(Icons.shield, color: _pink, size: 22),
                      ],
                    ),
                  ),
                ),
                TextSpan(text: 'Q', style: TextStyle(color: _pink)),
                TextSpan(text: 'T', style: TextStyle(color: _pink)),
              ],
            ),
            style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: .9, letterSpacing: -2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 58, top: 10),
          child: Text('Stay Alert. Stay Protected.', style: TextStyle(color: Color(0xFF596275), fontSize: 17)),
        ),
      ],
    );
  }
}

class _ProteqtDrawer extends StatelessWidget {
  const _ProteqtDrawer({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _items = [
    (label: 'Safety Center', icon: Icons.shield_outlined),
    (label: 'Shake-to-Alert', icon: Icons.vibration),
    (label: 'Connected Devices', icon: Icons.devices_other_outlined),
    (label: 'Settings', icon: Icons.settings_outlined),
    (label: 'About PROTEQT', icon: Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 20, 24),
              color: _pink,
              child: const Text(
                'PROTEQT',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
            for (final item in _items)
              ListTile(
                leading: Icon(item.icon, color: _deepPink),
                title: Text(item.label, style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(item.label);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class SafetyStatusCard extends StatelessWidget {
  const SafetyStatusCard({super.key, required this.isSafe, required this.onTap});

  final bool isSafe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final color = isSafe ? _green : Colors.red;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white.withAlpha(235), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x140E1830), blurRadius: 16, offset: Offset(0, 7))]),
            child: Row(
              children: [
                AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _circleIcon(isSafe ? Icons.verified_user : Icons.warning_rounded, color, isSafe ? const Color(0xFFC8F7E7) : const Color(0xFFFFE0E0), size: compact ? 70 : 82)),
                const SizedBox(width: 10),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(isSafe ? 'YOU ARE SAFE' : "I'M NOT FEELING SAFE", style: TextStyle(color: isSafe ? const Color(0xFF096647) : Colors.red.shade700, fontSize: compact ? 19 : 22, fontWeight: FontWeight.w800))), const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: const Text('Protection is Active', style: TextStyle(color: Color(0xFF596275), fontSize: 16)))])),
                Icon(Icons.chevron_right, color: isSafe ? _pink : Colors.red, size: 34),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SosSection extends StatelessWidget {
  const _SosSection({required this.onCall, required this.onSilentAlert, required this.onSos});

  final VoidCallback onCall;
  final VoidCallback onSilentAlert;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = (constraints.maxWidth * .48).clamp(140.0, 178.0);
        final sideWidth = ((constraints.maxWidth - diameter - 20) / 2).clamp(70.0, 116.0);
        return SizedBox(
          height: diameter + 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: sideWidth, child: _QuickActionCard(icon: Icons.phone, lines: const ['Quick', 'Call 112'], onTap: onCall)),
              const SizedBox(width: 10),
              _SosButton(diameter: diameter, onTap: onSos),
              const SizedBox(width: 10),
              SizedBox(width: sideWidth, child: _QuickActionCard(icon: Icons.campaign, lines: const ['Send', 'Silent Alert'], onTap: onSilentAlert)),
            ],
          ),
        );
      },
    );
  }

}

class _DeviceStatusIndicator extends StatelessWidget {
  const _DeviceStatusIndicator({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _dot(connected ? _green : Colors.red, 8),
          const SizedBox(width: 6),
          Text('DEVICE STATUS', style: TextStyle(color: connected ? _green : Colors.red, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0)),
          const SizedBox(width: 5),
          Text(connected ? 'CONNECTED' : 'DISCONNECTED', style: const TextStyle(color: _navy, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SosButton extends StatefulWidget {
  const _SosButton({required this.diameter, required this.onTap});

  final double diameter;
  final VoidCallback onTap;

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  static const _holdDuration = Duration(seconds: 1);
  Timer? _holdTimer;
  double _progress = 0;
  bool _completed = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _startHold() {
    _holdTimer?.cancel();
    _completed = false;
    setState(() => _progress = 0);
    const tick = Duration(milliseconds: 50);
    _holdTimer = Timer.periodic(tick, (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _progress = (_progress + tick.inMilliseconds / _holdDuration.inMilliseconds).clamp(0.0, 1.0));
      if (_progress >= 1) {
        timer.cancel();
        _completed = true;
        widget.onTap();
      }
    });
  }

  void _endHold() {
    _holdTimer?.cancel();
    if (!_completed && mounted) setState(() => _progress = 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _endHold(),
      onTapCancel: _endHold,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_progress > 0) SizedBox(width: widget.diameter, height: widget.diameter, child: CircularProgressIndicator(value: _progress, strokeWidth: 4, valueColor: const AlwaysStoppedAnimation<Color>(_pink), backgroundColor: const Color(0x33FF2D68))),
          Container(
        width: widget.diameter,
        height: widget.diameter,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFC1D8), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x55FF4D91), blurRadius: 20, spreadRadius: 6)],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_pink, _deepPink]),
              boxShadow: const [BoxShadow(color: Color(0xAAE51863), blurRadius: 14, spreadRadius: 2)],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_active_outlined, color: Colors.white, size: 30),
                  SizedBox(height: 4),
                  Text('SOS', style: TextStyle(color: Colors.white, fontSize: 43, fontWeight: FontWeight.w900, height: .95)),
                  SizedBox(height: 4),
                  Text('PRESS & HOLD', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('for Emergency Alert', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.icon, required this.lines, required this.onTap});
  final IconData icon;
  final List<String> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: _Panel(
          height: 124,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: _deepPink, size: 30),
            const SizedBox(height: 7),
            Text(lines.join('\n'), maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: _deepPink, fontSize: 13, fontWeight: FontWeight.w700, height: 1.15)),
          ]),
        ),
      );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.onTap, required this.onLiveLocation, required this.onTrustedContacts, required this.onVoiceTrigger, required this.onFakeCall});
  final void Function(BuildContext, String) onTap;
  final VoidCallback onLiveLocation;
  final VoidCallback onTrustedContacts;
  final VoidCallback onVoiceTrigger;
  final VoidCallback onFakeCall;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.location_on, _pink, const Color(0xFFFFE3ED), 'Live\nLocation', 'View on Map', ''),
      (Icons.groups, const Color(0xFF8B2BD9), const Color(0xFFF0E1FF), 'Trusted\nContacts', 'Manage', ''),
      (Icons.mic, const Color(0xFFF07824), const Color(0xFFFFE9D8), 'Voice\nTrigger', 'Activate', ''),
      (Icons.phone, _green, const Color(0xFFDDF7EC), 'Fake\nCall', 'Start', ''),
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        Expanded(child: _FeatureCard(icon: items[i].$1, color: items[i].$2, bg: items[i].$3, title: items[i].$4, action: items[i].$5, onTap: i == 0 ? onLiveLocation : i == 1 ? onTrustedContacts : i == 2 ? onVoiceTrigger : i == 3 ? onFakeCall : () => onTap(context, items[i].$6))),
        if (i != items.length - 1) const SizedBox(width: 10),
      ],
    ]);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.color, required this.bg, required this.title, required this.action, required this.onTap});
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: _Panel(
          height: 160,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleIcon(icon, color, bg, size: 52),
              const SizedBox(height: 10),
              Text(title, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(color: _navy, fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 7),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(action, style: const TextStyle(color: Color(0xFF596275), fontSize: 12)))), Icon(Icons.chevron_right, size: 16, color: color)]),
            ],
          ),
        ),
      );
}

class SafetyTipsCard extends StatefulWidget {
  const SafetyTipsCard({super.key});

  @override
  State<SafetyTipsCard> createState() => _SafetyTipsCardState();
}

class _SafetyTipsCardState extends State<SafetyTipsCard> {
  final _pageController = PageController();
  int _page = 0;

  final _pages = const [
    [
      (Icons.lightbulb_outline, 'Stay in\nWell-lit Areas'),
      (Icons.visibility, 'Be Aware of\nYour Surroundings'),
      (Icons.block, 'Avoid Isolated\nAreas'),
    ],
    [
      (Icons.location_on_outlined, 'Share Your\nLive Location'),
      (Icons.battery_full, 'Keep Your\nPhone Charged'),
      (Icons.groups, 'Stay Connected With\nTrusted Contacts'),
    ],
    [
      (Icons.psychology_outlined, 'Trust Your\nInstincts'),
      (Icons.phone_in_talk_outlined, 'Keep Emergency\nNumbers Ready'),
      (Icons.lock_outline, 'Keep Personal Information\nPrivate'),
    ],
    [
      (Icons.directions_walk, 'Stay Alert During\nTravel'),
      (Icons.shield_outlined, 'Use Safety Features\nWhen Needed'),
      (Icons.place_outlined, 'Move to a\nSafe Place'),
    ],
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Panel(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 15),
        child: Column(
          children: [
            Row(children: [
              const Icon(Icons.lightbulb, color: _pink, size: 27),
              const SizedBox(width: 8),
              const Expanded(child: Text('Safety Tips', style: TextStyle(color: _deepPink, fontSize: 19, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              height: 88,
              child: PageView.builder(
                controller: _pageController,
                itemCount: 4,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, page) => Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(child: _Tip(icon: _pages[page][i].$1, text: _pages[page][i].$2)),
                      if (i != 2) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 17),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  _dot(i == _page ? _pink : const Color(0xFFD9DCE4), i == _page ? 11 : 10),
                  if (i != 3) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      );
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          decoration: BoxDecoration(color: const Color(0xFFFBF9FC), borderRadius: BorderRadius.circular(17)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleIcon(icon, _pink, const Color(0xFFFFE8F0), size: 32),
              const SizedBox(height: 4),
              Text(text, maxLines: 3, textAlign: TextAlign.center, style: const TextStyle(color: _navy, fontSize: 10, fontWeight: FontWeight.w700, height: 1.15)),
            ],
          ),
        );
}

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({super.key, required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [('Home', Icons.home_rounded), ('Safety', Icons.shield_outlined), ('Location', Icons.location_on_outlined), ('Reports', Icons.description_outlined), ('Profile', Icons.person_outline)];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 11, 8, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), boxShadow: const [BoxShadow(color: Color(0x220E1830), blurRadius: 20, offset: Offset(0, 7))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (var i = 0; i < items.length; i++)
          Expanded(child: GestureDetector(onTap: () => onTap(items[i].$1), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(items[i].$2, color: i == 0 ? _pink : const Color(0xFF596275), size: 29), const SizedBox(height: 4), Text(items[i].$1, style: TextStyle(color: i == 0 ? _pink : const Color(0xFF596275), fontSize: 13, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500)), const SizedBox(height: 7), Container(height: 3, width: i == 0 ? 58 : 0, decoration: BoxDecoration(color: _pink, borderRadius: BorderRadius.circular(3)))]))),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({this.child, this.height, this.padding = EdgeInsets.zero});
  final Widget? child;
  final double? height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(height: height, padding: padding, decoration: BoxDecoration(color: Colors.white.withAlpha(235), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x140E1830), blurRadius: 16, offset: Offset(0, 7))]), child: child);
}

Widget _circleIcon(IconData icon, Color color, Color background, {required double size}) => Container(width: size, height: size, decoration: BoxDecoration(color: background, shape: BoxShape.circle), child: Icon(icon, color: color, size: size * .52));
Widget _dot(Color color, double size) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
