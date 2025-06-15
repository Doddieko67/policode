import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType { spam, inappropriate, harassment, misinformation, other }

enum ReportStatus { pending, reviewed, resolved, dismissed }

enum ReportedContentType { post, reply, user }

class ReportModel {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedUserId;
  final String reportedUserName;
  final ReportedContentType contentType;
  final String contentId;
  final String contentPreview;
  final ReportType type;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? resolutionNotes;
  final String? actionTaken;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedUserId,
    required this.reportedUserName,
    required this.contentType,
    required this.contentId,
    required this.contentPreview,
    required this.type,
    required this.reason,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.resolutionNotes,
    this.actionTaken,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? 'Usuario desconocido',
      reportedUserId: data['reportedUserId'] ?? '',
      reportedUserName: data['reportedUserName'] ?? 'Usuario desconocido',
      contentType: ReportedContentType.values.firstWhere(
        (t) => t.name == data['contentType'],
        orElse: () => ReportedContentType.post,
      ),
      contentId: data['contentId'] ?? '',
      contentPreview: data['contentPreview'] ?? '',
      type: ReportType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => ReportType.other,
      ),
      reason: data['reason'] ?? '',
      status: ReportStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ReportStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      reviewedBy: data['reviewedBy'],
      resolutionNotes: data['resolutionNotes'],
      actionTaken: data['actionTaken'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'contentType': contentType.name,
      'contentId': contentId,
      'contentPreview': contentPreview,
      'type': type.name,
      'reason': reason,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt': reviewedAt != null
          ? Timestamp.fromDate(reviewedAt!)
          : null,
      'reviewedBy': reviewedBy,
      'resolutionNotes': resolutionNotes,
      'actionTaken': actionTaken,
    };
  }

  String get typeLabel {
    switch (type) {
      case ReportType.spam:
        return 'Spam';
      case ReportType.inappropriate:
        return 'Contenido inapropiado';
      case ReportType.harassment:
        return 'Acoso';
      case ReportType.misinformation:
        return 'Información falsa';
      case ReportType.other:
        return 'Otro';
    }
  }

  String get statusLabel {
    switch (status) {
      case ReportStatus.pending:
        return 'Pendiente';
      case ReportStatus.reviewed:
        return 'En revisión';
      case ReportStatus.resolved:
        return 'Resuelto';
      case ReportStatus.dismissed:
        return 'Desestimado';
    }
  }
}