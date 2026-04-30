import 'api_service.dart';
import '../models/department_model.dart';

class DepartmentService {
  static Future<List<DepartmentData>> getDepartments() async {
    final response = await ApiService.get('/departments');
    if (response.success && response.data['data'] != null) {
      final list = response.data['data'] as List;
      return list.map((e) => DepartmentData.fromJson(e)).toList();
    }
    throw Exception(response.errorMessage ?? 'Gagal mengambil data department');
  }

  static Future<DepartmentData> createDepartment(String name) async {
    final response = await ApiService.post('/departments', {'name': name});
    if (response.success && response.data['data'] != null) {
      return DepartmentData.fromJson(response.data['data']);
    }
    throw Exception(response.errorMessage ?? 'Gagal menambah department');
  }

  static Future<DepartmentData> updateDepartment(int id, String name) async {
    final response = await ApiService.put('/departments/$id', {'name': name});
    if (response.success && response.data['data'] != null) {
      return DepartmentData.fromJson(response.data['data']);
    }
    throw Exception(response.errorMessage ?? 'Gagal mengupdate department');
  }

  static Future<void> deleteDepartment(int id) async {
    final response = await ApiService.delete('/departments/$id');
    if (!response.success) {
      throw Exception(response.errorMessage ?? 'Gagal menghapus department');
    }
  }
}
