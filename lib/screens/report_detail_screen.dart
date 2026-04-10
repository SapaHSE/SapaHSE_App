import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report.dart';
import '../data/report_store.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Report _report;

  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);

  @override
  void initState() {
    super.initState();
    _report = ReportStore.instance.getById(widget.report.id) ?? widget.report;
  }

  // ── Colors ─────────────────────────────────────────────────────────────────
  Color _severityColor(ReportSeverity s) => switch (s) {
        ReportSeverity.low => const Color(0xFF4CAF50),
        ReportSeverity.medium => const Color(0xFFFF9800),
        ReportSeverity.high => const Color(0xFFF44336),
      };

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.open       => const Color(0xFF2196F3), // Biru
        ReportStatus.inProgress => const Color(0xFF9C27B0), // Ungu
        ReportStatus.closed     => const Color(0xFF757575), // Abu
      };

  IconData _statusIcon(ReportStatus s) => switch (s) {
        ReportStatus.open => Icons.flag_outlined,
        ReportStatus.inProgress => Icons.autorenew,
        ReportStatus.closed => Icons.check_circle_outline,
      };

  String _formatDate(DateTime dt) {
    final m = [
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
      'Des'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateShort(DateTime dt) {
    final m = [
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
      'Des'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  // ── Update status ──────────────────────────────────────────────────────────
  void _showUpdateStatusDialog() {
    ReportStatus? selectedStatus = _report.status;
    ReportSubStatus? selectedSub = _report.subStatus;
    final noteCtrl = TextEditingController();
    File? attachedPhoto;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Update Status Laporan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Pilih Status Utama ──────────────────────────────────
                const Text('Status Utama',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey)),
                const SizedBox(height: 8),
                ...ReportStatus.values.map((s) {
                  final color = _statusColor(s);
                  final isSelected = selectedStatus == s;
                  return GestureDetector(
                    onTap: () => setDs(() {
                      selectedStatus = s;
                      selectedSub = null; // reset sub saat status berubah
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(s.label,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? color : Colors.black87,
                              fontSize: 14,
                            )),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle, color: color, size: 18),
                      ]),
                    ),
                  );
                }),

                // ── Pilih Sub-Status ───────────────────────────────────
                if (selectedStatus != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text('Sub-Status (${selectedStatus!.label})',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReportSubStatusInfo.forStatus(selectedStatus!)
                        .map((sub) {
                      final color = _statusColor(selectedStatus!);
                      final isSubSelected = selectedSub == sub;
                      return GestureDetector(
                        onTap: () => setDs(() => selectedSub = sub),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSubSelected
                                ? color
                                : color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSubSelected
                                  ? color
                                  : color.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            sub.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSubSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSubSelected ? Colors.white : color,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text('Catatan (opsional)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Tambahkan keterangan perubahan...',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _blue)),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lampirkan Foto',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    if (selectedSub == ReportSubStatus.reviewing)
                      const Text('* Wajib', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                    if (selectedSub != ReportSubStatus.reviewing)
                      const Text('(opsional)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) {
                      setDs(() => attachedPhoto = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: attachedPhoto != null
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(attachedPhoto!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 24),
                              SizedBox(height: 8),
                              Text('Tap untuk unggah foto', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal',
                    style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                if (selectedStatus == null) return;
                
                if (selectedSub == ReportSubStatus.reviewing && attachedPhoto == null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Foto bukti wajib dilampirkan untuk tahap Reviewing!'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                  return;
                }

                final note = noteCtrl.text.trim().isEmpty
                    ? null
                    : noteCtrl.text.trim();
                final updated = ReportStore.instance.updateStatus(
                  _report.id,
                  selectedStatus!,
                  newSubStatus: selectedSub,
                  actor: 'Noor Lintang Bhaskara',
                  note: note,
                  photoPath: attachedPhoto?.path,
                );
                setState(() => _report = updated);
                Navigator.pop(ctx);
                final label = selectedSub != null
                    ? '${selectedStatus!.label} · ${selectedSub!.label}'
                    : selectedStatus!.label;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Status diubah ke "$label"')),
                  ]),
                  backgroundColor: _statusColor(selectedStatus!),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image Preview ──────────────────────────────────────────────────────────
  void _showImagePreview(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Hero(
                tag: 'report_image_${_report.id}',
                child: CachedNetworkImage(
                  imageUrl: _report.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) => const Icon(Icons.image,
                      color: Colors.white54, size: 80),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ReportStore.instance.getTimeline(_report.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detail Laporan',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(fit: StackFit.expand, children: [
                GestureDetector(
                  onTap: () => _showImagePreview(context),
                  child: Hero(
                    tag: 'report_image_${_report.id}',
                    child: CachedNetworkImage(
                      imageUrl: _report.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF37474F),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white38, strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF37474F),
                        child: const Icon(Icons.image,
                            color: Colors.white24, size: 80),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.65),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  child: Row(children: [
                    _badge(_report.severity.label,
                        _severityColor(_report.severity)),
                    const SizedBox(width: 8),
                    _badge(_report.status.label, _statusColor(_report.status)),
                  ]),
                ),
              ]),
            ),

            // ── Info card ──────────────────────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_report.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_report.type.label,
                        style: const TextStyle(
                            fontSize: 13,
                            color: _blue,
                            fontWeight: FontWeight.w500)),
                    const Divider(height: 24),
                    _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Deskripsi',
                        value: _report.description),
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Lokasi',
                        value: _report.location),
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Dilaporkan oleh',
                        value: _report.reportedBy),
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.access_time,
                        label: 'Waktu Laporan',
                        value: _formatDate(_report.createdAt)),
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Kategori',
                        value: _report.category?.label ?? _report.type.label),
                  ]),
            ),

            // ── Progress Timeline ──────────────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(children: [
                      const Icon(Icons.timeline, color: _blue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Progress Laporan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _blueLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${timeline.length} aktivitas',
                            style: const TextStyle(
                                fontSize: 11,
                                color: _blue,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),

                    // Step indicator bar
                    _buildStepBar(),

                    const SizedBox(height: 20),

                    // Timeline events (grouped by parent status)
                    ..._buildGroupedTimeline(timeline),
                  ]),
            ),

            // ── Action buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showUpdateStatusDialog,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Update Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build grouped timeline ──────────────────────────────────────────────────
  List<Widget> _buildGroupedTimeline(List<TimelineEvent> timeline) {
    final groups = <ReportStatus, List<TimelineEvent>>{};
    for (final e in timeline) {
      groups.putIfAbsent(e.status, () => []).add(e);
    }

    final result = <Widget>[];
    final statuses = [ReportStatus.open, ReportStatus.inProgress, ReportStatus.closed];

    for (final status in statuses) {
      final events = groups[status];
      if (events == null) continue;

      final statusColor = _statusColor(status);
      final isCurrentGroup = _report.status == status;

      // Group header
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentGroup ? statusColor : statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_statusIcon(status),
                    size: 12,
                    color: isCurrentGroup ? Colors.white : statusColor),
                const SizedBox(width: 5),
                Text(status.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isCurrentGroup ? Colors.white : statusColor)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Container(
                    height: 1,
                    color: statusColor.withValues(alpha: 0.2))),
          ]),
        ),
      );

      // Sub-events under this group
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final isLastInGroup = i == events.length - 1;
        final isVeryLast =
            status == (_report.status) && isLastInGroup;

        result.add(
          _TimelineItem(
            event: event,
            isLast: isLastInGroup,
            isCurrent: isVeryLast,
            statusColor: statusColor,
            statusIcon: _statusIcon(status),
            formatDate: _formatDate,
            formatShort: _formatDateShort,
          ),
        );
      }

      result.add(const SizedBox(height: 4));
    }

    return result;
  }

  // ── Step bar (Open → In Progress → Closed) ─────────────────────────────────
  Widget _buildStepBar() {
    final steps = [
      ReportStatus.open,
      ReportStatus.inProgress,
      ReportStatus.closed
    ];
    final timeline = ReportStore.instance.getTimeline(_report.id);
    final reached = timeline.map((e) => e.status).toSet();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final leftStep = steps[i ~/ 2];
          final rightStep = steps[i ~/ 2 + 1];
          final active =
              reached.contains(leftStep) && reached.contains(rightStep);
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 17),
              height: 3,
              decoration: BoxDecoration(
                color: active ? _blue : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        // Step circle
        final step = steps[i ~/ 2];
        final isDone = reached.contains(step);
        final isCur = _report.status == step;
        final color = _statusColor(step);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isDone ? color : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? color : Colors.grey.shade300,
                  width: isCur ? 3 : 1.5,
                ),
                boxShadow: isCur
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
              child: Icon(
                _statusIcon(step),
                size: 16,
                color: isDone ? Colors.white : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                color: isDone ? color : Colors.grey,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _card({required Widget child, EdgeInsets margin = EdgeInsets.zero}) =>
      Container(
        margin: margin,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );
}

// ── Timeline item ─────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  final TimelineEvent event;
  final bool isLast;
  final bool isCurrent;
  final Color statusColor;
  final IconData statusIcon;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatShort;

  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.isCurrent,
    required this.statusColor,
    required this.statusIcon,
    required this.formatDate,
    required this.formatShort,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left column: dot + line ──────────────────────────────────
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        isCurrent ? statusColor : statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: isCurrent ? 2.5 : 1.5,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                                color: statusColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 1)
                          ]
                        : null,
                  ),
                  child: Icon(statusIcon,
                      size: 16, color: isCurrent ? Colors.white : statusColor),
                ),
                // Vertical line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Right column: content ────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sub-status label + "TERKINI" badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? statusColor
                            : statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        event.subStatus?.label ?? event.status.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : statusColor,
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF1A56C4).withValues(alpha: 0.3)),
                        ),
                        child: const Text('TERKINI',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A56C4),
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 6),

                  // Actor + timestamp
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(event.actor,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(formatDate(event.timestamp),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ]),

                  // Note
                  if (event.note != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(event.note!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.4)),
                    ),
                  ],
                  // Photo
                  if (event.photoPath != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: Colors.black,
                              appBar: AppBar(
                                backgroundColor: Colors.transparent,
                                iconTheme: const IconThemeData(color: Colors.white),
                                elevation: 0,
                              ),
                              extendBodyBehindAppBar: true,
                              body: Center(
                                child: InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 4.0,
                                  child: Image.file(
                                    File(event.photoPath!),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(event.photoPath!)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      );
}

