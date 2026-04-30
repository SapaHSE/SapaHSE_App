import 'package:flutter/material.dart';
import '../models/department_model.dart';
import '../services/department_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  State<DepartmentManagementScreen> createState() => _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends State<DepartmentManagementScreen> {
  static const _blue = Color(0xFF1A56C4);
  
  bool _isLoading = true;
  String? _error;
  List<DepartmentData> _departments = [];
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService.getCurrentUser();
      final departments = await DepartmentService.getDepartments();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _departments = departments;
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

  void _showForm({DepartmentData? department}) {
    final isEdit = department != null;
    final ctrl = TextEditingController(text: department?.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Department' : 'Tambah Department', 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NAMA DEPARTMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contoh: Maintenance',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                if (isEdit) {
                  await DepartmentService.updateDepartment(department.id, name);
                  _showSnack('Department berhasil diperbarui');
                } else {
                  await DepartmentService.createDepartment(name);
                  _showSnack('Department berhasil ditambahkan');
                }
                _loadInitialData();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(DepartmentData department) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
        content: Text('Yakin ingin menghapus ${department.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await DepartmentService.deleteDepartment(department.id);
                _showSnack('Department berhasil dihapus');
                _loadInitialData();
              } catch (e) {
                _showSnack(e.toString(), isError: true);
                setState(() => _isLoading = false);
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit = _currentUser?.role == 'superadmin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Department Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadInitialData, child: const Text('Coba Lagi')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _departments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final dept = _departments[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: _blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.corporate_fare, color: _blue, size: 20),
                          ),
                          title: Text(dept.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: canEdit ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                                onPressed: () => _showForm(department: dept),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _confirmDelete(dept),
                              ),
                            ],
                          ) : null,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: (canEdit && !_isLoading) ? FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Department'),
      ) : null,
    );
  }
}
