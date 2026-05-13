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
}
