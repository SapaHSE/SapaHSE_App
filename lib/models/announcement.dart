import 'package:intl/intl.dart';

enum AnnouncementType { normal, urgent }

class Announcement {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final bool isUrgent;
  final bool isRead;
  final String? creatorName;
  final DateTime createdAt;
  final String timeAgo;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.isUrgent = false,
    this.isRead = false,
    this.creatorName,
    required this.createdAt,
    required this.timeAgo,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      imageUrl: json['image_url'],
      isUrgent: json['is_urgent'] ?? false,
      isRead: json['is_read'] ?? false,
      creatorName: json['created_by'] != null ? json['created_by']['full_name'] : null,
      createdAt: DateTime.parse(json['created_at']),
      timeAgo: json['time_ago'] ?? '',
    );
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy, HH:mm').format(createdAt);
  }
}
