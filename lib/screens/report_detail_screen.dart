import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/report.dart';
import '../data/report_store.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  final bool isDialog;
  const ReportDetailScreen(
      {super.key, required this.report, this.isDialog = false});

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

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Colors ─────────────────────────────────────────────────────────────────
  Color _severityColor(ReportSeverity s) => switch (s) {
        ReportSeverity.low => const Color(0xFF4CAF50),
        ReportSeverity.medium => const Color(0xFFFF9800),
        ReportSeverity.high => const Color(0xFFF44336),
        ReportSeverity.critical => const Color(0xFF880E4F),
      };

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.open => const Color(0xFF2196F3), // Biru
        ReportStatus.inProgress => const Color(0xFF9C27B0), // Ungu
        ReportStatus.closed => const Color(0xFF757575), // Abu
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

  // ── Update Status logic replaced by UpdateStatusPage ───────────────────────

  // ── Image Preview ──────────────────────────────────────────────────────────
  void _showImagePreview(BuildContext context, String imageUrl, int index) {
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
              child: index == 0
                  ? Hero(
                      tag: 'report_image_${_report.id}',
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const CircularProgressIndicator(
                            color: Colors.white),
                        errorWidget: (_, __, ___) => const Icon(Icons.image,
                            color: Colors.white54, size: 80),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
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
    );
  }

  void _showUpdateStatusModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UpdateStatusSheet(
        report: _report,
        onUpdate: (updatedReport) {
          setState(() => _report = updatedReport);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ReportStore.instance.getTimeline(_report.id);

    final List<String> exampleImages = [
      _report.imageUrl,
      'https://images.unsplash.com/photo-1541888081696-2616238b9d75?q=80&w=800&auto=format&fit=crop'
    ];

    return Scaffold(
      backgroundColor: widget.isDialog ? Colors.white : const Color(0xFFF0F0F0),
      appBar: widget.isDialog
          ? null
          : AppBar(
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
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (idx) =>
                      setState(() => _currentImageIndex = idx),
                  itemCount: exampleImages.length,
                  itemBuilder: (context, index) {
                    final imgUrl = exampleImages[index];
                    return GestureDetector(
                      onTap: () => _showImagePreview(context, imgUrl, index),
                      child: index == 0
                          ? Hero(
                              tag: 'report_image_${_report.id}',
                              child: CachedNetworkImage(
                                imageUrl: imgUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFF37474F),
                                  child: const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white38,
                                          strokeWidth: 2)),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFF37474F),
                                  child: const Icon(Icons.image,
                                      color: Colors.white24, size: 80),
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: imgUrl,
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
                    );
                  },
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
                    _badge(_report.status.label, _statusColor(_report.status)),
                    const SizedBox(width: 8),
                    _badge(_report.severity.label,
                        _severityColor(_report.severity)),
                  ]),
                ),
                if (exampleImages.length > 1) ...[
                  Positioned(
                    bottom: 12,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${exampleImages.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                          onPressed: () {
                            if (_currentImageIndex > 0) {
                              _pageController.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_forward_ios,
                              color: Colors.white, size: 18),
                          onPressed: () {
                            if (_currentImageIndex < exampleImages.length - 1) {
                              _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
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
                    if (_report.saran != null && _report.saran!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.lightbulb_outline,
                          label: 'Saran Perbaikan',
                          value: _report.saran!),
                    ],
                  ]),
            ),

            // ── Info card (Detail Lanjutan) ────────────────────────────────
            _card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                        icon: Icons.category_outlined,
                        label: 'Kategori',
                        value: _report.category?.label ?? _report.type.label),
                    if (_report.subkategori != null &&
                        _report.subkategori!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.subdirectory_arrow_right,
                          label: 'Subkategori',
                          value: _report.subkategori!),
                    ],
                    const SizedBox(height: 12),
                    _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Lokasi Kejadian',
                        value: _report.location),
                    if (_report.kejadianLocation != null &&
                        _report.kejadianLocation!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.place_outlined,
                        label: 'Koordinat Kejadian',
                        value: _report.kejadianLocation!,
                        onTap: () async {
                          final coords = _report.kejadianLocation!.split(',');
                          if (coords.length != 2) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Format koordinat tidak valid')),
                              );
                            }
                            return;
                          }

                          final lat = double.tryParse(coords[0].trim());
                          final lng = double.tryParse(coords[1].trim());

                          if (lat == null || lng == null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Format koordinat tidak valid')),
                              );
                            }
                            return;
                          }

                          // Google Maps URL is more reliable across platforms
                          final googleMapsUrl = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          final appleMapsUrl =
                              Uri.parse('apple:0,0?q=$lat,$lng');

                          if (await canLaunchUrl(googleMapsUrl)) {
                            await launchUrl(googleMapsUrl,
                                mode: LaunchMode.externalApplication);
                          } else if (!kIsWeb &&
                              Platform.isIOS &&
                              await canLaunchUrl(appleMapsUrl)) {
                            await launchUrl(appleMapsUrl);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Tidak dapat membuka aplikasi peta')),
                              );
                            }
                          }
                        },
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF4FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.map_outlined,
                              color: Color(0xFF1A56C4), size: 18),
                        ),
                      ),
                    ],
                    if (_report.perusahaan != null &&
                        _report.perusahaan!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.business_outlined,
                          label: 'Perusahaan',
                          value: _report.perusahaan!),
                    ],
                    if (_report.departemen != null &&
                        _report.departemen!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.apartment_outlined,
                          label: 'Departemen',
                          value: _report.departemen!),
                    ],
                    if (_report.tagOrang != null &&
                        _report.tagOrang!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _DetailRow(
                          icon: Icons.manage_accounts_outlined,
                          label: 'PJA (Penanggung Jawab Area)',
                          value: _report.tagOrang!),
                    ],
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
                        icon: Icons.confirmation_number_outlined,
                        label: 'No. Tiket',
                        value: '#TKT-${_report.id.padLeft(4, '0')}'),
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
                  onPressed: () => _showUpdateStatusModal(),
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
    final statuses = [
      ReportStatus.open,
      ReportStatus.inProgress,
      ReportStatus.closed
    ];

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
                color: isCurrentGroup
                    ? statusColor
                    : statusColor.withValues(alpha: 0.1),
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
                    height: 1, color: statusColor.withValues(alpha: 0.2))),
          ]),
        ),
      );

      // Sub-events under this group
      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final isLastInGroup = i == events.length - 1;
        final isVeryLast = status == (_report.status) && isLastInGroup;

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
                    color: isCurrent
                        ? statusColor
                        : statusColor.withValues(alpha: 0.12),
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
                              color: const Color(0xFF1A56C4)
                                  .withValues(alpha: 0.3)),
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
                                iconTheme:
                                    const IconThemeData(color: Colors.white),
                                elevation: 0,
                              ),
                              extendBodyBehindAppBar: true,
                              body: Center(
                                child: InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 4.0,
                                  child: kIsWeb
                                      ? Image.network(
                                          event.photoPath!,
                                          fit: BoxFit.contain,
                                        )
                                      : Image.file(
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
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1A56C4).withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// UPDATE STATUS MODAL (COMPACT)
// ══════════════════════════════════════════════════════════════════════════════

class _UpdateStatusSheet extends StatefulWidget {
  final Report report;
  final Function(Report) onUpdate;

  const _UpdateStatusSheet({required this.report, required this.onUpdate});

  @override
  State<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<_UpdateStatusSheet> {
  late ReportStatus _selectedStatus;
  ReportSubStatus? _selectedSub;
  final _noteCtrl = TextEditingController();
  final Set<String> _taggedItems = {}; // Combined Dept & PJA
  XFile? _attachedPhoto;
  bool _isSaving = false;

  final _blue = const Color(0xFF1A56C4);
  final _purple = const Color(0xFF9C27B0);
  final _grey = const Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _selectedSub = widget.report.subStatus;
    if (widget.report.departemen != null) _taggedItems.add(widget.report.departemen!);
    if (widget.report.tagOrang != null) {
      _taggedItems.addAll(widget.report.tagOrang!.split(', ').where((s) => s.isNotEmpty));
    }
  }

  void _showUnifiedPicker() {
    final allOptions = [
      'Departemen HSE',
      'Departemen Produksi',
      'Departemen Maintenance',
      'Departemen Engineering',
      'Departemen HRD',
      'Departemen Logistik',
      'Departemen Security',
      'Budi Santoso (PJA)',
      'Ahmad Fauzi (PJA)',
      'Riko Pratama (PJA)',
      'Hendra Wijaya (PJA)',
      'Siti Rahayu (PJA)',
      'Dian Permata (PJA)',
      'Eko Susilo (PJA)',
    ];

    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = allOptions
              .where((o) => o.toLowerCase().contains(query.toLowerCase()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Tag Departemen / PJA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari departemen atau nama...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final opt = filtered[i];
                      final isSelected = _taggedItems.contains(opt);
                      return ListTile(
                        title: Text(opt, style: const TextStyle(fontSize: 14)),
                        trailing: Icon(isSelected ? Icons.check_circle : Icons.add_circle_outline, color: isSelected ? _blue : Colors.grey),
                        onTap: () {
                          setState(() {
                            if (isSelected) _taggedItems.remove(opt);
                            else _taggedItems.add(opt);
                          });
                          setSheetState(() {});
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_selectedSub == ReportSubStatus.reviewing && _attachedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto bukti wajib dilampirkan!')));
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 600));

    // Process combined tags
    final deptList = _taggedItems.where((t) => t.startsWith('Departemen')).map((t) => t.replaceFirst('Departemen ', '')).toList();
    final pjaList = _taggedItems.where((t) => t.endsWith('(PJA)')).map((t) => t.replaceFirst(' (PJA)', '')).toList();

    String? finalNote = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    
    final updated = ReportStore.instance.updateStatus(
      widget.report.id,
      _selectedStatus,
      newSubStatus: _selectedSub,
      actor: 'Noor Lintang Bhaskara',
      note: finalNote,
      photoPath: _attachedPhoto?.path,
    );

    if (mounted) {
      widget.onUpdate(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Status berhasil diperbarui ke ${_selectedStatus.label}'),
        backgroundColor: _selectedStatus == ReportStatus.open ? _blue : (_selectedStatus == ReportStatus.inProgress ? _purple : _grey),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 12,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Perbarui Status Laporan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: _blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('STATUS SAAT INI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.report.status.label}${widget.report.subStatus != null ? ' → ${widget.report.subStatus!.label}' : ''}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _blue),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('STATUS UTAMA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusBtn(label: 'Open', color: _blue, isSelected: _selectedStatus == ReportStatus.open, onTap: () => setState(() { _selectedStatus = ReportStatus.open; _selectedSub = null; })),
                const SizedBox(width: 10),
                _StatusBtn(label: 'In Progress', color: _purple, isSelected: _selectedStatus == ReportStatus.inProgress, onTap: () => setState(() { _selectedStatus = ReportStatus.inProgress; _selectedSub = null; })),
                const SizedBox(width: 10),
                _StatusBtn(label: 'Closed', color: _grey, isSelected: _selectedStatus == ReportStatus.closed, onTap: () => setState(() { _selectedStatus = ReportStatus.closed; _selectedSub = null; })),
              ],
            ),
            const SizedBox(height: 24),

            const Text('SUB-STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: ReportSubStatusInfo.forStatus(_selectedStatus).map((sub) {
                final isSelected = _selectedSub == sub;
                final color = isSelected ? (_selectedStatus == ReportStatus.open ? _blue : (_selectedStatus == ReportStatus.inProgress ? _purple : _grey)) : Colors.grey.shade400;
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 66) / 3, // 3 equal columns
                  child: ChoiceChip(
                    label: Center(
                      child: Text(sub.label, 
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _selectedSub = val ? sub : null),
                    selectedColor: color,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? color : Colors.grey.shade300)),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            if (_selectedSub == ReportSubStatus.assigned || _selectedSub == ReportSubStatus.deferred) ...[
              const Text('🏷️ TAG DEPARTEMEN / PJA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _showUnifiedPicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_add_outlined, size: 20, color: Colors.grey),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Ketuk untuk tag orang atau departemen',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                          ],
                        ),
                      ),
                      if (_taggedItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _taggedItems.map((item) => Chip(
                            label: Text(item, style: const TextStyle(fontSize: 11)),
                            onDeleted: () => setState(() => _taggedItems.remove(item)),
                            backgroundColor: _blue.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📸 PHOTO EVIDENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                if (_selectedSub == ReportSubStatus.reviewing)
                  const Text('* WAJIB UNTUK REVIEWING', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) setState(() => _attachedPhoto = picked);
              },
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: CustomPaint(
                  painter: _DashedRectPainter(color: Colors.grey.shade300),
                  child: Center(
                    child: _attachedPhoto != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_attachedPhoto!.path), height: 60, width: 60, fit: BoxFit.cover))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt, size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text('Tambah foto bukti penyelesaian', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          ],
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Notes for reviewer...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _StatusBtn({required this.label, required this.color, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: isSelected ? 2 : 1),
          ),
          child: Center(
            child: Text(label, style: TextStyle(color: isSelected ? color : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  _DashedRectPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    const double dashWidth = 5, dashSpace = 5;
    final Path path = Path();
    for (double i = 0; i < size.width; i += dashWidth + dashSpace) { path.moveTo(i, 0); path.lineTo(i + dashWidth, 0); }
    for (double i = 0; i < size.height; i += dashWidth + dashSpace) { path.moveTo(size.width, i); path.lineTo(size.width, i + dashWidth); }
    for (double i = size.width; i > 0; i -= dashWidth + dashSpace) { path.moveTo(i, size.height); path.lineTo(i - dashWidth, size.height); }
    for (double i = size.height; i > 0; i -= dashWidth + dashSpace) { path.moveTo(0, i); path.lineTo(0, i - dashWidth); }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54));
  }
}

