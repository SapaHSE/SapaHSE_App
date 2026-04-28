import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';

class CompanyManagementScreen extends StatefulWidget {
  const CompanyManagementScreen({super.key});

  @override
  State<CompanyManagementScreen> createState() => _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF1A56C4);
  static const _red = Color(0xFFD32F2F);
  static const _orange = Color(0xFFF57C00);

  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  List<CompanyData> _allCompanies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final companies = await CompanyService.getCompanies();
      if (mounted) {
        setState(() {
          _allCompanies = companies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _navigateToCompanyForm({CompanyData? company, String? defaultCategory}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CompanyFormScreen(
          companyToEdit: company,
          defaultCategory: defaultCategory,
        ),
      ),
    );
    if (result == true) {
      _loadData();
      _showSnack(company == null ? 'Company berhasil ditambahkan.' : 'Company berhasil diperbarui.');
    }
  }

  void _confirmDeleteCompany(CompanyData company) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Company', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Yakin ingin menghapus ${company.name}? Semua data yang terkait mungkin akan hilang.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await CompanyService.deleteCompany(company.id);
                _showSnack('Company berhasil dihapus.');
              } catch (e) {
                _showSnack(e.toString(), isError: true);
              }
              _loadData();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(CompanyData company) async {
    setState(() => _isLoading = true);
    try {
      await CompanyService.toggleCompanyStatus(company.id);
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Company Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _blue,
          labelColor: _blue,
          unselectedLabelColor: Colors.grey.shade400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Daftar Company'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMainListTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToCompanyForm(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Company'),
        isExtended: true,
      ),
    );
  }

  Widget _buildMainListTab() {
    // Group companies by category
    final owners = _allCompanies.where((c) => c.category == 'owner').toList();
    final kontraktors = _allCompanies.where((c) => c.category == 'kontraktor').toList();
    final subkontraktors = _allCompanies.where((c) => c.category == 'subkontraktor').toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 16),
          _buildCategoryCard('Owner', 'OWN', _blue, owners, 'owner'),
          _buildCategoryCard('Kontraktor', 'KON', _red, kontraktors, 'kontraktor'),
          _buildCategoryCard('Sub Kontraktor', 'SUB', _orange, subkontraktors, 'subkontraktor'),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Daftar tipe company yang ada dalam sistem.',
              style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, String code, Color color, List<CompanyData> subs, String defaultCategory) {
    final bgColor = color.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$code — $title',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${subs.where((s) => s.isActive).length} company aktif',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
              ],
            ),
          ),
          // Subcategories
          ...subs.map((sub) => _buildSubcategoryItem(sub)),
          // Add Subcategory Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _navigateToCompanyForm(defaultCategory: defaultCategory),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Tambah $title'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(CompanyData sub) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade100),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: sub.isActive ? Colors.green : Colors.grey.shade300),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    if (sub.code != null && sub.code!.isNotEmpty)
                      Text(sub.code!, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                onPressed: () => _confirmDeleteCompany(sub),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => _navigateToCompanyForm(company: sub),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _toggleStatus(sub),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sub.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sub.isActive ? 'On' : 'Off',
                    style: TextStyle(
                      color: sub.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Company Form Screen ─────────────────────────────────────────────────────

class _CompanyFormScreen extends StatefulWidget {
  final CompanyData? companyToEdit;
  final String? defaultCategory;

  const _CompanyFormScreen({this.companyToEdit, this.defaultCategory});

  @override
  State<_CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<_CompanyFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  late String _category;
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _category = widget.companyToEdit?.category ?? widget.defaultCategory ?? 'owner';
    _nameCtrl = TextEditingController(text: widget.companyToEdit?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.companyToEdit?.code ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama Company wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      dynamic result;
      if (widget.companyToEdit != null) {
        result = await CompanyService.updateCompany(
          widget.companyToEdit!.id,
          name,
          _category,
          code: code,
        );
      } else {
        result = await CompanyService.createCompany(
          name,
          _category,
          code: code,
        );
      }

      if (result != null) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan data')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.companyToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Company' : 'Tambah Company', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'TIPE COMPANY',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('MASUK KE *'),
                  const SizedBox(height: 8),
                  _buildDropdown(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'DETAIL COMPANY',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('NAMA COMPANY *'),
                  const SizedBox(height: 8),
                  _buildTextField(_nameCtrl, hint: 'Contoh: PT Bukit Baiduri Energi'),
                  const SizedBox(height: 16),
                  _buildLabel('KODE (OPSIONAL)'),
                  const SizedBox(height: 8),
                  _buildTextField(_codeCtrl, hint: 'Contoh: BBE'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⏳', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: Color(0xFFF57F17), fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: 'Setelah disimpan, perubahan akan langsung berlaku pada data '),
                  TextSpan(text: 'Company Management.', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.blueGrey.shade300,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        value: _category,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        items: const [
          DropdownMenuItem(value: 'owner', child: Text('Owner', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          DropdownMenuItem(value: 'kontraktor', child: Text('Kontraktor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          DropdownMenuItem(value: 'subkontraktor', child: Text('Sub Kontraktor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
        onChanged: (v) => setState(() => _category = v!),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, {String? hint}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
