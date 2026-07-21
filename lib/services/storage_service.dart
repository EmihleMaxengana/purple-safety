import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _incidentFolder = 'incidents';
  static const String _dmFolder = 'dms';

  // Upload an image (or any file) and return the public download URL.
  static Future<String> uploadFile({
    required File file,
    required String folder, // e.g., 'dms', 'incidents'
    String? subFolder,      // optional: chatId or incidentId
  }) async {
    try {
      final String ext = path.extension(file.path);
      final String fileName = '${const Uuid().v4()}$ext';
      String storagePath = '$folder';
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

  // Convenience: upload image for DM
  static Future<String> uploadDMImage(File file, String chatId) {
    return uploadFile(file: file, folder: _dmFolder, subFolder: chatId);
  }

  // Convenience: upload video for DM
  static Future<String> uploadDMVideo(File file, String chatId) {
    return uploadFile(file: file, folder: _dmFolder, subFolder: chatId);
  }

  // Convenience: upload audio for DM
  static Future<String> uploadDMAudio(File file, String chatId) {
    return uploadFile(file: file, folder: _dmFolder, subFolder: chatId);
  }

  // Convenience: upload incident media
  static Future<String> uploadIncidentMedia(File file, String incidentId) {
    return uploadFile(file: file, folder: _incidentFolder, subFolder: incidentId);
  }

  // Delete a file by URL (optional)
  static Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      // Silent fail if file doesn't exist
    }
  }
}