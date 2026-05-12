import '../services/api_service.dart';

class ApprovalService {
  static Future<ApiResponse> getPendingDocuments() async {
    return await ApiService.get('/admin/approvals/documents');
  }

  static Future<ApiResponse> approveLicense(String id) async {
    return await ApiService.post('/admin/licenses/$id/verify', {'is_verified': true});
  }

  static Future<ApiResponse> approveCertification(String id) async {
    return await ApiService.post('/admin/certifications/$id/verify', {'is_verified': true});
  }

  static Future<ApiResponse> rejectLicense(String id) async {
    return await ApiService.delete('/admin/licenses/$id/reject');
  }

  static Future<ApiResponse> rejectCertification(String id) async {
    return await ApiService.delete('/admin/certifications/$id/reject');
  }
}
