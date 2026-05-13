import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AnnouncementService {
  static final ChangeNotifier refreshNotifier = ChangeNotifier();

  static Future<List<Announcement>> getAnnouncements({int page = 1}) async {
    try {
      final response = await ApiService.get('/announcements?page=$page');
      if (response.success) {
        final List data = response.data['data'];
        return data.map((json) => Announcement.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }

  static Future<bool> createAnnouncement({
    required String title,
    required String body,
    required bool isUrgent,
    File? image,
  }) async {
    try {
      final token = await StorageService.getToken();
      final uri = Uri.parse('${ApiService.baseUrl}/announcements');
      
      var request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.fields['title'] = title;
      request.fields['body'] = body;
      request.fields['is_urgent'] = isUrgent ? '1' : '0';

      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      final bodyData = jsonDecode(response.body);
      final success = response.statusCode == 201 && bodyData['status'] == 'success';
      if (success) {
        // Notify listeners to refresh UI
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        refreshNotifier.notifyListeners();
      }
      return success;
    } catch (e) {
      print('Error creating announcement: $e');
      return false;
    }
  }

  static Future<bool> markAllAsRead() async {
    try {
      final response = await ApiService.patch('/announcements/read-all', {});
      return response.success;
    } catch (e) {
      return false;
    }
  }
}
