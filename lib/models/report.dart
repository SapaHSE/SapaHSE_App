enum ReportType { hazard, inspection }

enum ReportSeverity { low, medium, high, critical }

enum ReportStatus { open, inProgress, closed }

// Sub-kategori hazard / inspection
enum HazardCategory {
  unsafeAct,
  unsafeCondition,
  nearMiss,
  propertyDamage,
  environmentalHazard,
  spill,
  slipTripFall,
  fireSafety,
  // Inspection types
  routineInspection,
  electricalInspection,
  equipmentInspection,
}

// Sub-status per kategori utama
enum ReportSubStatus {
  // Open
  validating,
  approved,
  assigned,
  // In Progress
  preparing,
  executing,
  reviewing,
  // Closed
  resolved,
  rejected,
  deferred,
}

class Report {
  final String id;
  final String? ticketNumber;
  final String title;
  final String description;
  final ReportType type;
  final HazardCategory? category;
  final String? subkategori;
  final ReportSeverity severity;
  final ReportStatus status;
  final ReportSubStatus? subStatus;
  final String location;
  final String? kejadianLocation;
  final String? saran;
  final String? perusahaan;
  final String? departemen;
  final String? tagOrang;
  final DateTime createdAt;
  final String reportedBy;
  final String? reporterId;
  final String imageUrl;

  // Additional Backend Fields
  final String? area;
  final String? inspector;
  final String? notes;
  final String? result;

  const Report({
    required this.id,
    this.ticketNumber,
    required this.title,
    required this.description,
    required this.type,
    this.category,
    this.subkategori,
    required this.severity,
    required this.status,
    this.subStatus,
    required this.location,
    this.kejadianLocation,
    this.saran,
    this.perusahaan,
    this.departemen,
    this.tagOrang,
    required this.createdAt,
    required this.reportedBy,
    this.reporterId,
    required this.imageUrl,
    this.area,
    this.inspector,
    this.notes,
    this.result,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    // Detect type based on fields or provided type
    final isInspection = json.containsKey('area') ||
        json.containsKey('name_inspector') ||
        json['type'] == 'inspection';

    final reportedByMap = json['reported_by'];
    String? rId;
    if (reportedByMap is Map) {
      rId = reportedByMap['id']?.toString();
    }

    return Report(
      id: json['id']?.toString() ?? '',
      ticketNumber: json['ticket_number']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: isInspection ? ReportType.inspection : ReportType.hazard,
      category: _mapCategory(json['hazard_category']),
      subkategori: json['hazard_subcategory']?.toString() ?? json['subkategori']?.toString(),
      severity: _mapSeverity(json['severity']),
      status: _mapStatus(json['status']),
      subStatus: _mapSubStatus(json['sub_status']),
      location: json['location']?.toString() ?? json['kejadian_location']?.toString() ?? '',
      kejadianLocation: json['kejadian_location']?.toString() ?? json['location']?.toString(),
      saran: json['suggestion']?.toString() ?? json['saran']?.toString(),
      perusahaan: json['perusahaan']?.toString(),
      departemen: json['reported_department']?.toString() ?? json['departemen']?.toString(),
      tagOrang: json['name_pja']?.toString() ?? json['tag_orang']?.toString(),
      createdAt: json['created_at'] != null
          ? (json['created_at'] is String
              ? DateTime.parse(json['created_at'])
              : DateTime.now())
          : DateTime.now(),
      reportedBy: _mapReportedBy(json),
      reporterId: rId,
      imageUrl: json['image_url']?.toString() ?? '',
      area: json['area']?.toString(),
      inspector: json['name_inspector']?.toString(),
      notes: json['notes']?.toString(),
      result: json['result']?.toString(),
    );
  }

  static String _mapReportedBy(Map<String, dynamic> json) {
    final rb = json['reported_by'];
    if (rb is Map) {
      return rb['full_name']?.toString() ??
          rb['name']?.toString() ??
          rb['username']?.toString() ??
          'User';
    }
    if (rb != null) return rb.toString();

    final pja = json['name_pja'] ?? json['tag_orang'];
    if (pja != null) return pja.toString();

    final insp = json['name_inspector'];
    if (insp != null) return insp.toString();

    return 'Unknown';
  }

  static HazardCategory? _mapCategory(dynamic val) {
    if (val == null) return null;
    final s = val.toString().toLowerCase();
    if (s.contains('act') || s == 'tta' || s.contains('tindakan')) return HazardCategory.unsafeAct;
    if (s.contains('condition') || s == 'kta' || s.contains('kondisi')) return HazardCategory.unsafeCondition;
    if (s.contains('miss')) return HazardCategory.nearMiss;
    if (s.contains('damage')) return HazardCategory.propertyDamage;
    if (s.contains('enviro')) return HazardCategory.environmentalHazard;
    if (s.contains('spill')) return HazardCategory.spill;
    if (s.contains('slip') || s.contains('fall')) return HazardCategory.slipTripFall;
    if (s.contains('fire')) return HazardCategory.fireSafety;
    return null;
  }

  static ReportSeverity _mapSeverity(dynamic val) {
    if (val == null) return ReportSeverity.low;
    final s = val.toString().toLowerCase();
    if (s == 'high') return ReportSeverity.high;
    if (s == 'medium') return ReportSeverity.medium;
    if (s == 'critical') return ReportSeverity.critical;
    return ReportSeverity.low;
  }

  static ReportStatus _mapStatus(dynamic val) {
    if (val == null) return ReportStatus.open;
    final s = val.toString().toLowerCase();
    if (s == 'in_progress' || s == 'progress') return ReportStatus.inProgress;
    if (s == 'closed') return ReportStatus.closed;
    return ReportStatus.open;
  }

  static ReportSubStatus? _mapSubStatus(dynamic val) {
    if (val == null) return null;
    final s = val.toString().toLowerCase();
    for (var v in ReportSubStatus.values) {
      if (v.name.toLowerCase() == s) return v;
    }
    return null;
  }
}

extension ReportTypeLabel on ReportType {
  String get label {
    switch (this) {
      case ReportType.hazard:     return 'Hazard';
      case ReportType.inspection: return 'Inspection';
    }
  }
}

extension HazardCategoryLabel on HazardCategory {
  String get label {
    switch (this) {
      case HazardCategory.unsafeAct:            return 'Unsafe Act';
      case HazardCategory.unsafeCondition:       return 'Unsafe Condition';
      case HazardCategory.nearMiss:              return 'Near Miss';
      case HazardCategory.propertyDamage:        return 'Property Damage';
      case HazardCategory.environmentalHazard:   return 'Environmental Hazard';
      case HazardCategory.spill:                 return 'Spill';
      case HazardCategory.slipTripFall:          return 'Slip, Trip, Fall';
      case HazardCategory.fireSafety:            return 'Fire Safety';
      case HazardCategory.routineInspection:     return 'Routine Inspection';
      case HazardCategory.electricalInspection:  return 'Electrical Inspection';
      case HazardCategory.equipmentInspection:   return 'Equipment Inspection';
    }
  }
}

extension ReportSeverityLabel on ReportSeverity {
  String get label {
    switch (this) {
      case ReportSeverity.low:      return 'Low';
      case ReportSeverity.medium:   return 'Medium';
      case ReportSeverity.high:     return 'High';
      case ReportSeverity.critical: return 'Critical';
    }
  }
}

extension ReportStatusLabel on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.open:       return 'Open';
      case ReportStatus.inProgress: return 'In Progress';
      case ReportStatus.closed:     return 'Closed';
    }
  }
}

extension ReportSubStatusInfo on ReportSubStatus {
  String get label {
    switch (this) {
      case ReportSubStatus.validating: return 'Validating';
      case ReportSubStatus.approved:   return 'Approved';
      case ReportSubStatus.assigned:   return 'Assigned';
      case ReportSubStatus.preparing:  return 'Preparing';
      case ReportSubStatus.executing:  return 'Executing';
      case ReportSubStatus.reviewing:  return 'Reviewing';
      case ReportSubStatus.resolved:   return 'Resolved';
      case ReportSubStatus.rejected:   return 'Rejected';
      case ReportSubStatus.deferred:   return 'Deferred';
    }
  }

  ReportStatus get parentStatus {
    switch (this) {
      case ReportSubStatus.validating:
      case ReportSubStatus.approved:
      case ReportSubStatus.assigned:
        return ReportStatus.open;
      case ReportSubStatus.preparing:
      case ReportSubStatus.executing:
      case ReportSubStatus.reviewing:
        return ReportStatus.inProgress;
      case ReportSubStatus.resolved:
      case ReportSubStatus.rejected:
      case ReportSubStatus.deferred:
        return ReportStatus.closed;
    }
  }

  static List<ReportSubStatus> forStatus(ReportStatus s) {
    switch (s) {
      case ReportStatus.open:
        return [ReportSubStatus.validating, ReportSubStatus.approved, ReportSubStatus.assigned];
      case ReportStatus.inProgress:
        return [ReportSubStatus.preparing, ReportSubStatus.executing, ReportSubStatus.reviewing];
      case ReportStatus.closed:
        return [ReportSubStatus.resolved, ReportSubStatus.rejected, ReportSubStatus.deferred];
    }
  }
}
