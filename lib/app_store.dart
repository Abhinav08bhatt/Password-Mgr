import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A saved email + password pair. These are the "identities" that app
/// passwords get linked to (e.g. "myemail_1@gmail.com").
class EmailCredential {
  EmailCredential({
    required this.id,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String password;
  final DateTime createdAt;

  factory EmailCredential.fromMap(Map<dynamic, dynamic> map) {
    return EmailCredential(
      id: map['id'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// A saved app/website password, linked to one of the [EmailCredential]s
/// above via [emailId].
class PasswordEntry {
  PasswordEntry({
    required this.id,
    required this.appName,
    required this.username,
    required this.emailId,
    required this.password,
    required this.createdAt,
  });

  final String id;
  final String appName;
  final String username;
  final String emailId;
  final String password;
  final DateTime createdAt;

  factory PasswordEntry.fromMap(Map<dynamic, dynamic> map) {
    return PasswordEntry(
      id: map['id'] as String,
      appName: map['appName'] as String,
      username: map['username'] as String? ?? '',
      emailId: map['emailId'] as String,
      password: map['password'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appName': appName,
      'username': username,
      'emailId': emailId,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// The single source of truth for the app. Holds everything in memory for
/// fast reads, and persists to an encrypted Hive box on every change.
///
/// Storage design (kept deliberately simple since this is a personal,
/// fully-offline vault):
/// - Data lives in a Hive box on disk, encrypted with AES (HiveAesCipher).
/// - The AES key itself never touches plain storage: it's generated once
///   with Hive's CSPRNG and kept in the OS-level secure storage
///   (Android Keystore via flutter_secure_storage), not in the Hive box
///   and not in source code.
/// - So even if someone pulled the raw app data off the phone, the vault
///   contents would just be ciphertext without the device's keystore.
class AppStore extends ChangeNotifier {
  AppStore._(this._box);

  static const _boxName = 'vault_box';
  static const _emailsKey = 'emails';
  static const _entriesKey = 'entries';

  // Where the AES encryption key for the Hive box is kept. This storage is
  // backed by the Android Keystore, not by a plain file.
  static const _secureStorage = FlutterSecureStorage();
  static const _encryptionKeyStorageName = 'vault_encryption_key';

  final Box<dynamic> _box;
  final List<EmailCredential> _emails = [];
  final List<PasswordEntry> _entries = [];

  String _searchQuery = '';

  List<EmailCredential> get emails => List.unmodifiable(_emails);
  List<PasswordEntry> get entries => List.unmodifiable(_entries);
  String get searchQuery => _searchQuery;

  static Future<AppStore> initialize() async {
    await Hive.initFlutter();
    final encryptionKey = await _loadOrCreateEncryptionKey();
    final box = await Hive.openBox<dynamic>(
      _boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );

    final store = AppStore._(box);
    store._load();
    return store;
  }

  /// Returns the existing AES key from secure storage, or generates and
  /// saves a brand new one the very first time the app runs.
  static Future<List<int>> _loadOrCreateEncryptionKey() async {
    final existing = await _secureStorage.read(key: _encryptionKeyStorageName);
    if (existing != null) {
      return base64Decode(existing);
    }

    final newKey = Hive.generateSecureKey();
    await _secureStorage.write(
      key: _encryptionKeyStorageName,
      value: base64Encode(newKey),
    );
    return newKey;
  }

  void _load() {
    final storedEmails =
        (_box.get(_emailsKey, defaultValue: <dynamic>[]) as List<dynamic>)
            .cast<Map>()
            .map(EmailCredential.fromMap)
            .toList();
    final storedEntries =
        (_box.get(_entriesKey, defaultValue: <dynamic>[]) as List<dynamic>)
            .cast<Map>()
            .map(PasswordEntry.fromMap)
            .toList();

    _emails
      ..clear()
      ..addAll(storedEmails);
    _entries
      ..clear()
      ..addAll(storedEntries);
    _sortData();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  EmailCredential? emailById(String id) {
    for (final email in _emails) {
      if (email.id == id) {
        return email;
      }
    }
    return null;
  }

  /// Adds a new email + password identity. Throws [StateError] if that
  /// email is already saved, so the UI can show a clear message.
  Future<void> addEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      throw ArgumentError('Email and password are required.');
    }

    final exists = _emails.any(
      (item) => item.email.toLowerCase() == trimmedEmail.toLowerCase(),
    );
    if (exists) {
      throw StateError('This email already exists.');
    }

    _emails.add(
      EmailCredential(
        id: _newId(),
        email: trimmedEmail,
        password: trimmedPassword,
        createdAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  Future<void> updateEmail({
    required String id,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      throw ArgumentError('Email and password are required.');
    }

    final index = _emails.indexWhere((item) => item.id == id);
    if (index == -1) {
      throw StateError('This email no longer exists.');
    }

    final exists = _emails.any(
      (item) =>
          item.id != id &&
          item.email.toLowerCase() == trimmedEmail.toLowerCase(),
    );
    if (exists) {
      throw StateError('This email already exists.');
    }

    final current = _emails[index];
    _emails[index] = EmailCredential(
      id: current.id,
      email: trimmedEmail,
      password: trimmedPassword,
      createdAt: current.createdAt,
    );
    await _persist();
  }

  Future<void> deleteEmail(String id) async {
    _emails.removeWhere((item) => item.id == id);
    _entries.removeWhere((entry) => entry.emailId == id);
    await _persist();
  }

  /// Adds a new app/website password entry linked to an existing email.
  Future<void> addEntry({
    required String appName,
    required String username,
    required String emailId,
    required String password,
  }) async {
    final trimmedAppName = appName.trim();
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();
    if (trimmedAppName.isEmpty || emailId.isEmpty || trimmedPassword.isEmpty) {
      throw ArgumentError('App name, email and password are required.');
    }

    _entries.add(
      PasswordEntry(
        id: _newId(),
        appName: trimmedAppName,
        username: trimmedUsername,
        emailId: emailId,
        password: trimmedPassword,
        createdAt: DateTime.now(),
      ),
    );
    await _persist();
  }

  Future<void> updateEntry({
    required String id,
    required String appName,
    required String username,
    required String emailId,
    required String password,
  }) async {
    final trimmedAppName = appName.trim();
    final trimmedUsername = username.trim();
    final trimmedPassword = password.trim();
    if (trimmedAppName.isEmpty || emailId.isEmpty || trimmedPassword.isEmpty) {
      throw ArgumentError('App name, email and password are required.');
    }

    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw StateError('This password entry no longer exists.');
    }

    final current = _entries[index];
    _entries[index] = PasswordEntry(
      id: current.id,
      appName: trimmedAppName,
      username: trimmedUsername,
      emailId: emailId,
      password: trimmedPassword,
      createdAt: current.createdAt,
    );
    await _persist();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _persist();
  }

  /// Entries matching the current search query, grouped by the first
  /// letter of the app name (used to render the A-Z section headers).
  Map<String, List<PasswordEntry>> groupedVisibleEntries() {
    final filtered = _entries.where((entry) {
      if (_searchQuery.isEmpty) {
        return true;
      }

      final query = _searchQuery.toLowerCase();
      return entry.appName.toLowerCase().contains(query);
    }).toList();

    final grouped = <String, List<PasswordEntry>>{};
    for (final entry in filtered) {
      final letter = entry.appName.trim().isEmpty
          ? '#'
          : entry.appName[0].toUpperCase();
      grouped.putIfAbsent(letter, () => <PasswordEntry>[]).add(entry);
    }
    return grouped;
  }

  Future<void> _persist() async {
    _sortData();
    await _box.put(
      _emailsKey,
      _emails.map((email) => email.toMap()).toList(growable: false),
    );
    await _box.put(
      _entriesKey,
      _entries.map((entry) => entry.toMap()).toList(growable: false),
    );
    notifyListeners();
  }

  void _sortData() {
    _emails.sort(
      (a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
    );
    _entries.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );
  }

  String _newId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
  }
}
