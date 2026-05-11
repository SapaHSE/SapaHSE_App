import 'api_service.dart';

class ViolationService {
  static Future<ViolationListResult> getViolations({int page = 1, String? search}) async {
    String url = '/admin/violations?page=$page';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }

    final response = await ApiService.get(url);
    if (!response.success) {
      return ViolationListResult.error(response.errorMessage ?? 'Gagal memuat data pelanggaran');
    }

    return ViolationListResult.success(
      (response.data['data']['data'] as List<dynamic>)
          .map((v) => ViolationItem.fromJson(v))
          .toList(),
      currentPage: response.data['data']['current_page'],
      lastPage: response.data['data']['last_page'],
      total: response.data['data']['total'],
    );
  }

  static Future<ApiResponse> storeViolation(String userId, Map<String, dynamic> data) async {
    return await ApiService.post('/admin/users/$userId/violations', data);
  }

  static Future<ApiResponse> updateViolation(String violationId, Map<String, dynamic> data) async {
    return await ApiService.put('/admin/violations/$violationId', data);
  }

  static Future<ApiResponse> deleteViolation(String violationId) async {
    return await ApiService.delete('/admin/violations/$violationId');
  }
}

class ViolationListResult {
  final bool success;
  final String? message;
  final List<ViolationItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  ViolationListResult.success(this.items, {this.currentPage = 1, this.lastPage = 1, this.total = 0})
      : success = true,
        message = null;

  ViolationListResult.error(this.message)
      : success = false,
        items = [],
        currentPage = 1,
        lastPage = 1,
        total = 0;
}

class ViolationItem {
  final String id;
  final String title;
  final String? location;
  final String dateOfViolation;
  final String? expiredAt;
  final String status;
  final String? sanction;
  final Map<String, dynamic> user;

  ViolationItem({
    required this.id,
    required this.title,
    this.location,
    required this.dateOfViolation,
    this.expiredAt,
    required this.status,
    this.sanction,
    required this.user,
  });

  factory ViolationItem.fromJson(Map<String, dynamic> json) {
    return ViolationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      location: json['location']?.toString(),
      dateOfViolation: json['date_of_violation']?.toString() ?? '',
      expiredAt: json['expired_at']?.toString(),
      status: json['status']?.toString() ?? 'Aktif',
      sanction: json['sanction']?.toString(),
      user: json['user'] as Map<String, dynamic>? ?? {},
    );
  }
}
