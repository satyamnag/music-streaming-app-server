import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sangeet/services/logger/logger.dart';

/// AES-256-CBC encryption service for downloaded audio files.
///
/// Files are encrypted with a per-install unique key stored in Android
/// Keystore (via flutter_secure_storage). The encrypted format is:
///   [magic: 4 bytes "SBEN"] [version: 1 byte] [IV: 16 bytes] [ciphertext]
///
/// Encrypted files use the `.sbm` extension (Soulful Bhakti Music) and are
/// stored in app-private storage, making them inaccessible to other apps.
/// Decryption happens only in memory — the decrypted audio is streamed
/// through the local server to media_kit and never written to disk.
class AudioEncryptionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _keyStorageKey = 'audio_encryption_key';
  static const _magic = [0x53, 0x42, 0x45, 0x4E]; // "SBEN"
  static const _version = 1;
  static const _ivLength = 16;
  static const _keyLength = 32;

  static Uint8List? _cachedKeyBytes;

  /// Returns the downloads directory (app-private on Android).
  static Future<Directory> get downloadsDir async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(join(supportDir.path, 'downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the encrypted file path for a given track ID.
  static Future<String> encryptedFilePath(String trackId) async {
    final dir = await downloadsDir;
    return join(dir.path, '$trackId.sbm');
  }

  /// Checks if an encrypted file exists for the given track ID.
  static Future<bool> hasEncryptedFile(String trackId) async {
    final path = await encryptedFilePath(trackId);
    return File(path).exists();
  }

  /// Gets or creates the 32-byte AES-256 encryption key.
  /// The key is stored in flutter_secure_storage (Android Keystore-backed),
  /// base64-encoded so it survives the storage round-trip losslessly.
  static Future<Key> _getKey() async {
    if (_cachedKeyBytes != null && _cachedKeyBytes!.length == _keyLength) {
      return Key(_cachedKeyBytes!);
    }

    try {
      final stored = await _storage.read(key: _keyStorageKey);
      if (stored != null) {
        final decoded = base64Decode(stored);
        if (decoded.length == _keyLength) {
          _cachedKeyBytes = decoded;
          return Key(decoded);
        }
      }
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }

    // Generate a new 32-byte key
    final keyBytes = IV.fromSecureRandom(_keyLength).bytes;

    try {
      await _storage.write(key: _keyStorageKey, value: base64Encode(keyBytes));
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
    }

    _cachedKeyBytes = keyBytes;
    return Key(keyBytes);
  }

  /// Encrypts a raw audio file and saves it as an encrypted `.sbm` file.
  /// The raw file is deleted after successful encryption.
  /// Returns the path of the encrypted file.
  static Future<String> encryptFile(File rawFile, String trackId) async {
    final key = await _getKey();
    final iv = IV.fromSecureRandom(_ivLength);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final rawBytes = await rawFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(rawBytes, iv: iv);

    // Build the encrypted file: magic + version + IV + ciphertext
    final output = <int>[
      ..._magic,
      _version,
      ...iv.bytes,
      ...encrypted.bytes,
    ];

    final encPath = await encryptedFilePath(trackId);
    final encFile = File(encPath);
    await encFile.writeAsBytes(output);

    // Delete the raw (unencrypted) file
    if (await rawFile.exists()) {
      await rawFile.delete();
    }

    return encPath;
  }

  /// Decrypts an encrypted `.sbm` file and returns the raw audio bytes.
  /// This is called in-memory only — the decrypted bytes are never written
  /// to disk. They are served through the local server to media_kit.
  static Future<Uint8List> decryptFile(String trackId) async {
    final path = await encryptedFilePath(trackId);
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Encrypted file not found: $path', path);
    }

    final data = await file.readAsBytes();

    // Validate magic
    if (data.length < _magic.length + 1 + _ivLength) {
      throw const FormatException('File too small to be a valid .sbm file');
    }

    for (var i = 0; i < _magic.length; i++) {
      if (data[i] != _magic[i]) {
        throw const FormatException('Invalid .sbm magic header');
      }
    }

    // Extract IV and ciphertext
    final ivStart = _magic.length + 1; // skip magic + version
    final ivBytes = Uint8List.fromList(
      data.sublist(ivStart, ivStart + _ivLength),
    );
    final cipherBytes = Uint8List.fromList(
      data.sublist(ivStart + _ivLength),
    );

    final key = await _getKey();
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    final decrypted = encrypter.decryptBytes(Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// Deletes an encrypted file for a given track ID.
  static Future<void> deleteEncryptedFile(String trackId) async {
    final path = await encryptedFilePath(trackId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}