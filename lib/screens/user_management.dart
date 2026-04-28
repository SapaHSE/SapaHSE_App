import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/company_service.dart';
import '../models/company_model.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _blue = Color(0xFF1A56C4); // Unified Blue
  bool _isLoading = false;
  bool _isLoadingUnapproved = false;
  List<dynamic> _allUsers = [];
  List<dynamic> _unapprovedUsers = [];
  String _searchQuery = '';
  String _selectedFilter = 'Semua';
  bool _isSuperadmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    final user = await StorageService.getUser();
    if (mounted) {
      if (user != null && user['role'] == 'superadmin') {
        setState(() => _isSuperadmin = true);
        _fetchUsers();
        _fetchUnapprovedUsers();
      } else {
        setState(() => _isSuperadmin = false);
      }
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final response = await ApiService.get('/admin/users?per_page=100');
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.success && response.data['data'] != null) {
          // Sometimes pagination data is nested
          final data = response.data['data'];
          if (data is Map && data.containsKey('data')) {
            _allUsers = data['data'] ?? [];
          } else if (data is List) {
            _allUsers = data;
          } else {
            _allUsers = [];
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.errorMessage ?? 'Gagal memuat pengguna')),
          );
        }
      });
    }
  }

  Future<void> _fetchUnapprovedUsers() async {
    setState(() => _isLoadingUnapproved = true);
    final response = await ApiService.get('/admin/users?is_active=0');
    if (mounted) {
      setState(() {
        _isLoadingUnapproved = false;
        if (response.success && response.data['data'] != null) {
          final data = response.data['data'];
          if (data is Map && data.containsKey('data')) {
            _unapprovedUsers = data['data'] ?? [];
          } else if (data is List) {
            _unapprovedUsers = data;
          } else {
            _unapprovedUsers = [];
          }
        }
      });
    }
  }

  Future<void> _approveUser(String id) async {
    final response = await ApiService.put('/admin/users/$id/approve', {});
    if (mounted) {
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna berhasil disetujui!')),
        );
        _fetchUnapprovedUsers();
        _fetchUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.errorMessage ?? 'Gagal menyetujui pengguna.')),
        );
      }
    }
  }

  List<dynamic> get _filteredUsers {
    return _allUsers.where((u) {
      // Search
      final name = (u['full_name'] ?? '').toLowerCase();
      final nik = (u['employee_id'] ?? '').toLowerCase();
      final dept = (u['department'] ?? '').toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      if (_searchQuery.isNotEmpty && 
          !name.contains(searchLower) && 
          !nik.contains(searchLower) && 
          !dept.contains(searchLower)) {
        return false;
      }
      
      // Filter
      final isActive = u['is_active'] == 1 || u['is_active'] == true;
      final role = (u['role'] ?? 'user').toString().toLowerCase();

      if (_selectedFilter == 'Inactive') return !isActive;
      if (_selectedFilter == 'User') return role == 'user' && isActive;
      if (_selectedFilter == 'Admin') return role == 'admin' && isActive;
      if (_selectedFilter == 'Superadmin') return role == 'superadmin' && isActive;

      return true; // Semua
    }).toList();
  }

  void _navigateToUserDetail(dynamic user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserDetailScreen(user: user)),
    );
    if (result == true) {
      _fetchUsers();
      _fetchUnapprovedUsers();
    }
  }

  void _navigateToUserForm([dynamic user]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserFormScreen(userToEdit: user)),
    );
    if (result == true) {
      _fetchUsers();
      _fetchUnapprovedUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSuperadmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Management')),
        body: const Center(
          child: Text('Akses Ditolak. Hanya Superadmin yang dapat mengakses halaman ini.', 
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ),
      );
    }

    final users = _filteredUsers;
    final filters = ['Semua', 'User', 'Admin', 'Superadmin', 'Inactive'];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                radius: 16,
                child: IconButton(
                  icon: const Icon(Icons.add, size: 16, color: _blue),
                  padding: EdgeInsets.zero,
                  onPressed: () => _navigateToUserForm(),
                ),
              ),
            )
          ],
          bottom: const TabBar(
            labelColor: _blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _blue,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Daftar Pengguna'),
              Tab(text: 'Approval User'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserListTab(),
            _buildApprovalTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserListTab() {
    final users = _filteredUsers;
    final filters = ['Semua', 'User', 'Admin', 'Superadmin', 'Inactive'];

    return Column(
      children: [
        Container(
          color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: filters.map((f) {
                  final isSelected = _selectedFilter == f;
                  String label = f;
                  if (f == 'Semua') label = 'Semua (${_allUsers.length})';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = f);
                      },
                      selectedColor: _blue,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? _blue : Colors.grey.shade300),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search by name, NIK, departemen...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(child: Text('Tidak ada pengguna ditemukan.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final isActive = user['is_active'] == 1 || user['is_active'] == true;
                          final role = (user['role'] ?? 'user').toString();
                          final name = user['full_name'] ?? 'Unknown';
                          final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase() : '?';
                          final dept = user['department'] ?? 'No Dept';
                          final jabatan = user['job_title'] ?? 'Staff';
                          
                          Color avatarColor = Colors.blue;
                          if (role == 'superadmin') avatarColor = Colors.purple;
                          if (role == 'admin') avatarColor = Colors.orange;
                          if (!isActive) avatarColor = Colors.grey;

                          return GestureDetector(
                            onTap: () => _navigateToUserDetail(user),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: avatarColor,
                                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('$jabatan • $dept', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (!isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                          child: const Text('Inactive', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: avatarColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                          child: Text(
                                            role.toUpperCase(), 
                                            style: TextStyle(color: avatarColor, fontSize: 11, fontWeight: FontWeight.bold)
                                          ),
                                        ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Menampilkan ${users.length} dari ${_allUsers.length} pengguna', 
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            )
        ],
    );
  }

  Widget _buildApprovalTab() {
    if (_isLoadingUnapproved) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_unapprovedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Semua pengguna sudah disetujui', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _unapprovedUsers.length,
      itemBuilder: (context, index) {
        final user = _unapprovedUsers[index];
        final name = user['full_name'] ?? 'Unknown';
        final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase() : '?';
        final dept = user['department'] ?? '-';
        final email = user['personal_email'] ?? user['email'] ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: Text(initials, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('NIK: ${user['employee_id'] ?? '-'}'),
                Text('Email: $email'),
                Text('Dept: $dept'),
              ],
            ),
            isThreeLine: true,
            trailing: FilledButton(
              onPressed: () => _approveUser(user['id'].toString()),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

// ── User Detail Screen ──────────────────────────────────────────────────────

class UserDetailScreen extends StatefulWidget {
  final dynamic user;
  const UserDetailScreen({super.key, required this.user});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  static const _blue = Color(0xFF3F51B5);
  late String _selectedRole;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = (widget.user['role'] ?? 'user').toString().toLowerCase();
    _isActive = widget.user['is_active'] == 1 || widget.user['is_active'] == true;
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.put('/admin/users/${widget.user['id']}', {
        'role': _selectedRole,
        'is_active': _isActive ? 1 : 0,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan berhasil disimpan')));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.errorMessage ?? 'Gagal menyimpan')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengguna', style: TextStyle(color: Colors.red)),
        content: const Text('Yakin ingin menghapus pengguna ini secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final response = await ApiService.delete('/admin/users/${widget.user['id']}');
        if (mounted) {
          if (response.success) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengguna dihapus')));
            Navigator.pop(context, true);
          } else {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.errorMessage ?? 'Gagal menghapus')));
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user['full_name'] ?? 'Unknown';
    final initials = name.isNotEmpty ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase() : '?';
    final dept = widget.user['department'] ?? 'No Dept';
    final jabatan = widget.user['job_title'] ?? 'Staff';
    final role = (widget.user['role'] ?? 'user').toString().toLowerCase();

    Color avatarColor = Colors.green;
    if (role == 'superadmin') avatarColor = Colors.purple;
    if (role == 'admin') avatarColor = Colors.orange;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('User Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserFormScreen(userToEdit: widget.user)),
              );
              if (result == true) Navigator.pop(context, true);
            },
            tooltip: 'Edit Data',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteUser,
            tooltip: 'Hapus User',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: avatarColor,
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text('$jabatan • $dept', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                              child: Text(role.toUpperCase(), style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isActive ? Colors.green.shade50 : Colors.red.shade50, 
                                borderRadius: BorderRadius.circular(12)
                              ),
                              child: Text(_isActive ? 'Aktif' : 'Inaktif', 
                                style: TextStyle(color: _isActive ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ROLE & ACCESS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _buildInfoRow('Role', Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text(role.toUpperCase(), style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                        )),
                        const Divider(height: 1),
                        _buildInfoRow('Departemen', Text(dept, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const Divider(height: 1),
                        _buildInfoRow('Jabatan', Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text(jabatan, style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('CHANGE ROLE', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        _buildRoleOption('user', 'Akses dasar'),
                        const Divider(height: 1),
                        _buildRoleOption('admin', 'Kelola data & approve'),
                        const Divider(height: 1),
                        _buildRoleOption('superadmin', 'Akses penuh sistem'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _isActive = !_isActive);
                        },
                        icon: Icon(_isActive ? Icons.lock_outline : Icons.lock_open, color: Colors.grey.shade700, size: 18),
                        label: Text(_isActive ? 'Deactivate' : 'Activate', style: TextStyle(color: Colors.grey.shade700)),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, size: 18),
                        label: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          value,
        ],
      ),
    );
  }

  Widget _buildRoleOption(String roleValue, String subtitle) {
    String title = roleValue[0].toUpperCase() + roleValue.substring(1);
    final isSelected = _selectedRole == roleValue;
    return RadioListTile<String>(
      value: roleValue,
      groupValue: _selectedRole,
      onChanged: (val) => setState(() => _selectedRole = val!),
      activeColor: Colors.orange.shade700,
      title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.orange.shade800 : Colors.black87)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      secondary: isSelected ? Icon(Icons.circle, color: Colors.orange.shade700, size: 10) : Icon(Icons.circle, color: Colors.grey.shade300, size: 10),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

// ── User Form Screen (CRUD Create/Edit) ─────────────────────────────────────

class UserFormScreen extends StatefulWidget {
  final dynamic userToEdit;
  const UserFormScreen({super.key, this.userToEdit});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  static const _blue = Color(0xFF1A56C4);
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _nikCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _workEmailCtrl;
  late TextEditingController _hpCtrl;
  late TextEditingController _jabatanCtrl;
  late TextEditingController _simperCtrl;
  late TextEditingController _passwordCtrl;
  
  String _tipeAfiliasi = 'Owner';
  String? _selectedPerusahaan;
  String? _selectedPerusahaanKontraktor;
  String? _selectedSubKontraktor;
  String? _selectedDept;
  String _role = 'user';
  bool _isLoading = false;

  List<String> _ownerList = [];
  List<String> _kontraktorList = [];
  List<String> _subkontraktorList = [];

  final List<String> _departemenList = [
    'HSE',
    'IT',
    'Operasional',
    'Produksi',
    'Keuangan',
    'HR',
    'Maintenance',
    'Logistik',
  ];

  Future<void> _fetchCompanies() async {
    try {
      final owners = await CompanyService.getCompanies(category: 'owner', active: true);
      final contractors = await CompanyService.getCompanies(category: 'kontraktor', active: true);
      final subContractors = await CompanyService.getCompanies(category: 'subkontraktor', active: true);

      if (mounted) {
        setState(() {
          _ownerList = owners.map((e) => e.name).toList();
          _kontraktorList = contractors.map((e) => e.name).toList();
          _subkontraktorList = subContractors.map((e) => e.name).toList();

          // Ensure edited user's values are in the list if not present
          final p = widget.userToEdit?['company'] ?? '';
          if (p.isNotEmpty && !_ownerList.contains(p)) {
            _ownerList.add(p);
            _selectedPerusahaan = p;
          } else if (p.isNotEmpty) {
            _selectedPerusahaan = p;
          }

          final pk = widget.userToEdit?['perusahaan_kontraktor'] ?? '';
          if (pk.isNotEmpty && !_kontraktorList.contains(pk)) {
            _kontraktorList.add(pk);
            _selectedPerusahaanKontraktor = pk;
          } else if (pk.isNotEmpty) {
            _selectedPerusahaanKontraktor = pk;
          }

          final sk = widget.userToEdit?['sub_kontraktor'] ?? '';
          if (sk.isNotEmpty && !_subkontraktorList.contains(sk)) {
            _subkontraktorList.add(sk);
            _selectedSubKontraktor = sk;
          } else if (sk.isNotEmpty) {
            _selectedSubKontraktor = sk;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching companies: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _nameCtrl = TextEditingController(text: widget.userToEdit?['full_name'] ?? '');
    _nikCtrl = TextEditingController(text: widget.userToEdit?['employee_id'] ?? '');
    _emailCtrl = TextEditingController(text: widget.userToEdit?['personal_email'] ?? widget.userToEdit?['email'] ?? '');
    _workEmailCtrl = TextEditingController(text: widget.userToEdit?['work_email'] ?? '');
    _hpCtrl = TextEditingController(text: widget.userToEdit?['phone_number'] ?? '');
    _jabatanCtrl = TextEditingController(text: widget.userToEdit?['position'] ?? widget.userToEdit?['job_title'] ?? '');
    _simperCtrl = TextEditingController(text: widget.userToEdit?['simper'] ?? '');
    _passwordCtrl = TextEditingController();
    
    _tipeAfiliasi = widget.userToEdit?['tipe_afiliasi'] ?? 'Owner';
    if (_tipeAfiliasi == 'Sub-Kontraktor') _tipeAfiliasi = 'Sub-Kont.';

    final dept = widget.userToEdit?['department'] ?? '';
    if (_departemenList.contains(dept)) _selectedDept = dept;
    else if (dept.isNotEmpty) { _departemenList.add(dept); _selectedDept = dept; }

    if (widget.userToEdit != null) {
      _role = (widget.userToEdit['role'] ?? 'user').toString().toLowerCase();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'full_name': _nameCtrl.text.trim(),
      'employee_id': _nikCtrl.text.trim(),
      'personal_email': _emailCtrl.text.trim(),
      'work_email': _workEmailCtrl.text.trim(),
      'phone_number': _hpCtrl.text.trim(),
      'department': _selectedDept ?? '',
      'position': _jabatanCtrl.text.trim(),
      'company': _selectedPerusahaan ?? '',
      'tipe_afiliasi': _tipeAfiliasi == 'Sub-Kont.' ? 'Sub-Kontraktor' : _tipeAfiliasi,
      'perusahaan_kontraktor': _selectedPerusahaanKontraktor,
      'sub_kontraktor': _selectedSubKontraktor,
      'simper': _simperCtrl.text.trim(),
      'role': _role,
    };

    if (_passwordCtrl.text.isNotEmpty) {
      data['password'] = _passwordCtrl.text;
    }

    try {
      dynamic response;
      if (widget.userToEdit != null) {
        response = await ApiService.put('/admin/users/${widget.userToEdit['id']}', data);
      } else {
        response = await ApiService.post('/admin/users', data);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.userToEdit == null ? 'Pengguna dibuat' : 'Pengguna diperbarui')));
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.errorMessage ?? 'Gagal menyimpan')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.userToEdit != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Pengguna' : 'Tambah Pengguna', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField('Nama Lengkap', _nameCtrl, required: true),
              _buildField('NIK / Employee ID', _nikCtrl, required: true),
              _buildField('Nomor HP', _hpCtrl, required: true, isPhone: true),
              _buildField('Email Pribadi', _emailCtrl, required: true, isEmail: true),
              _buildField('Email Kantor (Opsional)', _workEmailCtrl, isEmail: true),
              if (!isEdit) _buildField('Password', _passwordCtrl, required: true, obscure: true)
              else _buildField('Password (Isi untuk mengganti)', _passwordCtrl, obscure: true),
              
              const Divider(height: 32),
              
              _buildAfiliasiRow(),
              _buildDropdown('Perusahaan Owner', _selectedPerusahaan, _ownerList, (v) => setState(() => _selectedPerusahaan = v), required: true),
              
              if (_tipeAfiliasi == 'Kontraktor' || _tipeAfiliasi == 'Sub-Kont.')
                _buildDropdown('Perusahaan Kontraktor', _selectedPerusahaanKontraktor, _kontraktorList, (v) => setState(() => _selectedPerusahaanKontraktor = v)),
                
              if (_tipeAfiliasi == 'Sub-Kont.')
                _buildDropdown('Sub-Kontraktor', _selectedSubKontraktor, _subkontraktorList, (v) => setState(() => _selectedSubKontraktor = v)),

              const Divider(height: 32),

              _buildDropdown('Departemen', _selectedDept, _departemenList, (v) => setState(() => _selectedDept = v), required: true),
              _buildField('Jabatan / Posisi', _jabatanCtrl, required: true),
              _buildField('SIMPER / KIMPER (Opsional)', _simperCtrl),
              
              const SizedBox(height: 16),
              const Text('Role Akses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('User')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'superadmin', child: Text('Superadmin')),
                ],
                onChanged: (val) => setState(() => _role = val!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool required = false, bool isEmail = false, bool isPhone = false, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + (required ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            obscureText: obscure,
            keyboardType: isEmail ? TextInputType.emailAddress : (isPhone ? TextInputType.phone : TextInputType.text),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (v) {
              if (required && (v == null || v.trim().isEmpty)) return 'Wajib diisi';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + (required ? ' *' : ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
            validator: (v) {
              if (required && (v == null || v.isEmpty)) return 'Wajib dipilih';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAfiliasiRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tipe Afiliasi *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Owner', 'Kontraktor', 'Sub-Kont.'].map((type) {
                final isSelected = _tipeAfiliasi == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _tipeAfiliasi = type);
                    },
                    selectedColor: _blue,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}
