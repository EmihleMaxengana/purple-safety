import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _incidentFolder = 'incidents';
  static const String _dmFolder = 'dms';
  static const String _profileFolder = 'profiles';
  static const String _recordingsFolder = 'recordings';

  // Core upload method
  static Future<String> uploadFile({
    required File file,
    required String userId,
    required String folder,
    String? subFolder,
  }) async {
    try {
      final String ext = path.extension(file.path);
      final String fileName = '${const Uuid().v4()}$ext';
      String storagePath = '$folder/$userId';
      if (subFolder != null && subFolder.isNotEmpty) {
        storagePath += '/$subFolder';
      }
      storagePath += '/$fileName';

      final ref = _storage.ref().child(storagePath);
      final UploadTask uploadTask = ref.putFile(file);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  // DM image
  static Future<String> uploadDMImage({
    required File file,
    required String userId,
    required String chatId,
  }) {
    return uploadFile(
      file: file,
      userId: userId,
      folder: _dmFolder,
      subFolder: chatId,
    );
  }

  // DM video
  static Future<String> uploadDMVideo({
    required File file,
    required String userId,
    required String chatId,
  }) {
    return uploadFile(
      file: file,
      userId: userId,
      folder: _dmFolder,
      subFolder: chatId,
    );
  }

  // DM audio
  static Future<String> uploadDMAudio({
    required File file,
    required String userId,
    required String chatId,
  }) {
    return uploadFile(
      file: file,
      userId: userId,
      folder: _dmFolder,
      subFolder: chatId,
    );
  }

  // Incident media (image/video)
  static Future<String> uploadIncidentMedia({
    required File file,
    required String userId,
    required String incidentId,
  }) {
    return uploadFile(
      file: file,
      userId: userId,
      folder: _incidentFolder,
      subFolder: incidentId,
    );
  }

  // Missing person image
  static Future<String> uploadMissingPersonImage({
    required File file,
    required String userId,
    required String incidentId,
  }) {
    return uploadFile(
      file: file,
      userId: userId,
      folder: _incidentFolder,
      subFolder: '$incidentId/missing_person',
    );
  }

  // Profile image
  static Future<String> uploadProfileImage({
    required String filePath,
    required String userId,
  }) {
    final file = File(filePath);
    return uploadFile(
      file: file,
      userId: userId,
      folder: _profileFolder,
    );
  }

  // Recording (audio/video)
  static Future<String> uploadRecording({
    required File file,
    required String userId,
    String? subFolder,
  }) {
    return uploadFile(
      file: file,
      userId: userId,
      folder: _recordingsFolder,
      subFolder: subFolder,
    );
  }

  // Delete single file by URL
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      // silent
    }
  }

  // Delete all user files (for account deletion)
  static Future<void> deleteUserFiles(String userId) async {
    try {
      final List<String> folders = [_incidentFolder, _dmFolder, _profileFolder, _recordingsFolder];
      for (final folder in folders) {
        try {
          final listResult = await _storage.ref().child('$folder/$userId').listAll();
          for (final item in listResult.items) {
            await item.delete();
          }
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      // ignore
    }
  }
}