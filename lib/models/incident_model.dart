import 'package:cloud_firestore/cloud_firestore.dart';

enum IncidentType {
  missingPerson,
  harassment,
  crime,
  accident,
  other,
}

class Incident {
  final String id;
  final String userId;
  final String? userName;
  final String? userPhone;
  final String? alternativePhone;
  final bool isAnonymous;
  final String title;
  final String description;
  final IncidentType type;
  
  // Missing person fields
  final String? missingPersonName;
  final int? missingPersonAge;
  final String? lastSeenLocation;
  final String? missingPersonImageUrl;
  
  // Location fields
  final String location;
  final double? latitude;
  final double? longitude;
  
  // Media
  final List<String> imageUrls;
  final List<String> videoUrls;
  
  final DateTime timestamp;
  final int commentCount;
  final int shareCount;
  final bool isResolved;
  
  // Found/Delete fields
  final bool isFound;           // Whether person has been found
  final DateTime? foundAt;      // When they were marked as found
  final DateTime? expiresAt;    // When post should be deleted (24 hours after creation)
  final DateTime? deleteAt;     // When marked as found, delete after 2 hours

  Incident({
    required this.id,
    required this.userId,
    this.userName,
    this.userPhone,
    this.alternativePhone,
    required this.isAnonymous,
    required this.title,
    required this.description,
    required this.type,
    this.missingPersonName,
    this.missingPersonAge,
    this.lastSeenLocation,
    this.missingPersonImageUrl,
    required this.location,
    this.latitude,
    this.longitude,
    this.imageUrls = const [],
    this.videoUrls = const [],
    required this.timestamp,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isResolved = false,
    this.isFound = false,
    this.foundAt,
    this.expiresAt,
    this.deleteAt,
  });

  factory Incident.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Incident(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'],
      userPhone: data['userPhone'],
      alternativePhone: data['alternativePhone'],
      isAnonymous: data['isAnonymous'] ?? false,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: IncidentType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => IncidentType.other,
      ),
      missingPersonName: data['missingPersonName'],
      missingPersonAge: data['missingPersonAge'],
      lastSeenLocation: data['lastSeenLocation'],
      missingPersonImageUrl: data['missingPersonImageUrl'],
      location: data['location'] ?? '',
      latitude: data['latitude'],
      longitude: data['longitude'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      isResolved: data['isResolved'] ?? false,
      isFound: data['isFound'] ?? false,
      foundAt: data['foundAt'] != null ? (data['foundAt'] as Timestamp).toDate() : null,
      expiresAt: data['expiresAt'] != null ? (data['expiresAt'] as Timestamp).toDate() : null,
      deleteAt: data['deleteAt'] != null ? (data['deleteAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'alternativePhone': alternativePhone,
      'isAnonymous': isAnonymous,
      'title': title,
      'description': description,
      'type': type.toString(),
      'missingPersonName': missingPersonName,
      'missingPersonAge': missingPersonAge,
      'lastSeenLocation': lastSeenLocation,
      'missingPersonImageUrl': missingPersonImageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'timestamp': Timestamp.fromDate(timestamp),
      'commentCount': commentCount,
      'shareCount': shareCount,
      'isResolved': isResolved,
      'isFound': isFound,
      'foundAt': foundAt != null ? Timestamp.fromDate(foundAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'deleteAt': deleteAt != null ? Timestamp.fromDate(deleteAt!) : null,
    };
  }
}

// ============================================================
// INCIDENT COMMENT CLASS
// ============================================================
class IncidentComment {
  final String id;
  final String incidentId;
  final String userId;
  final String? userName;
  final bool isAnonymous;
  final String comment;
  final DateTime timestamp;

  IncidentComment({
    required this.id,
    required this.incidentId,
    required this.userId,
    this.userName,
    required this.isAnonymous,
    required this.comment,
    required this.timestamp,
  });

  factory IncidentComment.fromFirestore(DocumentSnapshot doc, String incidentId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return IncidentComment(
      id: doc.id,
      incidentId: incidentId,
      userId: data['userId'] ?? '',
      userName: data['userName'],
      isAnonymous: data['isAnonymous'] ?? false,
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'isAnonymous': isAnonymous,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}