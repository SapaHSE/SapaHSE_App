/// Types of items that can require superadmin approval.
enum ApprovalType {
  registerUser,
  license,
  certification,
}

/// Status for an approval request.
enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

/// A single approval request visible to superadmin in Inbox → Tugas.
class ApprovalItem {
  final String id;
  final ApprovalType type;
  ApprovalStatus status; // mutable for optimistic updates
  final String title;
  final String subtitle;
  final String requesterName;
  final String? requesterPhoto;
  final String? department;
  final String? company;
  final DateTime createdAt;
  final Map<String, dynamic> metadata; // additional data per type

  ApprovalItem({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.requesterName,
    this.requesterPhoto,
    this.department,
    this.company,
    required this.createdAt,
    this.metadata = const {},
  });

  String get typeLabel {
    switch (type) {
      case ApprovalType.registerUser:
        return 'Registrasi User';
      case ApprovalType.license:
        return 'Input Lisensi';
      case ApprovalType.certification:
        return 'Input Sertifikat';
    }
  }

  String get statusLabel {
    switch (status) {
      case ApprovalStatus.pending:
        return 'Menunggu';
      case ApprovalStatus.approved:
        return 'Disetujui';
      case ApprovalStatus.rejected:
        return 'Ditolak';
    }
  }
  factory ApprovalItem.fromJson(Map<String, dynamic> json) {
    ApprovalType type;
    final typeStr = json['type']?.toString();
    if (typeStr == 'license') {
      type = ApprovalType.license;
    } else if (typeStr == 'certification') {
      type = ApprovalType.certification;
    } else {
      type = ApprovalType.registerUser;
    }

    ApprovalStatus status;
    final statusStr = json['status']?.toString();
    if (statusStr == 'approved') {
      status = ApprovalStatus.approved;
    } else if (statusStr == 'rejected') {
      status = ApprovalStatus.rejected;
    } else {
      status = ApprovalStatus.pending;
    }

    return ApprovalItem(
      id: json['id']?.toString() ?? '',
      type: type,
      status: status,
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      requesterName: json['requester_name']?.toString() ?? 'Unknown',
      requesterPhoto: json['requester_photo']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()) 
          : DateTime.now(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : {},
    );
  }
}
