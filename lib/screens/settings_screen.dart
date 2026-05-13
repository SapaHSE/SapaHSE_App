import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/profile_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import '../main.dart';
import 'create_hazard_screen.dart';
import 'create_inspection_screen.dart';
import 'qr_scan_screen.dart';
import 'my_profile.dart';
import 'package:local_auth/local_auth.dart';
import '../services/cloud_save_service.dart';
import '../services/report_service.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguage = 'Indonesia';
  bool _isDarkMode = false;
  bool _isPushEnabled = true;
  bool _isBiometricEnabled = false;
  int _draftCount = 0;
  bool _isSyncing = false;
  String _storageSize = '0 KB';
  static const _blue = Color(0xFF1A56C4);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshSyncData();
  }

  Future<void> _refreshSyncData() async {
    final count = await CloudSaveService.instance.getDraftCount();
    // Simplified storage calculation for demo/utility
    final drafts = await CloudSaveService.instance.getDrafts();
    double sizeKb = 0;
    for (var d in drafts) {
      sizeKb += (d.data.toString().length) / 1024.0;
      if (d.data['imagePath'] != null) {
        try {
          final file = File(d.data['imagePath']);
          if (await file.exists()) {
            sizeKb += (await file.length()) / 1024.0;
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _draftCount = count;
        _storageSize = sizeKb > 1024 
            ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' 
            : '${sizeKb.toStringAsFixed(0)} KB';
      });
    }
  }

  Future<void> _handleSync() async {
    if (_draftCount == 0 || _isSyncing) return;

    setState(() => _isSyncing = true);

    await CloudSaveService.instance.syncAll(
      uploadFn: (draft) async {
        if (draft.type == DraftType.hazard) {
          final res = await ReportService.createHazardReport(
            title: draft.data['title'] ?? '',
            description: draft.data['description'] ?? '',
            location: draft.data['location'] ?? '',
            severity: draft.data['severity'],
            hazardCategory: draft.data['hazardCategory'],
            hazardSubcategory: draft.data['hazardSubcategory'],
            imagePath: draft.data['imagePath'],
          );
          return res.success;
        } else {
          // Add logic for inspection if needed
          return true; 
        }
      },
      onEach: (draft, success) {
        if (success) {
          debugPrint('Synced draft: ${draft.id}');
        }
      },
    );

    await _refreshSyncData();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi selesai.')),
      );
    }
  }

  Future<void> _loadSettings() async {
    final bioEnabled = await StorageService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = bioEnabled;
      });
    }
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Biometrik tidak didukung di platform Web.')));
      return;
    }

    if (!enable) {
      await StorageService.setBiometricEnabled(false);
      setState(() => _isBiometricEnabled = false);
      return;
    }

    final user = await StorageService.getUser();
    final employeeId = user?['employee_id'] as String?;
    if (employeeId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesi tidak valid.')));
      return;
    }

    final localAuth = LocalAuthentication();
    try {
      final canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (!canCheck) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perangkat tidak mendukung biometrik.')));
        return;
      }

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk mengaktifkan login otomatis',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        if (!mounted) return;
        final password = await _showPasswordPromptDialog(context);
        if (password != null && password.isNotEmpty) {
          await StorageService.saveBiometricCredentials(employeeId, password);
          await StorageService.setBiometricEnabled(true);
          setState(() => _isBiometricEnabled = true);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login biometrik diaktifkan.')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<String?> _showPasswordPromptDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan password Anda untuk disimpan dengan aman sebagai kredensial biometrik.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A56C4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index == 4) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FabMenuSheet(
        currentIndex: 4,
        onScanQr: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScanScreen()));
        },
        onCreateHazard: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateHazardScreen()));
        },
        onCreateInspection: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateInspectionScreen()));
        },
        onAddCarousel: () { Navigator.pop(context); },
        onAddNews: () { Navigator.pop(context); },
        onEditBiodata: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'edit_biodata')));
        },
        onAddLicense: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'add_license')));
        },
        onAddCertification: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'add_certification')));
        },
        onEditMedical: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProfileScreen(initialAction: 'edit_medical')));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('PREFERENSI APLIKASI'),
                  _buildCard([
                    _buildDropdownRow(
                      icon: Icons.language,
                      iconColor: const Color(0xFF1976D2),
                      label: 'Bahasa',
                      subtitle: 'Bahasa tampilan aplikasi',
                      value: _selectedLanguage,
                      items: ['Indonesia', 'English'],
                      onChanged: (v) => setState(() => _selectedLanguage = v!),
                    ),
                    _buildDivider(),
                    _buildSwitchRow(
                      icon: Icons.dark_mode,
                      iconColor: Colors.black,
                      label: 'Tema Gelap',
                      value: _isDarkMode,
                      onChanged: (v) => setState(() => _isDarkMode = v),
                    ),
                    _buildDivider(),
                    _buildSwitchRow(
                      icon: Icons.notifications_active,
                      iconColor: const Color(0xFFFBC02D),
                      label: 'Notifikasi Push',
                      subtitle: 'Laporan, pengumuman, tugas',
                      value: _isPushEnabled,
                      onChanged: (v) => setState(() => _isPushEnabled = v),
                    ),
                  ]),
                  _buildSectionHeader('SINKRONISASI & PENYIMPANAN'),
                  _buildCard([
                    _buildActionRow(
                      icon: Icons.sync,
                      iconColor: const Color(0xFF43A047),
                      label: 'Status Sinkronisasi',
                      subtitle: _isSyncing 
                          ? 'Sedang menyelaraskan...' 
                          : '$_draftCount data menunggu sinkronisasi',
                      onTap: _handleSync,
                      trailing: _isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : (_draftCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text('$_draftCount',
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                )
                              : const Icon(Icons.check_circle, color: Colors.green, size: 20)),
                    ),
                    _buildDivider(),
                    _buildActionRow(
                      icon: Icons.storage,
                      iconColor: const Color(0xFF5C38FF),
                      label: 'Local Storage',
                      subtitle: '$_storageSize digunakan untuk draft offline',
                      trailing: TextButton(
                        onPressed: () async {
                          await CloudSaveService.instance.clearAll();
                          await _refreshSyncData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Penyimpanan lokal dibersihkan.')));
                          }
                        },
                        child: const Text('Hapus',
                            style: TextStyle(
                                color: Color(0xFF5C38FF),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    _buildDivider(),
                    _buildSwitchRow(
                      icon: Icons.fingerprint,
                      iconColor: const Color(0xFFF57C00),
                      label: 'Login Biometrik',
                      subtitle: 'Face ID / Sidik Jari',
                      value: _isBiometricEnabled,
                      onChanged: _toggleBiometric,
                    ),
                  ]),
                  _buildSectionHeader('AKUN'),
                  _buildCard([
                    _buildMenuRow(Icons.lock_outline, 'Ganti Kata Sandi', '',
                        onTap: () => _showChangePasswordDialog(context)),
                    _buildDivider(),
                    _buildMenuRow(Icons.logout, 'Keluar', '',
                        isDestructive: true, onTap: () => _showLogoutDialog(context)),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SettingsNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 4, onTap: _onTabTapped),
                      _SettingsNavItem(icon: Icons.article_outlined, label: 'News', index: 1, currentIndex: 4, onTap: _onTabTapped),
                      const SizedBox(width: 56), // Space for FAB
                      _SettingsNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 4, onTap: _onTabTapped),
                      _SettingsNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 4, onTap: _onTabTapped),
                    ],
                  ),
                ),
                Positioned(
                  top: -24,
                  child: GestureDetector(
                    onTap: _openFabMenu,
                    child: Container(
                      width: 60, // Slightly larger
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A56C4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Text(title,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      );

  Widget _buildCard(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(children: children),
      );

  Widget _buildDivider() =>
      Divider(height: 1, color: Colors.grey.shade50, indent: 60, endIndent: 16);

  Widget _buildSwitchRow(
          {required IconData icon,
          required Color iconColor,
          required String label,
          String? subtitle,
          required bool value,
          required ValueChanged<bool> onChanged}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIconBox(icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF1565C0),
              activeTrackColor: const Color(0xFF1565C0).withValues(alpha: 0.2),
            ),
          ],
        ),
      );

  Widget _buildDropdownRow(
          {required IconData icon,
          required Color iconColor,
          required String label,
          required String subtitle,
          required String value,
          required List<String> items,
          required ValueChanged<String?> onChanged}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIconBox(icon, iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                items: items
                    .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: onChanged,
                icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      );


  Widget _buildActionRow(
          {required IconData icon,
          required Color iconColor,
          required String label,
          required String subtitle,
          VoidCallback? onTap,
          required Widget trailing}) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildIconBox(icon, iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(subtitle,
                        style:
                            TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );

  Widget _buildMenuRow(IconData icon, String label, String subtitle,
          {bool isDestructive = false, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildIconBox(
                  icon, isDestructive ? Colors.red : Colors.grey.shade400,
                  isOutline: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDestructive ? Colors.red : Colors.black)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
            ],
          ),
        ),
      );

  Widget _buildIconBox(IconData icon, Color color, {bool isOutline = false}) =>
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: isOutline ? Border.all(color: Colors.grey.shade100) : null,
        ),
        child: Icon(icon, color: color, size: 20),
      );

  void _showChangePasswordDialog(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Ubah Password',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(errorMsg!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    _buildDialogField('Password Lama', oldCtrl, hint: 'Masukkan password lama'),
                    const SizedBox(height: 16),
                    _buildDialogField('Password Baru', newCtrl, hint: 'Minimal 8 karakter'),
                    const SizedBox(height: 16),
                    _buildDialogField('Konfirmasi Password Baru', confirmCtrl, hint: 'Ulangi password baru'),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () async {
                          setModalState(() {
                            isLoading = true;
                            errorMsg = null;
                          });

                          final result = await ProfileService.changePassword(
                            currentPassword: oldCtrl.text,
                            newPassword: newCtrl.text,
                            confirmPassword: confirmCtrl.text,
                          );

                          if (!context.mounted) return;

                          if (result.success) {
                            Navigator.pop(context);
                            await StorageService.clear();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password berhasil diubah. Silakan login kembali.')),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          } else {
                            setModalState(() {
                              isLoading = false;
                              errorMsg = result.message;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDialogField(String label, TextEditingController controller, {required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A56C4), width: 1.5)),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await StorageService.clear();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}



class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _SettingsNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF1A56C4) : Colors.grey, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}