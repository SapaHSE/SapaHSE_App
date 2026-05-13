import 'api_service.dart';
import '../models/approval_item.dart';

class ApprovalService {
  /// Fetch all pending approvals for superadmin
  static Future<List<ApprovalItem>> getPendingApprovals() async {
    final response = await ApiService.get('/approvals');
    
    if (!response.success) {
      return [];
    }

    final List<dynamic> data = (response.data is Map && response.data['data'] != null) 
        ? response.data['data'] 
        : [];
    return data.map((json) => ApprovalItem.fromJson(json)).toList();
  }

  /// Fetch pending documents filtered by type (license/certification)
  static Future<List<dynamic>> getPendingDocuments(String type) async {
    final list = await getPendingApprovals();
    // Filter based on type from the unified list
    if (type == 'license') {
      return list.where((item) => item.type == ApprovalType.license).toList();
    } else if (type == 'certification') {
      return list.where((item) => item.type == ApprovalType.certification).toList();
    }
    return list;
  }

  /// Approve a request (Generic)
  static Future<bool> approve(String id, String type) async {
    final response = await ApiService.post('/approvals/approve', {
      'id': id,
      'type': type,
    });
    return response.success;
  }

  /// Specialized approve for licenses
  static Future<bool> approveLicense(String id) => approve(id, 'license');

  /// Specialized approve for certifications
  static Future<bool> approveCertification(String id) => approve(id, 'certification');

  /// Reject a request (Generic)
  static Future<bool> reject(String id, String type, {String? reason}) async {
    final response = await ApiService.post('/approvals/reject', {
      'id': id,
      'type': type,
      'reason': reason,
    });
    return response.success;
  }

  /// Specialized reject for licenses
  static Future<bool> rejectLicense(String id, {String? reason}) => reject(id, 'license', reason: reason);

  /// Specialized reject for certifications
  static Future<bool> rejectCertification(String id, {String? reason}) => reject(id, 'certification', reason: reason);
}
