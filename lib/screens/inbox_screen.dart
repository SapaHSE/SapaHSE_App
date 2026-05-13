import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/inbox_item.dart';
import '../models/report.dart';
import '../models/approval_item.dart';
import '../services/cloud_save_service.dart';
import '../services/inbox_service.dart';
import 'report_detail_screen.dart';
import '../widgets/sapa_hse_header.dart';
import '../services/approval_service.dart';
import '../services/storage_service.dart';


enum _SubFilter { unread, read }
enum _MyPostFilter { all, draft, pending, approved, rejected }
enum _ApprovalFilter { all, pending, approved, rejected }

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _mainTabController;
  _SubFilter _activeFilter = _SubFilter.unread;
  _MyPostFilter _activeMyPostFilter = _MyPostFilter.all;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ── Server-backed state ────────────────────────────────────────────────────
  List<InboxItem> _reports = [];
  List<InboxItem> _announcements = [];
  List<Report> _myRawReports = [];
  List<ReportDraft> _myDrafts = [];
  bool _loadingReports = false;
  bool _loadingAnnouncements = false;
  bool _loadingMyReports = false;
  String? _errorReports;
  String? _errorAnnouncements;
  String? _errorMyReports;
  String? _currentUserId;

  // ── Superadmin Approval state ──────────────────────────────────────────────
  bool _isSuperAdmin = false;
  List<ApprovalItem> _approvals = [];
  bool _loadingApprovals = false;
  _ApprovalFilter _activeApprovalFilter = _ApprovalFilter.all;

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _activeFilter = _SubFilter.unread; // Reset filter when switching tabs
        });
      }
    });
    _loadCurrentUser();
    // Fetch both tabs in parallel so badges are accurate from the start.
    _loadReports();
    _loadAnnouncements();
  }

  Future<void> _loadCurrentUser() async {
    final user = await StorageService.getUser();
    if (user != null) {
      final role = user['role']?.toString().toLowerCase() ?? '';
      setState(() {
        _currentUserId = user['id']?.toString();
        _isSuperAdmin = role == 'superadmin' || role == 'super admin';
      });
      _loadMyReports();
      if (_isSuperAdmin) {
        _loadApprovals();
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mainTabController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadReports() async {
    setState(() {
      _loadingReports = true;
      _errorReports = null;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _loadingReports = false;
      _reports = [
        InboxItem(
          id: 'r1',
          itemType: InboxItemType.report,
          isRead: false,
          title: 'Kebocoran Pipa Bahan Kimia Area Produksi',
          body: 'Ditemukan kebocoran kecil pada pipa bahan kimia di area produksi. Perlu perbaikan segera.',
          fromName: 'Budi Santoso',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          reportType: ReportType.hazard,
          status: ReportStatus.open,
          severity: ReportSeverity.high,
          location: 'Area Produksi - Pipa Utama',
          imageUrl: '',
          ticketNumber: 'TKT-2026-001',
        ),
        InboxItem(
          id: 'r2',
          itemType: InboxItemType.report,
          isRead: true,
          title: 'Inspeksi Rutin Peralatan Berat',
          body: 'Inspeksi rutin bulanan pada alat berat selesai dilakukan. Semua dalam kondisi baik.',
          fromName: 'Ahmad Wijaya',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          reportType: ReportType.inspection,
          status: ReportStatus.closed,
          severity: ReportSeverity.low,
          location: 'Gudang Alat Berat',
          imageUrl: '',
          ticketNumber: 'TKT-2026-002',
        ),
        InboxItem(
          id: 'r3',
          itemType: InboxItemType.report,
          isRead: false,
          title: 'Laporan Kecelakaan Kerja Ringan',
          body: 'Karyawan mengalami cedera ringan saat mengoperasikan mesin. Sedang dalam penanganan medis.',
          fromName: 'Rina Kusuma',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          reportType: ReportType.hazard,
          status: ReportStatus.inProgress,
          severity: ReportSeverity.critical,
          location: 'Mesin Pemotong - Lantai 2',
          imageUrl: '',
          ticketNumber: 'TKT-2026-003',
        ),
        InboxItem(
          id: 'r4',
          itemType: InboxItemType.report,
          isRead: true,
          title: 'Pembersihan Tumpahan Minyak',
          body: 'Tumpahan minyak telah dibersihkan dan area sudah aman.',
          fromName: 'Slamet Hadi',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          reportType: ReportType.hazard,
          status: ReportStatus.closed,
          severity: ReportSeverity.medium,
          location: 'Parkir Kendaraan',
          imageUrl: '',
          ticketNumber: 'TKT-2026-004',
        ),
      ];
    });
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loadingAnnouncements = true;
      _errorAnnouncements = null;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _loadingAnnouncements = false;
      _announcements = [
        InboxItem(
          id: 'a1',
          itemType: InboxItemType.announcement,
          isRead: false,
          title: 'Pelatihan K3 Wajib Maret 2026',
          body: 'Seluruh karyawan diwajibkan mengikuti pelatihan K3 pada tanggal 28 Maret 2026 pukul 08.00 di Aula Utama. Kehadiran bersifat wajib.',
          fromName: 'Admin HSE',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        InboxItem(
          id: 'a2',
          itemType: InboxItemType.announcement,
          isRead: false,
          title: 'Inspeksi Rutin Area Tambang',
          body: 'Akan dilaksanakan inspeksi rutin menyeluruh di seluruh area tambang pada minggu ini. Harap semua peralatan dalam kondisi siap periksa.',
          fromName: 'Supervisor K3',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        InboxItem(
          id: 'a3',
          itemType: InboxItemType.announcement,
          isRead: false,
          title: 'Update SOP Penanganan Bahan B3',
          body: 'SOP penanganan limbah B3 telah diperbarui sesuai regulasi KLHK terbaru. Silakan unduh dokumen terbaru di portal internal perusahaan.',
          fromName: 'Admin HSE',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        InboxItem(
          id: 'a4',
          itemType: InboxItemType.announcement,
          isRead: false,
          title: 'Jadwal Pemeriksaan APAR Bulanan',
          body: 'Pemeriksaan APAR bulanan akan dilaksanakan pada 30 Maret 2026. Pastikan semua unit APAR di area tanggung jawab Anda dalam kondisi baik.',
          fromName: 'Tim HSE',
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
      ];
    });
  }

  Future<void> _loadMyReports() async {
    if (_currentUserId == null) return;
    setState(() {
      _loadingMyReports = true;
      _errorMyReports = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      _loadingMyReports = false;
      _myDrafts = [
        ReportDraft(
          id: 'd1',
          type: DraftType.hazard,
          title: 'Laporan Bahaya Bahan Kimia',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          data: {
            'description': 'Kebocoran bahan kimia berbahaya di area produksi',
            'kronologi': 'Kebocoran terjadi saat proses pengisian tangki',
            'location': 'Area Produksi - Tangki B-01',
            'severity': 'high',
          },
        ),
        ReportDraft(
          id: 'd2',
          type: DraftType.inspection,
          title: 'Draft Inspeksi Peralatan Keselamatan',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          data: {
            'description': 'Inspeksi rutin peralatan keselamatan kerja',
            'kronologi': 'Pemeriksaan alat pelindung diri dan peralatan darurat',
            'location': 'Gudang Peralatan',
            'severity': 'medium',
          },
        ),
      ];
      _myRawReports = [
        Report(
          id: 'mr1',
          title: 'Laporan Kecelakaan Kerja Ringan',
          description: 'Karyawan terpeleset di area basah',
          type: ReportType.hazard,
          status: ReportStatus.open,
          subStatus: ReportSubStatus.validating,
          severity: ReportSeverity.medium,
          location: 'Area Gudang - Lorong Utama',
          imageUrl: '',
          ticketNumber: 'TKT-2026-005',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          reportedBy: 'Noor Lintang Bhaskara',
          reporterId: 'user123',
        ),
        Report(
          id: 'mr2',
          title: 'Inspeksi Rutin Peralatan Pemadam',
          description: 'Pemeriksaan rutin APAR dan peralatan pemadam kebakaran',
          type: ReportType.inspection,
          status: ReportStatus.open,
          subStatus: null,
          severity: ReportSeverity.low,
          location: 'Seluruh Area Pabrik',
          imageUrl: '',
          ticketNumber: 'TKT-2026-006',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          reportedBy: 'Noor Lintang Bhaskara',
          reporterId: 'user123',
        ),
        Report(
          id: 'mr3',
          title: 'Laporan Kebocoran Pipa Air',
          description: 'Kebocoran pipa air telah diperbaiki',
          type: ReportType.hazard,
          status: ReportStatus.closed,
          subStatus: ReportSubStatus.rejected,
          severity: ReportSeverity.low,
          location: 'Area Parkir',
          imageUrl: '',
          ticketNumber: 'TKT-2026-007',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          reportedBy: 'Noor Lintang Bhaskara',
          reporterId: 'user123',
        ),
      ];
    });
  }

  // ── Approval loading (superadmin only) ─────────────────────────────────────
  Future<void> _loadApprovals() async {
    setState(() => _loadingApprovals = true);
    try {
      final list = await ApprovalService.getPendingApprovals();
      if (!mounted) return;
      setState(() {
        _approvals = list;
        _loadingApprovals = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingApprovals = false);
    }
  }

  int get _pendingApprovalCount =>
      _approvals.where((a) => a.status == ApprovalStatus.pending).length;

  List<ApprovalItem> get _filteredApprovals {
    switch (_activeApprovalFilter) {
      case _ApprovalFilter.pending:
        return _approvals.where((a) => a.status == ApprovalStatus.pending).toList();
      case _ApprovalFilter.approved:
        return _approvals.where((a) => a.status == ApprovalStatus.approved).toList();
      case _ApprovalFilter.rejected:
        return _approvals.where((a) => a.status == ApprovalStatus.rejected).toList();
      case _ApprovalFilter.all:
        return List.from(_approvals);
    }
  }

  int _approvalFilterCount(_ApprovalFilter f) {
    switch (f) {
      case _ApprovalFilter.all:
        return _approvals.length;
      case _ApprovalFilter.pending:
        return _approvals.where((a) => a.status == ApprovalStatus.pending).length;
      case _ApprovalFilter.approved:
        return _approvals.where((a) => a.status == ApprovalStatus.approved).length;
      case _ApprovalFilter.rejected:
        return _approvals.where((a) => a.status == ApprovalStatus.rejected).length;
    }
  }

  String _approvalFilterLabel(_ApprovalFilter f) {
    switch (f) {
      case _ApprovalFilter.all: return 'Semua';
      case _ApprovalFilter.pending: return 'Menunggu';
      case _ApprovalFilter.approved: return 'Disetujui';
      case _ApprovalFilter.rejected: return 'Ditolak';
    }
  }

  InboxItem _reportToInboxItem(Report r) {
    return InboxItem(
      id: r.id,
      itemType: InboxItemType.report,
      isRead: true,
      title: r.title,
      createdAt: r.createdAt,
      reportType: r.type,
      description: r.description,
      status: r.status,
      
      location: r.location,
      imageUrl: r.imageUrl,
      severity: r.severity,
      ticketNumber: r.ticketNumber,
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _loadReports();
      _loadAnnouncements();
    });
  }

  // ── Filtering (client-side by read/unread + already filtered list) ────────
  List<InboxItem> _filterByReadState(List<InboxItem> source) {
    if (_activeFilter == _SubFilter.unread) {
      return source.where((i) => !i.isRead).toList();
    }
    return source.where((i) => i.isRead).toList();
  }

  // Reports where user is tagged (inbox tasks assigned to the user)
  List<InboxItem> get _personalReports => _reports;

  // Reports created by the current user, fetched from ReportService
  List<InboxItem> get _myReports =>
      _myRawReports.map(_reportToInboxItem).toList();

  int _severityValue(ReportSeverity? s) {
    if (s == null) return 0;
    switch (s) {
      case ReportSeverity.critical:
        return 4;
      case ReportSeverity.high:
        return 3;
      case ReportSeverity.medium:
        return 2;
      case ReportSeverity.low:
        return 1;
    }
  }

  List<InboxItem> get _activeReports {
    var list = _personalReports.where((i) {
      if (_activeFilter == _SubFilter.unread) {
        return i.status != ReportStatus.closed;
      } else {
        return i.status == ReportStatus.closed;
      }
    }).toList();
    
    list.sort((a, b) {
      final sevA = _severityValue(a.severity);
      final sevB = _severityValue(b.severity);
      if (sevA != sevB) {
        return sevB.compareTo(sevA);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((i) => 
        i.title.toLowerCase().contains(q) || 
        (i.location?.toLowerCase().contains(q) ?? false) || 
        (i.reportedBy?.fullName.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    
    return list;
  }

  List<InboxItem> get _activeAnnouncements =>
      _filterByReadState(_announcements);
       
  List<InboxItem> get _activeMyReports {
    final drafts = _myDrafts.map((d) => InboxItem(
          id: d.id,
          itemType: InboxItemType.report,
          isRead: true,
          title: '[DRAFT] ${d.title}',
          createdAt: d.createdAt,
          reportType: d.type == DraftType.hazard ? ReportType.hazard : ReportType.inspection,
          description: d.data['description']?.toString() ?? d.data['kronologi']?.toString() ?? '',
          status: ReportStatus.open,
          location: d.data['location']?.toString() ?? '-',
          severity: _parseSeverity(d.data['severity']),
        )).toList();

    switch (_activeMyPostFilter) {
      case _MyPostFilter.all:
        final all = [...drafts, ..._myReports];
        all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return all;
      case _MyPostFilter.draft:
        return drafts;
      case _MyPostFilter.pending:
        return _myRawReports
            .where((r) => r.status == ReportStatus.open && r.subStatus == ReportSubStatus.validating)
            .map(_reportToInboxItem)
            .toList();
      case _MyPostFilter.approved:
        return _myRawReports
            .where((r) =>
                (r.status == ReportStatus.open && r.subStatus != ReportSubStatus.validating) ||
                r.status == ReportStatus.inProgress)
            .map(_reportToInboxItem)
            .toList();
      case _MyPostFilter.rejected:
        return _myRawReports
            .where((r) => r.subStatus == ReportSubStatus.rejected)
            .map(_reportToInboxItem)
            .toList();
    }
  }

  int _myPostFilterCount(_MyPostFilter f) {
    switch (f) {
      case _MyPostFilter.all:
        return _myDrafts.length + _myRawReports.length;
      case _MyPostFilter.draft:
        return _myDrafts.length;
      case _MyPostFilter.pending:
        return _myRawReports
            .where((r) => r.status == ReportStatus.open && r.subStatus == ReportSubStatus.validating)
            .length;
      case _MyPostFilter.approved:
        return _myRawReports
            .where((r) =>
                (r.status == ReportStatus.open && r.subStatus != ReportSubStatus.validating) ||
                r.status == ReportStatus.inProgress)
            .length;
      case _MyPostFilter.rejected:
        return _myRawReports.where((r) => r.subStatus == ReportSubStatus.rejected).length;
    }
  }

  ReportSeverity _parseSeverity(dynamic raw) {
    final s = raw?.toString().toLowerCase();
    if (s == 'low') return ReportSeverity.low;
    if (s == 'high') return ReportSeverity.high;
    if (s == 'critical') return ReportSeverity.critical;
    return ReportSeverity.medium;
  }

  int get _readAnnouncementCount =>
      _announcements.where((i) => i.isRead).length;

  int get _unreadReports => _personalReports.where((i) => !i.isRead).length;
  int get _unreadAnnouncements => _announcements.where((i) => !i.isRead).length;
  int get _unreadMyReports => _myReports.where((i) => !i.isRead).length;

  int get _aktifReportCount =>
      _personalReports.where((i) => i.status != ReportStatus.closed).length;
  int get _selesaiReportCount =>
      _personalReports.where((i) => i.status == ReportStatus.closed).length;

  // ── Mark-as-read (optimistic) ──────────────────────────────────────────────
  void _markItemRead(InboxItem item) {
    if (item.isRead) return;
    setState(() {
      item.isRead = true;
      // No manual count adjustment; counts are computed from lists.
    });

    // Fire-and-forget — rollback if it fails.
    final typeStr =
        item.itemType == InboxItemType.report ? 'report' : 'announcement';
    InboxService.markRead(itemId: item.id, itemType: typeStr).then((res) {
      if (!mounted) return;
      if (!res.success) {
        setState(() {
          item.isRead = false;
          // No manual count adjustment; counts are computed from lists.
        });
      }
    });
  }

  // ── Formatters & colors ────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _levelResiko(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return 'P3 - Low';
      case ReportSeverity.medium:
        return 'P2 - Medium';
      case ReportSeverity.high:
        return 'P1 - High';
      case ReportSeverity.critical:
        return 'P0 - Critical';
    }
  }

  Color _statusColor(ReportStatus s) {
    switch (s) {
      case ReportStatus.open:
        return const Color(0xFF2196F3); // Biru
      case ReportStatus.inProgress:
        return const Color(0xFF9C27B0); // Ungu
      case ReportStatus.closed:
        return const Color(0xFF757575); // Abu
    }
  }

  Color _severityColor(ReportSeverity s) {
    switch (s) {
      case ReportSeverity.low:
        return const Color(0xFF4CAF50); // Green
      case ReportSeverity.medium:
        return const Color(0xFFFF9800); // Orange
      case ReportSeverity.high:
        return const Color(0xFFF44336); // Red
      case ReportSeverity.critical:
        return const Color(0xFFB71C1C); // Dark Red
    }
  }

  String _statusLabel(ReportStatus s) {
    switch (s) {
      case ReportStatus.open:
        return 'Open';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.closed:
        return 'Closed';
    }
  }

  String _myPostFilterLabel(_MyPostFilter f) {
    switch (f) {
      case _MyPostFilter.all: return 'Semua Laporan';
      case _MyPostFilter.draft: return 'Draft';
      case _MyPostFilter.pending: return 'Pending Approval';
      case _MyPostFilter.approved: return 'Approved';
      case _MyPostFilter.rejected: return 'Rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF5F5F5),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Custom Header matching Profile design (Unified Container) ────
            Container(
              color: const Color(0xFFF8F8F8),
              child: Column(
                children: [
                  SapaHseHeader(
                    isSearching: _isSearching,
                    searchController: _searchController,
                    searchHint: 'Cari...',
                    onSearchChanged: _onSearchChanged,
                    onSearchToggle: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _searchQuery = '';
                          _loadReports();
                          _loadAnnouncements();
                        }
                      });
                    },
                  ),
                  TabBar(
                    controller: _mainTabController,
                    labelColor: const Color(0xFF1565C0),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF1565C0),
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 13),
                    tabs: [
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Pengumuman'),
                              if (_unreadAnnouncements > 0) ...[
                                const SizedBox(width: 6),
                                _TabBadge(count: _unreadAnnouncements),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Tugas'),
                              if (_isSuperAdmin && _pendingApprovalCount > 0) ...[
                                const SizedBox(width: 6),
                                _TabBadge(count: _pendingApprovalCount),
                              ] else if (!_isSuperAdmin && _unreadReports > 0) ...[
                                const SizedBox(width: 6),
                                _TabBadge(count: _unreadReports),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('MyPost'),
                              if (_unreadMyReports > 0) ...[
                                const SizedBox(width: 6),
                                _TabBadge(count: _unreadMyReports),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

              // ── Sub-filter: context-aware ────────────────────────────────────
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: _mainTabController.index == 2
                    ? _buildDropdownFilter<_MyPostFilter>(
                        value: _activeMyPostFilter,
                        values: _MyPostFilter.values,
                        label: _myPostFilterLabel,
                        count: _myPostFilterCount,
                        onChanged: (v) => setState(() => _activeMyPostFilter = v),
                      )
                    : (_mainTabController.index == 1 && _isSuperAdmin)
                        ? _buildDropdownFilter<_ApprovalFilter>(
                            value: _activeApprovalFilter,
                            values: _ApprovalFilter.values,
                            label: _approvalFilterLabel,
                            count: _approvalFilterCount,
                            onChanged: (v) => setState(() => _activeApprovalFilter = v),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _SubFilterChip(
                                  label: _mainTabController.index == 1 ? 'Aktif' : 'Unread',
                                  isActive: _activeFilter == _SubFilter.unread,
                                  badge: _mainTabController.index == 0
                                      ? (_unreadAnnouncements > 0
                                          ? _unreadAnnouncements
                                          : null)
                                      : (_aktifReportCount > 0 ? _aktifReportCount : null),
                                  onTap: () =>
                                      setState(() => _activeFilter = _SubFilter.unread),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _SubFilterChip(
                                  label: _mainTabController.index == 1 ? 'Selesai' : 'Read',
                                  isActive: _activeFilter == _SubFilter.read,
                                  badge: _mainTabController.index == 0
                                      ? (_readAnnouncementCount > 0
                                          ? _readAnnouncementCount
                                          : null)
                                      : (_selesaiReportCount > 0 ? _selesaiReportCount : null),
                                  onTap: () =>
                                      setState(() => _activeFilter = _SubFilter.read),
                                ),
                              ),
                            ],
                          ),
              ),

            // ── Tugas Butuh Tindakan Segera Banner ───────────────────────
            if (_mainTabController.index == 1 && !_isSuperAdmin)
              Builder(builder: (context) {
                final urgentCount = _personalReports.where((i) =>
                  i.status == ReportStatus.open && 
                  (i.severity == ReportSeverity.high || i.severity == ReportSeverity.critical)
                ).length;
                
                if (urgentCount == 0) return const SizedBox.shrink();
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: const Color(0xFFFFF4E5),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$urgentCount Tugas Butuh Tindakan Segera',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            // ── Pending approval banner for superadmin ───────────────────
            if (_mainTabController.index == 1 && _isSuperAdmin && _pendingApprovalCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                color: const Color(0xFFFFF8E1),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions, size: 18, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_pendingApprovalCount Permintaan Menunggu Persetujuan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Content (TabBarView for smooth animations) ───────────────
            Expanded(
              child: TabBarView(
                controller: _mainTabController,
                children: [
                  _buildAnnouncementsTab(),
                  _buildReportsTab(),
                  _buildMyReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_isSuperAdmin) {
      if (_loadingApprovals && _approvals.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: _loadApprovals,
        child: _buildApprovalList(_filteredApprovals),
      );
    }
    if (_loadingReports && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorReports != null && _reports.isEmpty) {
      return _buildErrorState(_errorReports!, _loadReports);
    }
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: _buildList(_activeReports, isAnnouncement: false),
    );
  }

  // ── Generic dropdown filter builder ────────────────────────────────────────
  Widget _buildDropdownFilter<T>({
    required T value,
    required List<T> values,
    required String Function(T) label,
    required int Function(T) count,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      children: [
        const Text(
          'Filter:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A56C4),
                ),
                items: values.map((f) {
                  final c = count(f);
                  return DropdownMenuItem<T>(
                    value: f,
                    child: Row(
                      children: [
                        Text(label(f)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$c',
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Approval list builder ──────────────────────────────────────────────────
  Widget _buildApprovalList(List<ApprovalItem> list) {
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 52, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'Tidak ada permintaan approval.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        return _ApprovalCard(
          item: item,
          formatDate: _formatDate,
          onTap: () => _showApprovalDetail(item),
          onApprove: item.status == ApprovalStatus.pending
              ? () async {
                  final typeStr = item.type == ApprovalType.registerUser ? 'register_user' : (item.type == ApprovalType.license ? 'license' : 'certification');
                  final success = await ApprovalService.approve(item.id, typeStr);
                  if (success) {
                    setState(() => item.status = ApprovalStatus.approved);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.title} telah disetujui'),
                          backgroundColor: const Color(0xFF4CAF50),
                        ),
                      );
                    }
                  }
                }
              : null,
          onReject: item.status == ApprovalStatus.pending
              ? () async {
                  final typeStr = item.type == ApprovalType.registerUser ? 'register_user' : (item.type == ApprovalType.license ? 'license' : 'certification');
                  final success = await ApprovalService.reject(item.id, typeStr);
                  if (success) {
                    setState(() => item.status = ApprovalStatus.rejected);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.title} telah ditolak'),
                          backgroundColor: const Color(0xFFF44336),
                        ),
                      );
                    }
                  }
                }
              : null,
        );
      },
    );
  }

  // ── Approval detail bottom sheet ───────────────────────────────────────────
  void _showApprovalDetail(ApprovalItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: sc,
                  children: [
                    // Type badge + title
                    Row(
                      children: [
                        _approvalTypeIcon(item.type),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.typeLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _approvalTypeColor(item.type))),
                              const SizedBox(height: 2),
                              Text(item.title,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _detailRow(Icons.person_outline, 'Pemohon', item.requesterName),
                    _detailRow(Icons.business, 'Departemen', item.department ?? '-'),
                    _detailRow(Icons.apartment, 'Perusahaan', item.company ?? '-'),
                    _detailRow(Icons.calendar_today_outlined, 'Tanggal', _formatDate(item.createdAt)),
                    _detailRow(Icons.description_outlined, 'Keterangan', item.subtitle),
                    // Extra metadata
                    ...item.metadata.entries.where((e) => e.key != 'reject_reason' && e.key != 'file_url').map((e) =>
                      _detailRow(Icons.info_outline, _metadataLabel(e.key), e.value.toString()),
                    ),
                    if (item.metadata['reject_reason'] != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 18, color: Color(0xFFF44336)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Alasan ditolak: ${item.metadata['reject_reason']}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFFC62828)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (item.metadata['file_url'] != null) ...[
                      const SizedBox(height: 16),
                      const Text('Lampiran Dokumen:', 
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.metadata['file_url'],
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, err, stack) => Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (item.status == ApprovalStatus.pending)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showRejectDialog(item, sheetCtx),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Tolak'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF44336),
                                side: const BorderSide(color: Color(0xFFF44336)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showApproveConfirmation(item, sheetCtx),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Setujui'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: item.status == ApprovalStatus.approved
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF3F3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.status == ApprovalStatus.approved
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 18,
                              color: item.status == ApprovalStatus.approved
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.statusLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: item.status == ApprovalStatus.approved
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showApproveConfirmation(ApprovalItem item, BuildContext sheetCtx) {
    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi', style: TextStyle(fontWeight: FontWeight.bold)),
          content: isProcessing 
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : Text('Apakah Anda yakin ingin menyetujui pengajuan "${item.title}" ini?'),
          actions: isProcessing ? [] : [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                setModalState(() => isProcessing = true);
                final typeStr = item.type == ApprovalType.registerUser ? 'register_user' : (item.type == ApprovalType.license ? 'license' : 'certification');
                final success = await ApprovalService.approve(item.id, typeStr);
                if (success) {
                  if (mounted) {
                    setState(() => item.status = ApprovalStatus.approved);
                    Navigator.pop(ctx);
                    Navigator.pop(sheetCtx);
                    _loadApprovals(); // Refresh list
                  }
                } else {
                  setModalState(() => isProcessing = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyetujui pengajuan.')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ya, Setujui'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(ApprovalItem item, BuildContext sheetCtx) {
    final reasonCtrl = TextEditingController();
    bool isProcessing = false;
    final isRegisterUser = item.type == ApprovalType.registerUser;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isRegisterUser ? 'Alasan Penolakan' : 'Konfirmasi Penolakan', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: isProcessing 
            ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isRegisterUser 
                      ? 'Berikan alasan mengapa pendaftaran ini ditolak. Alasan ini akan dikirimkan ke email user.'
                      : 'Apakah Anda yakin ingin menolak pengajuan "${item.title}" ini?',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  if (isRegisterUser) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Dokumen kurang jelas atau tidak sesuai.',
                        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ],
              ),
          actions: isProcessing ? [] : [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (isRegisterUser && reasonCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alasan penolakan tidak boleh kosong.'))
                  );
                  return;
                }
                setModalState(() => isProcessing = true);
                final typeStr = item.type == ApprovalType.registerUser ? 'register_user' : (item.type == ApprovalType.license ? 'license' : 'certification');
                final success = await ApprovalService.reject(item.id, typeStr, reason: isRegisterUser ? reasonCtrl.text : null);
                if (success) {
                  if (mounted) {
                    setState(() => item.status = ApprovalStatus.rejected);
                    Navigator.pop(ctx);
                    Navigator.pop(sheetCtx);
                    _loadApprovals(); // Refresh list
                  }
                } else {
                  setModalState(() => isProcessing = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menolak pengajuan.')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF44336),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isRegisterUser ? 'Tolak & Kirim' : 'Ya, Tolak'),
            ),
          ],
        ),
      ),
    );
  }

  String _metadataLabel(String key) {
    switch (key) {
      case 'email': return 'Email';
      case 'employee_id': return 'NIP';
      case 'position': return 'Jabatan';
      case 'license_number': return 'No. Lisensi';
      case 'cert_number': return 'No. Sertifikat';
      case 'issuer': return 'Penerbit';
      case 'expired_at': return 'Masa Berlaku';
      default: return key.replaceAll('_', ' ');
    }
  }

  Widget _approvalTypeIcon(ApprovalType type) {
    IconData icon;
    Color color;
    switch (type) {
      case ApprovalType.registerUser:
        icon = Icons.person_add_outlined;
        color = const Color(0xFF1565C0);
        break;
      case ApprovalType.license:
        icon = Icons.badge_outlined;
        color = const Color(0xFFE65100);
        break;
      case ApprovalType.certification:
        icon = Icons.workspace_premium_outlined;
        color = const Color(0xFF6A1B9A);
        break;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _approvalTypeColor(ApprovalType type) {
    switch (type) {
      case ApprovalType.registerUser: return const Color(0xFF1565C0);
      case ApprovalType.license: return const Color(0xFFE65100);
      case ApprovalType.certification: return const Color(0xFF6A1B9A);
    }
  }

  Widget _buildAnnouncementsTab() {
    if (_loadingAnnouncements && _announcements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorAnnouncements != null && _announcements.isEmpty) {
      return _buildErrorState(_errorAnnouncements!, _loadAnnouncements);
    }
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: _buildList(_activeAnnouncements, isAnnouncement: true),
    );
  }

  Widget _buildMyReportsTab() {
    if (_loadingMyReports && _myRawReports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMyReports != null && _myRawReports.isEmpty) {
      return _buildErrorState(_errorMyReports!, _loadMyReports);
    }
    return RefreshIndicator(
      onRefresh: _loadMyReports,
      child: _buildList(_activeMyReports, isAnnouncement: false),
    );
  }

  Widget _buildList(List<InboxItem> list, {required bool isAnnouncement}) {
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _activeFilter == _SubFilter.unread
                        ? Icons.mark_email_read_outlined
                        : Icons.drafts_outlined,
                    size: 52,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _mainTabController.index == 2
                      ? 'Tidak ada laporan dengan status ini.'
                      : (_activeFilter == _SubFilter.unread
                          ? (_mainTabController.index == 1 ? 'Tidak ada tugas aktif!' : 'Semua sudah dibaca!')
                          : (_mainTabController.index == 1 ? 'Tidak ada tugas selesai.' : 'Belum ada yang dibaca.')),
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final item = list[i];
        if (isAnnouncement) {
          return _AnnouncementCard(
            item: item,
            formatDate: _formatDate,
            onTap: () {
              _markItemRead(item);
              _showAnnouncementDetail(context, item);
            },
          );
        }
        return _InboxCard(
          item: item,
          formatDate: _formatDate,
          levelResiko: _levelResiko,
          statusColor: _statusColor,
          statusLabel: _statusLabel,
          severityColor: _severityColor,
          onDetail: () {
            _markItemRead(item);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(report: item.toReport()),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState(String message, Future<void> Function() onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDetail(BuildContext context, InboxItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: sc,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1A56C4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.campaign,
                              color: Color(0xFF1A56C4), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.fromName ?? 'Admin',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF1A56C4))),
                              Text(_formatDate(item.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(item.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            height: 1.3)),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(item.body ?? '',
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87, height: 1.6)),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── TAB BADGE Widget ─────────────────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  const _TabBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── SUB FILTER CHIP (Unread | Read) ──────────────────────────────────────────
class _SubFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final int? badge;
  final VoidCallback onTap;

  const _SubFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A56C4);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? blue.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? blue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? blue : Colors.black54,
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? blue : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class _InboxCard extends StatelessWidget {
  final InboxItem item;
  final String Function(DateTime) formatDate;
  final String Function(ReportSeverity) levelResiko;
  final Color Function(ReportStatus) statusColor;
  final String Function(ReportStatus) statusLabel;
  final Color Function(ReportSeverity) severityColor;
  final VoidCallback onDetail;

  const _InboxCard({
    required this.item,
    required this.formatDate,
    required this.levelResiko,
    required this.statusColor,
    required this.statusLabel,
    required this.severityColor,
    required this.onDetail,
  });

  Color get _typeColor {
    switch (item.reportType) {
      case ReportType.hazard:
        return const Color(0xFFF44336);
      case ReportType.inspection:
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF757575);
    }
  }

  String get _typeLabel {
    switch (item.reportType) {
      case ReportType.hazard:
        return 'HAZARD';
      case ReportType.inspection:
        return 'INSPECTION';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRead = item.isRead;
    final ReportStatus status = item.status ?? ReportStatus.open;
    final ReportSeverity severity = item.severity ?? ReportSeverity.medium;
    final String imageUrl = item.imageUrl ?? '';

    return GestureDetector(
      onTap: onDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? Colors.grey.shade200
                : const Color(0xFF1A56C4).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              SizedBox(
                height: 135,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── LEFT SIDE: Image + Category ──────────────────────────
                    Container(
                      width: 110,
                      color: Colors.grey.shade50,
                      child: Column(
                        children: [
                          Expanded(
                            child: imageUrl.isEmpty
                                ? Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.image_outlined,
                                        color: Colors.grey),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_outlined,
                                          color: Colors.grey),
                                    ),
                                  ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            color: _typeColor,
                            child: Text(
                              _typeLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── RIGHT SIDE: Details ──────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isRead ? FontWeight.w600 : FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                item.description ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Date & Location
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(formatDate(item.createdAt),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on_outlined,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(item.location ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey))),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Status & Priority
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor(status)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: statusColor(status)
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    statusLabel(status),
                                    style: TextStyle(
                                        color: statusColor(status),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: severityColor(severity),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    levelResiko(severity),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── BOTTOM: Warning Banner if Open ───────────────────────────
              if (status == ReportStatus.open &&
                  (severity == ReportSeverity.high))
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    border:
                        Border(top: BorderSide(color: Colors.orange.shade100)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.orange.shade900),
                      const SizedBox(width: 8),
                      Text(
                        'BUTUH TINDAKAN SEGERA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ANNOUNCEMENT CARD ────────────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final InboxItem item;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.item,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRead = item.isRead;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFFFAFAFA) : const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(14),
          border: isRead
              ? null
              : Border.all(
                  color: const Color(0xFF1A56C4).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Column(
            children: [
              if (!isRead)
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A56C4),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56C4).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.campaign,
                          color: Color(0xFF1A56C4), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!isRead)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin:
                                      const EdgeInsets.only(right: 6, top: 2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A56C4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.body ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(formatDate(item.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              const SizedBox(width: 12),
                              const Icon(Icons.person_outline,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(item.fromName ?? 'Admin',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── APPROVAL CARD ─────────────────────────────────────────────────────────────
class _ApprovalCard extends StatelessWidget {
  final ApprovalItem item;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ApprovalCard({
    required this.item,
    required this.formatDate,
    required this.onTap,
    this.onApprove,
    this.onReject,
  });

  Color get _typeColor {
    switch (item.type) {
      case ApprovalType.registerUser:
        return const Color(0xFF1565C0);
      case ApprovalType.license:
        return const Color(0xFFE65100);
      case ApprovalType.certification:
        return const Color(0xFF6A1B9A);
    }
  }

  IconData get _typeIcon {
    switch (item.type) {
      case ApprovalType.registerUser:
        return Icons.person_add_outlined;
      case ApprovalType.license:
        return Icons.badge_outlined;
      case ApprovalType.certification:
        return Icons.workspace_premium_outlined;
    }
  }

  Color get _statusColor {
    switch (item.status) {
      case ApprovalStatus.pending:
        return const Color(0xFFFF9800);
      case ApprovalStatus.approved:
        return const Color(0xFF4CAF50);
      case ApprovalStatus.rejected:
        return const Color(0xFFF44336);
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case ApprovalStatus.pending:
        return Icons.schedule;
      case ApprovalStatus.approved:
        return Icons.check_circle;
      case ApprovalStatus.rejected:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = item.status == ApprovalStatus.pending;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isPending ? const Color(0xFFFFFDE7) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? _typeColor.withValues(alpha: 0.3)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Top color accent
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: _typeColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + type + status badge
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_typeIcon, color: _typeColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.typeLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _typeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon, size: 12, color: _statusColor),
                            const SizedBox(width: 4),
                            Text(
                              item.statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Meta row: requester + date
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.requesterName} • ${item.department ?? "-"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        formatDate(item.createdAt),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),

                  // Quick action buttons (only for pending)
                  if (isPending) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onReject,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Tolak',
                                style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF44336),
                              side: const BorderSide(color: Color(0xFFF44336)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Setujui',
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
