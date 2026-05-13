import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../models/report.dart';
import '../data/news_data.dart';
import '../services/news_service.dart';
import 'report_detail_screen.dart';
import 'news_detail_screen.dart';
import '../data/report_store.dart';
import '../widgets/sapa_hse_header.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/storage_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _carouselTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedType = 'All Report';
  String _statusFilter = 'Aktif';

  int _displayedCount = 25;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // ── Featured News & Announcements Carousel ───────────────────────────────
  List<dynamic> _carouselItems = []; // Can hold NewsArticle or Announcement

  // ── Only Hazard & Inspection ──────────────────────────────────────────────
  final List<String> _reportTypes = [
    'All Report',
    'Hazard',
    'Inspection',
  ];

  List<Report> _filteredReportsCache = [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Initial filter calculation
    _updateFilteredCache();
    
    // Listen to changes in ReportStore to update cache
    ReportStore.instance.reports.addListener(_updateFilteredCache);

    // Listen to announcement changes to reload carousel
    AnnouncementService.refreshNotifier.addListener(_loadCarouselData);

    // STAGGERED LOADING: Give the engine time to render the first frames
    // before starting heavy data tasks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _loadCarouselData();
        }
      });
    });
  }

  void _updateFilteredCache() {
    if (!mounted) return;
    setState(() {
      _filteredReportsCache = _getFilteredReports(ReportStore.instance.reports.value);
    });
  }

  Future<void> _loadCarouselData() async {
    // Load News
    final newsResult = await NewsService.getNews();
    
    // Load Announcements
    final announcements = await AnnouncementService.getAnnouncements();

    if (!mounted) return;

    setState(() {
      _carouselItems = [];
      
      // Add all news
      if (newsResult.success) {
        _carouselItems.addAll(newsResult.articles);
      }
      
      // Add announcements
      _carouselItems.addAll(announcements);

      // Sort by date (latest first)
      _carouselItems.sort((a, b) {
        DateTime parseDate(dynamic item) {
          if (item is NewsArticle) {
            // Try ISO first
            DateTime? d = DateTime.tryParse(item.date);
            if (d != null) return d;
            // Try "13 May 2026" format
            try {
              return DateFormat('dd MMM yyyy').parse(item.date);
            } catch (_) {
              return DateTime(2000); // Fallback to old date if unparseable
            }
          } else {
            return (item as Announcement).createdAt;
          }
        }

        return parseDate(b).compareTo(parseDate(a));
      });

      // LIMIT TO 3 ITEMS
      if (_carouselItems.length > 3) {
        _carouselItems = _carouselItems.sublist(0, 3);
      }
    });

    // Check for urgent announcement popup
    _checkUrgentAnnouncement(announcements);

    if (_carouselItems.isNotEmpty) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _startCarousel();
      });
    }
  }

  Future<void> _checkUrgentAnnouncement(List<Announcement> announcements) async {
    final urgent = announcements.where((a) => a.isUrgent).toList();
    if (urgent.isNotEmpty) {
      // Filter out already read ones
      for (final a in urgent) {
        final alreadyRead = await StorageService.isAnnouncementRead(a.id);
        if (!alreadyRead) {
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUrgentPopup(a);
          });
          break; // Show only one at a time
        }
      }
    }
  }

  void _showUrgentPopup(Announcement a) {
    bool isChecked = false;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Must confirm
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Red Header with Siren
                  Container(
                    width: double.infinity,
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFB71C1C), Color(0xFFC62828)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge & Expiry
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 12, color: Colors.red.shade700),
                                  const SizedBox(width: 4),
                                  Text('URGENSI TINGGI', style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Text('Berlaku: 3 hari lagi', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Image if available (Above Title)
                        if (a.imageUrl != null && a.imageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: a.imageUrl!,
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator())),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Title
                        Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        
                        // Body
                        Text(
                          a.body,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        
                        // Warning Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3F3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Color(0xFFF44336)),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Pengumuman ini akan muncul setiap hari selama 3 hari hingga kamu mengonfirmasi telah membaca.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFFC62828), height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Footer Meta
                        Text(
                          'Dari: Admin HSE - PT. Bukit Bakiri Energi - ${_formatDate(a.createdAt)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        const Divider(height: 32),
                        
                        // Checkbox
                        GestureDetector(
                          onTap: () => setModalState(() => isChecked = !isChecked),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24, height: 24,
                                child: Checkbox(
                                  value: isChecked,
                                  activeColor: const Color(0xFF1A56C4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (v) => setModalState(() => isChecked = v ?? false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Saya sudah membaca dan mengerti isi pengumuman ini',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isChecked ? () async {
                              await StorageService.markAnnouncementRead(a.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A56C4),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isChecked) const Icon(Icons.check, size: 18),
                                if (isChecked) const SizedBox(width: 8),
                                const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      
      // Use the CACHED filtered list instead of recalculating
      final filteredCount = _filteredReportsCache.length;
      
      if (!_isLoadingMore && _displayedCount < filteredCount) {
        setState(() {
          _isLoadingMore = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _displayedCount += 5;
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _searchQuery = v;
          _displayedCount = 5;
          _updateFilteredCache();
        });
      }
    });
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    if (_carouselItems.isEmpty) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_pageController.hasClients) return;
      if (_carouselItems.isEmpty) return;
      final next = (_currentPage + 1) % _carouselItems.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    ReportStore.instance.reports.removeListener(_updateFilteredCache);
    AnnouncementService.refreshNotifier.removeListener(_loadCarouselData);
    _searchDebounce?.cancel();
    _carouselTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Report> _getFilteredReports(List<Report> allReports) {
    final query = _searchQuery.toLowerCase();
    return allReports.where((r) {
      final matchType =
          _selectedType == 'All Report' || r.type.label == _selectedType;
      bool matchStatus = true;
      if (_statusFilter == 'Aktif') {
        matchStatus = r.status != ReportStatus.closed;
      } else if (_statusFilter == 'Selesai') {
        matchStatus = r.status == ReportStatus.closed;
      }

      final matchSearch = query.isEmpty ||
          r.title.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query);
      return matchType && matchStatus && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF2F2F2),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SapaHseHeader(
              isSearching: _isSearching,
              searchController: _searchController,
              searchHint: 'Cari laporan...',
              onSearchChanged: _onSearchChanged,
              onSearchToggle: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                    _displayedCount = 5;
                    _updateFilteredCache();
                  }
                });
              },
            ),

            // ── Scrollable Body ─────────────────────────────────────────────
            Expanded(
              child: ValueListenableBuilder<List<Report>>(
                valueListenable: ReportStore.instance.reports,
                builder: (context, _, __) {
                  final filtered = _filteredReportsCache;
                  final displayList = filtered.take(_displayedCount).toList();

                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // ── Carousel ───────────────────────────────────────────────────
                      SliverToBoxAdapter(child: _buildCarousel()),

                      // ── Filters ────────────────────────────────────────────────────
                      SliverToBoxAdapter(child: _buildFilters()),

                      // ── Report list section with state sync ─────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              const Text('Report List',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const Spacer(),
                              Text(
                                '${filtered.length} laporan',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (filtered.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined,
                                      size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Tidak ada laporan ditemukan',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index == displayList.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF1A56C4)),
                                  ),
                                );
                              }
                              return _ReportCard(
                                report: displayList[index],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportDetailScreen(
                                        report: displayList[index]),
                                  ),
                                ),
                              );
                            },
                            childCount:
                                displayList.length + (_isLoadingMore ? 1 : 0),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    if (_carouselItems.isEmpty) {
      return Container(
        height: 240,
        color: const Color(0xFF263238),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white38),
        ),
      );
    }
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _carouselItems.length,
            itemBuilder: (_, index) {
              final item = _carouselItems[index];
              final isNews = item is NewsArticle;
              
              final String title = isNews ? item.title : item.title;
              final String? rawImageUrl = isNews ? item.imageUrl : item.imageUrl;
              final String imageUrl = (rawImageUrl != null && rawImageUrl.isNotEmpty) 
                  ? rawImageUrl 
                  : 'https://placehold.co/600x400/1A56C4/FFFFFF?text=SapaHSE+ANNOUNCEMENT';
              final String label = isNews ? 'BERITA' : 'PENGUMUMAN';
              final Color labelColor = isNews ? Colors.blue : Colors.purple;

              return GestureDetector(
                onTap: () {
                  if (isNews) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NewsDetailScreen(article: item),
                      ),
                    );
                  } else {
                    _showUrgentPopup(item); 
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF37474F),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white38, strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF37474F),
                        child: const Icon(Icons.image,
                            color: Colors.white24, size: 60),
                      ),
                    ),
                    
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.88)
                          ],
                          stops: const [0.3, 1.0],
                         ),
                      ),
                    ),

                    // Type Badge
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Title
                    Positioned(
                      left: 16,
                      right: 52,
                      bottom: 38,
                      child: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.35,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Arrows and dots logic stays similar, but updated with item info
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final prev = _currentPage > 0 ? _currentPage - 1 : _carouselItems.length - 1;
                  _pageController.animateToPage(prev, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                },
                child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle), child: const Icon(Icons.chevron_left, color: Colors.white, size: 22)),
              ),
            ),
          ),
          Positioned(
            right: 8, top: 0, bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final next = (_currentPage + 1) % _carouselItems.length;
                  _pageController.animateToPage(next, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                },
                child: Container(width: 32, height: 32, decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle), child: const Icon(Icons.chevron_right, color: Colors.white, size: 22)),
              ),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: 12,
            child: Row(
              children: [
                Row(
                  children: List.generate(
                      _carouselItems.length,
                      (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: i == _currentPage ? 20 : 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: i == _currentPage ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.person_outline, color: Colors.white70, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    () {
                      final item = _carouselItems[_currentPage];
                      if (item is NewsArticle) return '${item.author}  •  ${item.date}';
                      if (item is Announcement) return '${item.creatorName ?? 'Admin'}  •  ${item.timeAgo}';
                      return '';
                    }(),
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTERS ───────────────────────────────────────────────────────────────
  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      margin: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPORT TYPE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.6),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                items: _reportTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedType = val;
                      _displayedCount = 5;
                      _updateFilteredCache();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildStatusChip('Aktif')),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusChip('Selesai')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = label;
          _displayedCount = 5;
          _updateFilteredCache();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A56C4) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A56C4) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A56C4).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              ValueListenableBuilder<List<Report>>(
                valueListenable: ReportStore.instance.reports,
                builder: (context, _, __) {
                  final count = _filteredReportsCache.length;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── REPORT CARD ───────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

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
      'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Color get _severityColor {
    switch (report.severity) {
      case ReportSeverity.low:
        return const Color(0xFF4CAF50);
      case ReportSeverity.medium:
        return const Color(0xFFFF9800);
      case ReportSeverity.high:
        return const Color(0xFFF44336);
      case ReportSeverity.critical:
        return const Color(0xFFB71C1C);
    }
  }

  Color get _statusColor {
    switch (report.status) {
      case ReportStatus.open:
        return const Color(0xFF2196F3);
      case ReportStatus.inProgress:
        return const Color(0xFF9C27B0);
      case ReportStatus.closed:
        return const Color(0xFF757575);
    }
  }

  Color get _typeColor {
    switch (report.type) {
      case ReportType.hazard:
        return const Color(0xFFF44336);
      case ReportType.inspection:
        return const Color(0xFF1565C0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [],
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
                            child: CachedNetworkImage(
                              imageUrl: report.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
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
                              report.type.label.toUpperCase(),
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
                              report.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                report.description,
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
                                Text(_formatDate(report.createdAt),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on_outlined,
                                    size: 10, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(report.location,
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
                                    color: _statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: _statusColor.withValues(
                                            alpha: 0.3)),
                                  ),
                                  child: Text(
                                    report.status.label,
                                    style: TextStyle(
                                        color: _statusColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _severityColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    report.severity.label,
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
            ],
          ),
        ),
      ),
    );
  }
}
