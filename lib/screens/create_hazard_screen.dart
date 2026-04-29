import 'dart:io' show File;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../models/report.dart';
import '../models/company_model.dart';
import '../models/user_model.dart';
import '../services/cloud_save_service.dart';
import '../services/company_service.dart';
import '../services/report_service.dart';
import '../services/auth_service.dart';
import 'map_picker_screen.dart';







class CreateHazardScreen extends StatefulWidget {
  const CreateHazardScreen({super.key});

  @override
  State<CreateHazardScreen> createState() => _CreateHazardScreenState();
}

class _CreateHazardScreenState extends State<CreateHazardScreen> {
  static const _blue = Color(0xFF1A56C4);

  static const _bgColor = Color(0xFFF0F0F0);

  int _currentStep = 0;

  // Forms
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _step1Key = GlobalKey();
  final _step2Key = GlobalKey();
  final _step3Key = GlobalKey();

  // Step 1
  String? _selectedKategori;
  String? _selectedSubkategori;
  String? _selectedPerusahaan;
  final List<String> _selectedPIC = [];

  // Step 2
  final _titleCtrl = TextEditingController();
  ReportSeverity? _selectedSeverity;
  final _kronologiCtrl = TextEditingController();
  final List<String> _selectedPelaku = [];
  final _saranCtrl = TextEditingController();
  String? _selectedLokasi;
  final _locationCtrl = TextEditingController();
  final _pelaporLocationCtrl = TextEditingController();
  final _kejadianLocationCtrl = TextEditingController();
  final List<XFile> _photoFiles = [];
  final _picker = ImagePicker();

  // Step 3
  bool _isPublic = true;
  bool _isSubmitting = false;

  List<CompanyData> _companiesData = [];
  List<AreaData> _areasData = [];
  List<HazardCategoryData> _categoriesData = [];
  List<UserModel> _usersData = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchPelaporLocationSilent();
    _fetchDynamicData();
  }

  Future<void> _fetchDynamicData() async {
    try {
      final companies = await CompanyService.getCompanies(active: true, category: 'owner');
      final areas = await CompanyService.getAreas(active: true);
      final categories = await ReportService.getHazardCategories();
      final users = await AuthService.getUsers();
      
      if (mounted) {
        setState(() {
          _companiesData = companies;
          _areasData = areas;
          _categoriesData = categories;
          _usersData = users;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dynamic data: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  Future<void> _fetchPelaporLocationSilent() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium));
        if (mounted) {
          final loc = '${pos.latitude}, ${pos.longitude}';
          _pelaporLocationCtrl.text = loc;
          if (_kejadianLocationCtrl.text.isEmpty) {
            _kejadianLocationCtrl.text = loc;
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch lokasi pelapor: $e');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _kronologiCtrl.dispose();
    _saranCtrl.dispose();
    _locationCtrl.dispose();
    _pelaporLocationCtrl.dispose();
    _kejadianLocationCtrl.dispose();
    super.dispose();
  }

  List<String> get _subkategoriList {
    if (_selectedKategori == null) return [];
    try {
      final category = _categoriesData.firstWhere((c) => c.name == _selectedKategori);
      return category.subcategories.map((s) => s.name).toList();
    } catch (e) {
      return [];
    }
  }

  List<String> get _lokasiList {
    if (_selectedPerusahaan == null) return [];
    try {
      final selectedCompany = _companiesData.firstWhere((c) => c.name == _selectedPerusahaan);
      return _areasData
          .where((a) => a.companyId == selectedCompany.id)
          .map((a) => a.name)
          .toList();
    } catch (e) {
      return [];
    }
  }

  String get _dynamicHseDepartment {
    try {
      final hseUser = _usersData.firstWhere(
        (u) => (u.department?.toLowerCase().contains('hse') ?? false) || 
               (u.department?.toLowerCase().contains('k3') ?? false),
      );
    } catch (e) {
      // Ignore if not found
    }
    return 'Departemen HSE';
  }

  List<String> get _picOptions {
    if (_selectedPerusahaan == null) return [];

    final companyUsers = _usersData.where((u) => 
        u.role != 'superadmin'
    ).toList();
    final depts = companyUsers
        .map((u) => u.department)
        .where((d) => d != null && d!.isNotEmpty)
        .toSet()
        .toList();

    final List<String> options = [];
    for (var d in depts) {
      if (!d!.toLowerCase().contains('hse') && !d.toLowerCase().contains('k3')) {
        options.add('Departemen $d');
      }
    }
    for (var u in companyUsers) {
      final deptStr = (u.department != null && u.department!.isNotEmpty) ? ' (${u.department})' : '';
      options.add('${u.fullName}$deptStr');
    }
    return options;
  }

  Future<void> _pickLocationFromMap(TextEditingController ctrl) async {
    LatLng? current;
    if (ctrl.text.isNotEmpty) {
      final parts = ctrl.text.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          current = LatLng(lat, lng);
        }
      }
    }

    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialLocation: current),
      ),
    );

    if (result != null) {
      setState(() {
        ctrl.text = '${result.latitude}, ${result.longitude}';
      });
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<XFile?> _compressAndConvertImage(XFile file) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      debugPrint('Compression error: $e');
      return file; // Fallback ke file asli jika kompresi gagal
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1280,
        );
        if (picked.isNotEmpty) {
          for (var file in picked) {
            final compressed = await _compressAndConvertImage(file);
            if (compressed != null) setState(() => _photoFiles.add(compressed));
          }
        }
      } else {
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1280,
        );
        if (picked != null) {
          final compressed = await _compressAndConvertImage(picked);
          if (compressed != null) setState(() => _photoFiles.add(compressed));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey1.currentState!.validate()) return;
      if (_selectedPerusahaan == null || _selectedPIC.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perusahaan dan PIC wajib diisi'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() => _currentStep++);
      _scrollToTop();
    } else if (_currentStep == 1) {
      if (!_formKey2.currentState!.validate()) return;
      if (_selectedSeverity == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Status resiko wajib dipilih'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      _showPinpointConfirmationDialog(() {
        setState(() => _currentStep++);
        _scrollToTop();
      });
    } else {
      _submitReport();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _currentStep == 0
          ? _step1Key
          : _currentStep == 1
              ? _step2Key
              : _step3Key;
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _showPinpointConfirmationDialog(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Pinpoint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah lokasi kejadian (pinpoint) sudah sesuai?', style: TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: _blue, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _kejadianLocationCtrl.text,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Lanjut', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    final online = await CloudSaveService.isOnline();
    final data = {
      'title': _titleCtrl.text.trim(),
      'kronologi': _kronologiCtrl.text.trim(),
      'pelakuPelanggaran': _selectedPelaku.join(', '),
      'saran': _saranCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'pelaporLocation': _pelaporLocationCtrl.text.trim(),
      'kejadianLocation': _kejadianLocationCtrl.text.trim(),
      'perusahaan': _selectedPerusahaan,
      'pic': _selectedPIC,
      'severity': _selectedSeverity?.name,
      'kategori': _selectedKategori,
      'subkategori': _selectedSubkategori,
      'photoPaths': _photoFiles.map((f) => f.path).toList(),
      'isPublic': _isPublic,
    };

    if (!online) {
      final draft = ReportDraft(
        id: 'hazard_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
        type: DraftType.hazard,
        title: _titleCtrl.text.trim(),
        data: data,
        createdAt: DateTime.now(),
      );
      await CloudSaveService.instance.saveDraft(draft);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showResultDialog(
        isOffline: true,
        title: 'Tersimpan sebagai Draft',
        message: 'Tidak ada koneksi internet. Laporan disimpan secara lokal.',
      );
    } else {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showResultDialog(
        isOffline: false,
        title: 'Laporan Terkirim!',
        message: 'Laporan hazard Anda berhasil dikirim.',
      );
    }
  }

  void _showResultDialog(
      {required bool isOffline,
      required String title,
      required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.cloud_off : Icons.check_circle_outline,
              color: isOffline ? Colors.orange : _blue,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // ── UI Helpers ────────────────────────────────────────────────────────────
  InputDecoration _inputDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5)),
    );
  }

  InputDecorationTheme _dropdownTheme() {
    return InputDecorationTheme(
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5)),
      constraints: const BoxConstraints(maxHeight: 50),
    );
  }

  Widget _label(String text, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );


  // ── FULLSCREEN PERSON PICKER ──────────────────────────────────────────────
  Future<String?> _showPersonPicker({
    required String title,
    required List<String> options,
    String? hint,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PersonPickerContent(
        title: title,
        options: options,
        hint: hint ?? 'Cari...',
      ),
    );
  }

  Widget _picTagField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('PIC / Departemen Terkait *'),
        GestureDetector(
          onTap: () async {
            final result = await _showPersonPicker(
              title: 'Tag PIC / Departemen',
              options: _picOptions,
            );
            if (result != null) {
              setState(() {
                if (!_selectedPIC.contains(result)) {
                  _selectedPIC.add(result);
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_add_outlined,
                    size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ketuk untuk tag orang atau departemen',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (_selectedPIC.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedPIC
                .map((e) => Chip(
                      label: Text(e, style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      onDeleted: e == _dynamicHseDepartment
                          ? null
                          : () {
                              setState(() {
                                _selectedPIC.remove(e);
                              });
                            },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _pelakuTagField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Pelaku Pelanggaran (Opsional)'),
        GestureDetector(
          onTap: () async {
            final options = _usersData
                .where((u) => u.company == _selectedPerusahaan && u.role != 'superadmin')
                .map((u) {
                  final deptStr = (u.department != null && u.department!.isNotEmpty) ? ' (${u.department})' : '';
                  return '${u.fullName}$deptStr';
                })
                .toList();
            final result = await _showPersonPicker(
              title: 'Tag Pelaku Pelanggaran',
              options: options,
            );
            if (result != null) {
              setState(() {
                if (!_selectedPelaku.contains(result)) {
                  _selectedPelaku.add(result);
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_add_outlined,
                    size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ketuk untuk tag pelaku',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (_selectedPelaku.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedPelaku
                .map((e) => Chip(
                      label: Text(e, style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      onDeleted: () {
                        setState(() {
                          _selectedPelaku.remove(e);
                        });
                      },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Kategori Hazard *', key: _step1Key),
          DropdownButtonFormField<String>(
            initialValue: _selectedKategori,
            validator: (v) => v == null ? 'Wajib dipilih' : null,
            decoration: _inputDeco(
                hint: _isLoadingData ? 'Memuat data...' : 'Pilih Kategori', icon: Icons.category_outlined),
            items: _categoriesData
                .map((e) => DropdownMenuItem(value: e.name, child: Text(e.name)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedKategori = v;
              _selectedSubkategori = null;
            }),
          ),
          const SizedBox(height: 14),
          _label('Subkategori Hazard *'),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubkategori,
            validator: (v) => v == null ? 'Wajib dipilih' : null,
            decoration: _inputDeco(
                hint: 'Pilih Subkategori',
                icon: Icons.subdirectory_arrow_right),
            items: _subkategoriList
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => setState(() => _selectedSubkategori = v),
          ),
          const SizedBox(height: 14),
          _label('Perusahaan (Ketik untuk mencari) *'),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              width: constraints.maxWidth,
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: _selectedPerusahaan,
              hintText: _isLoadingData ? 'Memuat data...' : 'Pilih / Cari Perusahaan',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() {
                _selectedPerusahaan = v;
                _selectedLokasi = null;
                _selectedPIC.clear();
                _selectedPIC.add(_dynamicHseDepartment);
              }),
              dropdownMenuEntries: _companiesData
                  .map((e) => DropdownMenuEntry(value: e.name, label: e.name))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _picTagField(),
        ],
      ),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Judul Laporan *', key: _step2Key),
          TextFormField(
            controller: _titleCtrl,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Judul laporan'),
          ),
          const SizedBox(height: 14),
          _label('Status Resiko *'),
          Row(
            children: [
              ReportSeverity.low,
              ReportSeverity.medium,
              ReportSeverity.high
            ].map((s) {
              final isSelected = _selectedSeverity == s;
              final colors = {
                ReportSeverity.low: Colors.green,
                ReportSeverity.medium: Colors.orange,
                ReportSeverity.high: Colors.red,
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSeverity = s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors[s]
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSelected ? colors[s]! : Colors.grey.shade400,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Text(s.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _label('Deskripsi Kronologi *'),
          TextFormField(
            controller: _kronologiCtrl,
            maxLines: 3,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Jelaskan kronologi...'),
          ),
          const SizedBox(height: 14),
          _label('Deskripsi Saran (Opsional)'),
          TextFormField(
            controller: _saranCtrl,
            maxLines: 3,
            decoration: _inputDeco(hint: 'Saran perbaikan...'),
          ),
          const SizedBox(height: 14),
          _pelakuTagField(),
          const SizedBox(height: 14),
          _label('Lokasi Kejadian *'),
          DropdownButtonFormField<String>(
            initialValue: _selectedLokasi,
            validator: (v) => v == null ? 'Wajib dipilih' : null,
            decoration: _inputDeco(
                hint: _selectedPerusahaan == null 
                    ? 'Pilih Perusahaan Dulu' 
                    : (_isLoadingData ? 'Memuat data...' : 'Pilih Lokasi Kejadian'), 
                icon: Icons.location_city),
            items: _lokasiList
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedLokasi = v),
          ),
          const SizedBox(height: 14),
          _label('Pinpoint Lokasi Kejadian *'),
          TextFormField(
            controller: _kejadianLocationCtrl,
            readOnly: true,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(
              hint: 'Koordinat Kejadian',
              icon: Icons.place,
            ).copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.map_outlined),
                onPressed: () => _pickLocationFromMap(_kejadianLocationCtrl),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Foto (Opsional)'),
          if (_photoFiles.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photoFiles.length,
                itemBuilder: (context, index) {
                  final photo = _photoFiles[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(photo.path, fit: BoxFit.cover)
                              : Image.file(File(photo.path), fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photoFiles.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_photoFiles.isNotEmpty) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: const Text('Galeri'))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review Laporan Akhir',
                  key: _step3Key,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              _previewItem('Kategori', '$_selectedKategori - $_selectedSubkategori'),
              _previewItem('Perusahaan', '$_selectedPerusahaan'),
              _previewItem('PIC', _selectedPIC.join(', ')),
              _previewItem('Judul', _titleCtrl.text),
              _previewItem(
                  'Resiko', _selectedSeverity?.name.toUpperCase() ?? '-'),
              _previewItem('Kronologi', _kronologiCtrl.text),
              if (_saranCtrl.text.trim().isNotEmpty)
                _previewItem('Saran', _saranCtrl.text),
              if (_selectedPelaku.isNotEmpty)
                _previewItem('Pelaku Pelanggaran', _selectedPelaku.join(', ')),
              _previewItem('Lokasi', _selectedLokasi ?? '-'),
              if (_photoFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Foto:',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoFiles.length,
                    itemBuilder: (context, index) {
                      final photo = _photoFiles[index];
                      return GestureDetector(
                        onTap: () => _showPhotoZoom(context, photo),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(photo.path, fit: BoxFit.cover)
                                : Image.file(File(photo.path),
                                    fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Ketuk foto untuk memperbesar',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Pengaturan Privasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Public'),
                subtitle: const Text(
                    'Laporan dapat dilihat oleh semua orang di menu Utama',
                    style: TextStyle(fontSize: 12)),
                // ignore: deprecated_member_use
                value: true,
                // ignore: deprecated_member_use
                groupValue: _isPublic,
                activeColor: _blue,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
              RadioListTile<bool>(
                title: const Text('Private'),
                subtitle: const Text(
                    'Laporan hanya dilihat oleh Anda dan pihak terkait',
                    style: TextStyle(fontSize: 12)),
                // ignore: deprecated_member_use
                value: false,
                // ignore: deprecated_member_use
                groupValue: _isPublic,
                activeColor: _blue,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
            ],
          ),
        ),
        if (!_isPublic) ...[
          const SizedBox(height: 20),
          const Text('Tambah Departemen / PIC',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () async {
                    final result = await _showPersonPicker(
                      title: 'Tag PIC / Departemen',
                      options: _picOptions,
                    );
                    if (result != null) {
                      setState(() {
                        if (!_selectedPIC.contains(result)) {
                          _selectedPIC.add(result);
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_outlined,
                            size: 20, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Ketuk untuk tag orang atau departemen',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                if (_selectedPIC.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedPIC
                        .map((e) => Chip(
                              label:
                                  Text(e, style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onDeleted: () {
                                setState(() {
                                  _selectedPIC.remove(e);
                                });
                              },
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _previewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(': ', style: TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  void _showPhotoZoom(BuildContext context, XFile photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(photo.path)
                    : Image.file(File(photo.path)),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Buat Laporan Hazard',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        elevation: 0,
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Kembali'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isLastStep ? 'Kirim Laporan' : 'Selanjutnya',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        steps: [
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            title: const Text('Data', style: TextStyle(fontSize: 12)),
            content: _buildStep1(),
          ),
          Step(
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            title: const Text('Detail', style: TextStyle(fontSize: 12)),
            content: _buildStep2(),
          ),
          Step(
            isActive: _currentStep >= 2,
            title: const Text('Review', style: TextStyle(fontSize: 12)),
            content: _buildStep3(),
          ),
        ],
      ),
    );
  }
}

// ── PICKER CONTENT WIDGET ──────────────────────────────────────────────────
class _PersonPickerContent extends StatefulWidget {
  final String title;
  final List<String> options;
  final String hint;

  const _PersonPickerContent({
    required this.title,
    required this.options,
    required this.hint,
  });

  @override
  State<_PersonPickerContent> createState() => _PersonPickerContentState();
}

class _PersonPickerContentState extends State<_PersonPickerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((opt) => opt.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    // Grouping logic
    final depts = filtered.where((o) => o.startsWith('Departemen')).toList();
    final pjas = filtered.where((o) => !o.startsWith('Departemen')).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A56C4),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Field
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'Tidak menemukan hasil',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (depts.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
                          child: Text('DEPARTEMEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                        ),
                        ...depts.map((opt) => Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                                  trailing: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF1A56C4)),
                                  onTap: () => Navigator.pop(context, opt),
                                ),
                                const Divider(height: 1),
                              ],
                            )),
                      ],
                      if (pjas.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
                          child: Text('PIC / PJA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                        ),
                        ...pjas.map((opt) => Column(
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                                  trailing: const Icon(Icons.add_circle_outline, size: 20, color: Color(0xFF1A56C4)),
                                  onTap: () => Navigator.pop(context, opt),
                                ),
                                const Divider(height: 1),
                              ],
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
