import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'storage_service.dart';
import '../models/profile_model.dart';

class ProfileService {
  // ── Get profile from API (always fresh) ──────────────────────────────────
  static Future<ProfileResult> getProfile() async {
    final response = await ApiService.get('/profile');

    if (!response.success) {
      return ProfileResult.error(
          response.errorMessage ?? 'Gagal memuat profil.',
          statusCode: response.statusCode);
    }

    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return ProfileResult.error('Respons server tidak valid.');
    }

    await StorageService.saveUser(userData);
    return ProfileResult.success(ProfileData.fromJson(userData));
  }

  // ── Get licenses from profile ────────────────────────────────────────────────────────
  static Future<LicensesResult> getLicenses() async {
    final response = await ApiService.get('/profile');
    if (!response.success) {
      return LicensesResult.error(
          response.errorMessage ?? 'Gagal memuat lisensi.');
    }
    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return LicensesResult.error('Respons server tidak valid.');
    }
    final licenses = (userData['licenses'] as List<dynamic>?)
            ?.map((l) => UserLicense.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [];
    return LicensesResult.success(licenses);
  }

  // ── Get certifications from profile ──────────────────────────────────────────────
  static Future<CertificationsResult> getCertifications() async {
    final response = await ApiService.get('/profile');
    if (!response.success) {
      return CertificationsResult.error(
          response.errorMessage ?? 'Gagal memuat sertifikasi.');
    }
    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return CertificationsResult.error('Respons server tidak valid.');
    }
    final certs = (userData['certifications'] as List<dynamic>?)
            ?.map((c) => UserCertification.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    return CertificationsResult.success(certs);
  }

  // ── Get medicals from profile ──────────────────────────────────────────────────────
  static Future<MedicalsResult> getMedicals() async {
    final response = await ApiService.get('/profile');
    if (!response.success) {
      return MedicalsResult.error(
          response.errorMessage ?? 'Gagal memuat data medis.');
    }
    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return MedicalsResult.error('Respons server tidak valid.');
    }
    final medicals = (userData['medicals'] as List<dynamic>?)
            ?.map((m) => UserMedical.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return MedicalsResult.success(medicals);
  }

  // ── Update profile (full_name, email, phone, position, department, alamat, photo) ──────────────────
  static Future<ProfileResult> updateProfile({
    String? fullName,
    String? personalEmail,
    String? workEmail,
    String? phoneNumber,
    String? position,
    String? department,
    String? alamat,
    String? tipeAfiliasi,
    String? company,
    String? perusahaanKontraktor,
    String? subKontraktor,
    XFile? imageFile,
  }) async {
    final fields = <String, dynamic>{};
    if (fullName != null) fields['full_name'] = fullName;
    if (personalEmail != null) fields['personal_email'] = personalEmail;
    if (workEmail != null) fields['work_email'] = workEmail;
    if (phoneNumber != null) fields['phone_number'] = phoneNumber;
    if (position != null) fields['position'] = position;
    if (department != null) fields['department'] = department;
    if (alamat != null) fields['alamat'] = alamat;
    if (tipeAfiliasi != null) fields['tipe_afiliasi'] = tipeAfiliasi;
    if (company != null) fields['company'] = company;
    if (perusahaanKontraktor != null) fields['perusahaan_kontraktor'] = perusahaanKontraktor;
    if (subKontraktor != null) fields['sub_kontraktor'] = subKontraktor;

    ApiResponse response;
    if (imageFile != null) {
      final files = <http.MultipartFile>[];
      files.add(
          await http.MultipartFile.fromPath('profile_photo', imageFile.path));
      response = await ApiService.postMultipart('/profile', fields, files);
    } else {
      response = await ApiService.post('/profile', fields);
    }

    if (!response.success) {
      return ProfileResult.error(
          response.errorMessage ?? 'Gagal menyimpan profil.',
          statusCode: response.statusCode);
    }

    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return ProfileResult.error('Respons server tidak valid.');
    }

    await StorageService.saveUser(userData);
    return ProfileResult.success(ProfileData.fromJson(userData));
  }

  // ── Update Medical ──────────────────────────────────────────────────────────
  static Future<ProfileResult> updateMedical({
    String? bloodType,
    String? height,
    String? weight,
    String? bloodPressure,
    String? allergies,
    String? lastMedication,
    String? currentMedication,
    String? currentIllness,
  }) async {
    final response = await ApiService.post('/profile/medical', {
      'blood_type': bloodType,
      'height': height,
      'weight': weight,
      'blood_pressure': bloodPressure,
      'allergies': allergies,
      'last_medication': lastMedication,
      'current_medication': currentMedication,
      'current_illness': currentIllness,
    });

    if (!response.success) {
      return ProfileResult.error(
          response.errorMessage ?? 'Gagal menyimpan data medis.');
    }

    final userData = response.data['data'] as Map<String, dynamic>?;
    if (userData == null) {
      return ProfileResult.error('Respons server tidak valid.');
    }

    await StorageService.saveUser(userData);
    return ProfileResult.success(ProfileData.fromJson(userData));
  }

  // ── Change password ───────────────────────────────────────────────────────
  static Future<SimpleResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      return SimpleResult.error('Password baru dan konfirmasi tidak cocok.');
    }
    if (newPassword.length < 8) {
      return SimpleResult.error('Password baru minimal 8 karakter.');
    }

    final response = await ApiService.post('/profile/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
      'new_password_confirmation': confirmPassword,
    });

    if (!response.success) {
      return SimpleResult.error(
          response.errorMessage ?? 'Gagal mengubah password.');
    }

    return SimpleResult.success(
        response.data['message'] ?? 'Password berhasil diubah.');
  }

  // ── Add License ─────────────────────────────────────────────────────────────
  static Future<SimpleResult> addLicense({
    required String name,
    required String licenseNumber,
    String? issuer,
    String? obtainedAt,
    String? expiredAt,
    String status = 'active',
    XFile? imageFile,
  }) async {
    final fields = {
      'name': name,
      'license_number': licenseNumber,
      'issuer': issuer ?? '',
      'obtained_at': obtainedAt ?? '',
      'expired_at': expiredAt ?? '',
      'status': status,
    };

    final files = <http.MultipartFile>[];
    if (imageFile != null) {
      files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    }

    final response = await ApiService.postMultipart('/profile/license', fields, files);

    if (!response.success) {
      return SimpleResult.error(response.errorMessage ?? 'Gagal menambah lisensi.');
    }
    return SimpleResult.success('Lisensi berhasil ditambahkan.');
  }

  static Future<SimpleResult> updateLicense({
    required String id,
    String? name,
    String? licenseNumber,
    String? issuer,
    String? obtainedAt,
    String? expiredAt,
    String? status,
    XFile? imageFile,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['name'] = name;
    if (licenseNumber != null) fields['license_number'] = licenseNumber;
    if (issuer != null) fields['issuer'] = issuer;
    if (obtainedAt != null) fields['obtained_at'] = obtainedAt;
    if (expiredAt != null) fields['expired_at'] = expiredAt;
    if (status != null) fields['status'] = status;

    final files = <http.MultipartFile>[];
    if (imageFile != null) {
      files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    }

    fields['_method'] = 'PUT';
    final response =
        await ApiService.postMultipart('/profile/license/$id', fields, files);

    if (!response.success) {
      return SimpleResult.error(
          response.errorMessage ?? 'Gagal memperbarui lisensi.');
    }
    return SimpleResult.success('Lisensi berhasil diperbarui.');
  }

  // ── Add Certification ───────────────────────────────────────────────────────
  static Future<SimpleResult> addCertification({
    required String name,
    String? certificationNumber,
    required String issuer,
    String? obtainedAt,
    String? expiredAt,
    String status = 'active',
    XFile? imageFile,
  }) async {
    final fields = {
      'name': name,
      'certification_number': certificationNumber ?? '',
      'issuer': issuer,
      'obtained_at': obtainedAt ?? '',
      'expired_at': expiredAt ?? '',
      'status': status,
    };

    final files = <http.MultipartFile>[];
    if (imageFile != null) {
      files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    }

    final response = await ApiService.postMultipart('/profile/certification', fields, files);

    if (!response.success) {
      return SimpleResult.error(response.errorMessage ?? 'Gagal menambah sertifikasi.');
    }
    return SimpleResult.success('Sertifikasi berhasil ditambahkan.');
  }

  static Future<SimpleResult> updateCertification({
    required String id,
    String? name,
    String? certificationNumber,
    String? issuer,
    String? obtainedAt,
    String? expiredAt,
    String? status,
    XFile? imageFile,
  }) async {
    final fields = <String, String>{};
    if (name != null) fields['name'] = name;
    if (certificationNumber != null) fields['certification_number'] = certificationNumber;
    if (issuer != null) fields['issuer'] = issuer;
    if (obtainedAt != null) fields['obtained_at'] = obtainedAt;
    if (expiredAt != null) fields['expired_at'] = expiredAt;
    if (status != null) fields['status'] = status;

    final files = <http.MultipartFile>[];
    if (imageFile != null) {
      files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    }

    fields['_method'] = 'PUT';
    final response =
        await ApiService.postMultipart('/profile/certification/$id', fields, files);

    if (!response.success) {
      return SimpleResult.error(
          response.errorMessage ?? 'Gagal memperbarui sertifikasi.');
    }
    return SimpleResult.success('Sertifikasi berhasil diperbarui.');
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RESULT WRAPPERS
// ══════════════════════════════════════════════════════════════════════════════

class ProfileResult {
  final bool success;
  final ProfileData? data;
  final String? errorMessage;
  final int? statusCode;

  ProfileResult._(
      {required this.success, this.data, this.errorMessage, this.statusCode});

  factory ProfileResult.success(ProfileData data) =>
      ProfileResult._(success: true, data: data);

  factory ProfileResult.error(String message, {int? statusCode}) =>
      ProfileResult._(
          success: false, errorMessage: message, statusCode: statusCode);
}

class LicensesResult {
  final bool success;
  final List<UserLicense> licenses;
  final String? errorMessage;

  LicensesResult._(
      {required this.success, this.licenses = const [], this.errorMessage});

  factory LicensesResult.success(List<UserLicense> licenses) =>
      LicensesResult._(success: true, licenses: licenses);

  factory LicensesResult.error(String message) =>
      LicensesResult._(success: false, errorMessage: message);
}

class CertificationsResult {
  final bool success;
  final List<UserCertification> certifications;
  final String? errorMessage;

  CertificationsResult._(
      {required this.success,
      this.certifications = const [],
      this.errorMessage});

  factory CertificationsResult.success(
          List<UserCertification> certifications) =>
      CertificationsResult._(success: true, certifications: certifications);

  factory CertificationsResult.error(String message) =>
      CertificationsResult._(success: false, errorMessage: message);
}

class MedicalsResult {
  final bool success;
  final List<UserMedical> medicals;
  final String? errorMessage;

  MedicalsResult._(
      {required this.success, this.medicals = const [], this.errorMessage});

  factory MedicalsResult.success(List<UserMedical> medicals) =>
      MedicalsResult._(success: true, medicals: medicals);

  factory MedicalsResult.error(String message) =>
      MedicalsResult._(success: false, errorMessage: message);
}

class SimpleResult {
  final bool success;
  final String message;

  SimpleResult._({required this.success, required this.message});

  factory SimpleResult.success(String message) =>
      SimpleResult._(success: true, message: message);

  factory SimpleResult.error(String message) =>
      SimpleResult._(success: false, message: message);
}
