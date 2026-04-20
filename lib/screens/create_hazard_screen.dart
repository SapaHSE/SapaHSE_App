import 'dart:io' show File;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report.dart';
import '../services/cloud_save_service.dart';

const _perusahaanList = [
  'PT. Bukit Baiduri Energi',
  'PT. Khotai Makmur Insan Abadi',
];

const _departemenList = [
  'HSE',
  'Produksi',
  'Maintenance',
  'Engineering',
  'HRD',
  'Logistik',
  'Security',
];

const _tagOrangList = [
  'Budi Santoso',
  'Ahmad Fauzi',
  'Riko Pratama',
  'Hendra Wijaya',
  'Siti Rahayu',
  'Dian Permata',
  'Eko Susilo',
  'Novi Andriani',
  'Wahyu Hidayat',
  'Agus Setiawan',
  'Bambang Purnomo',
  'Lintang Bhaskara',
  'Maya Putri',
  'Reza Firmansyah',
  'Kevin Alfarisi',
  'Deni Setiawan',
  'Putri Wulandari',
];

const _subkategoriTTA = [
  'Tidak Menggunakan APD',
  'Mengoperasikan Peralatan Tanpa Izin',
  'Posisi/Sikap Kerja Tidak Aman',
  'Bekerja di Bawah Pengaruh Alkohol/Obat',
  'Mengabaikan Prosedur Keselamatan',
  'Berkendara Tidak Aman',
  'Menggunakan Peralatan Rusak',
];

const _subkategoriKTA = [
  'Kondisi Lantai/Jalan Berbahaya',
  'Peralatan Rusak/Tidak Layak Pakai',
  'Pencahayaan Tidak Memadai',
  'Penyimpanan Material Tidak Aman',
  'Bahaya Benda Jatuh/Terlempar',
  'Kebisingan Berlebihan',
  'Instalasi Listrik Tidak Aman',
  'Ventilasi Tidak Memadai',
];

class CreateHazardScreen extends StatefulWidget {
  const CreateHazardScreen({super.key});

  @override
  State<CreateHazardScreen> createState() => _CreateHazardScreenState();
}

class _CreateHazardScreenState extends State<CreateHazardScreen> {
  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);
  static const _bgColor = Color(0xFFF0F0F0);

  int _currentStep = 0;

  // Forms
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // Step 1
  String? _selectedKategori;
  String? _selectedSubkategori;
  String? _selectedPerusahaan;
  String? _selectedDepartemen;
  String? _selectedTagOrang;

  // Step 2
  final _titleCtrl = TextEditingController();
  ReportSeverity? _selectedSeverity;
  final _kronologiCtrl = TextEditingController();
  final _saranCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  XFile? _photoFile;
  final _picker = ImagePicker();

  // Step 3
  bool _isPublic = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _kronologiCtrl.dispose();
    _saranCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  List<String> get _subkategoriList {
    if (_selectedKategori == 'TTA (Tindakan Tidak Aman)')
      return _subkategoriTTA;
    if (_selectedKategori == 'KTA (Kondisi Tidak Aman)') return _subkategoriKTA;
    return [];
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked != null) setState(() => _photoFile = picked);
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
      if (_selectedPerusahaan == null || _selectedDepartemen == null || _selectedTagOrang == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perusahaan, Departemen, dan Tag Orang wajib diisi'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (!_formKey2.currentState!.validate()) return;
      if (_selectedSeverity == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Status resiko wajib dipilih'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() => _currentStep++);
    } else {
      _submitReport();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    final online = await CloudSaveService.isOnline();
    final data = {
      'title': _titleCtrl.text.trim(),
      'kronologi': _kronologiCtrl.text.trim(),
      'saran': _saranCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'perusahaan': _selectedPerusahaan,
      'tagOrang': _selectedTagOrang,
      'severity': _selectedSeverity?.name,
      'kategori': _selectedKategori,
      'subkategori': _selectedSubkategori,
      'photoPath': _photoFile?.path,
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Kategori Hazard *'),
          DropdownButtonFormField<String>(
            value: _selectedKategori,
            validator: (v) => v == null ? 'Wajib dipilih' : null,
            decoration: _inputDeco(
                hint: 'Pilih Kategori', icon: Icons.category_outlined),
            items: ['TTA (Tindakan Tidak Aman)', 'KTA (Kondisi Tidak Aman)']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedKategori = v;
              _selectedSubkategori = null;
            }),
          ),
          const SizedBox(height: 14),
          _label('Subkategori Hazard *'),
          DropdownButtonFormField<String>(
            value: _selectedSubkategori,
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
              hintText: 'Pilih / Cari Perusahaan',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() => _selectedPerusahaan = v),
              dropdownMenuEntries: _perusahaanList
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _label('Departemen *'),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              width: constraints.maxWidth,
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: _selectedDepartemen,
              hintText: 'Pilih / Cari Departemen',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() => _selectedDepartemen = v),
              dropdownMenuEntries: _departemenList
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _label('PJA (Penanggung Jawab Area) *'),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              width: constraints.maxWidth,
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: _selectedTagOrang,
              hintText: 'Pilih / Cari Orang',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() => _selectedTagOrang = v),
              dropdownMenuEntries: _tagOrangList
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
            ),
          ),
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
          _label('Judul Laporan *'),
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
              ReportSeverity.high,
              ReportSeverity.critical
            ].map((s) {
              final isSelected = _selectedSeverity == s;
              final colors = {
                ReportSeverity.low: Colors.green,
                ReportSeverity.high: Colors.orange,
                ReportSeverity.critical: Colors.red,
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
                          : colors[s]!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: colors[s]!, width: isSelected ? 2 : 1),
                    ),
                    child: Text(s.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isSelected ? Colors.white : colors[s],
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
          _label('Deskripsi Saran *'),
          TextFormField(
            controller: _saranCtrl,
            maxLines: 3,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Saran perbaikan...'),
          ),
          const SizedBox(height: 14),
          _label('Lokasi Kejadian *'),
          TextFormField(
            controller: _locationCtrl,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(
                hint: 'Lokasi kejadian', icon: Icons.location_on_outlined),
          ),
          const SizedBox(height: 14),
          _label('Foto *'),
          _photoFile != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(_photoFile!.path,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover)
                          : Image.file(File(_photoFile!.path),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white),
                        style:
                            IconButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => setState(() => _photoFile = null),
                      ),
                    )
                  ],
                )
              : Row(
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
              const Text('Preview Laporan Akhir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              _previewItem(
                  'Kategori', '$_selectedKategori - $_selectedSubkategori'),
              _previewItem('Perusahaan', '$_selectedPerusahaan'),
              _previewItem('Departemen', '$_selectedDepartemen'),
              _previewItem('PJA', '$_selectedTagOrang'),
              _previewItem('Judul', _titleCtrl.text),
              _previewItem(
                  'Resiko', _selectedSeverity?.name.toUpperCase() ?? '-'),
              _previewItem('Kronologi', _kronologiCtrl.text),
              _previewItem('Saran', _saranCtrl.text),
              _previewItem('Lokasi', _locationCtrl.text),
              if (_photoFile != null) ...[
                const SizedBox(height: 8),
                const Text('Foto:',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showPhotoZoom(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(_photoFile!.path,
                            height: 120, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(File(_photoFile!.path),
                            height: 120, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Ketuk foto untuk memperbesar', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
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
                    'Laporan dapat dilihat oleh semua orang di menu News',
                    style: TextStyle(fontSize: 12)),
                value: true,
                groupValue: _isPublic,
                activeColor: _blue,
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
              RadioListTile<bool>(
                title: const Text('Private'),
                subtitle: const Text(
                    'Laporan hanya dilihat oleh Anda dan pihak terkait',
                    style: TextStyle(fontSize: 12)),
                value: false,
                groupValue: _isPublic,
                activeColor: _blue,
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
            ],
          ),
        ),
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

  void _showPhotoZoom(BuildContext context) {
    if (_photoFile == null) return;
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
                    ? Image.network(_photoFile!.path)
                    : Image.file(File(_photoFile!.path)),
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
            title: const Text('Preview', style: TextStyle(fontSize: 12)),
            content: _buildStep3(),
          ),
        ],
      ),
    );
  }
}
