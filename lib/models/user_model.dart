/// Matches the formatUser() response from Laravel's AuthController
class UserModel {
  final String id;
  final String? employeeId;
  final String fullName;
  final String? personalEmail;
  final String? workEmail;
  final String? phoneNumber;
  final String? position;
  final String? department;
  final String? company;
  final String? profilePhoto;
  final String role;
  final bool isActive;

  const UserModel({
    required this.id,
    this.employeeId,
    required this.fullName,
    this.personalEmail,
    this.workEmail,
    this.phoneNumber,
    this.position,
    this.department,
    this.company,
    this.profilePhoto,
    required this.role,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      personalEmail: json['personal_email']?.toString(),
      workEmail: json['work_email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      position: json['position']?.toString(),
      department: json['department']?.toString(),
      company: json['company']?.toString(),
      profilePhoto: json['profile_photo']?.toString(),
      role: json['role']?.toString() ?? 'user',
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['is_active'] == '1',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employee_id': employeeId,
        'full_name': fullName,
        'personal_email': personalEmail,
        'work_email': workEmail,
        'phone_number': phoneNumber,
        'position': position,
        'department': department,
        'company': company,
        'profile_photo': profilePhoto,
        'role': role,
        'is_active': isActive ? 1 : 0,
      };

  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get isUser => role == 'user';
}
