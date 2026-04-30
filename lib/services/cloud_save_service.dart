import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// ── Model: Draft Laporan ──────────────────────────────────────────────────────
enum DraftType { hazard, inspection }

class ReportDraft {
  final String id;
  final DraftType type;
  final String title;
  final Map<String, dynamic> data; // all form fields
  final DateTime createdAt;
  bool isSyncing;

  ReportDraft({
    required this.id,
    required this.type,
    required this.title,
    required this.data,
    required this.createdAt,
    this.isSyncing = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReportDraft.fromJson(Map<String, dynamic> json) => ReportDraft(
        id: json['id'] as String,
        type: DraftType.values.firstWhere((e) => e.name == json['type']),
        title: json['title'] as String,
        data: Map<String, dynamic>.from(json['data'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

// ── Service ───────────────────────────────────────────────────────────────────
class CloudSaveService {
  static const _prefKey = 'cloud_save_drafts';
  static final CloudSaveService instance = CloudSaveService._();
  CloudSaveService._();

  // ── Connectivity ──────────────────────────────────────────────────────────
  static bool? _lastOnlineStatus;
  static DateTime? _lastCheckTime;

  /// Returns true if device currently has internet access.
  /// Optimized to be non-blocking and avoid UI freezes.
  static Future<bool> isOnline() async {
    // 1. Quick check: If we checked very recently, return cached status
    if (_lastOnlineStatus != null && _lastCheckTime != null) {
      if (DateTime.now().difference(_lastCheckTime!) < const Duration(seconds: 5)) {
        return _lastOnlineStatus!;
      }
    }

    try {
      // 2. Check basic connectivity first (Wifi/Mobile data)
      final results = await Connectivity().checkConnectivity();
      
      if (results.isEmpty || (results.length == 1 && results.contains(ConnectivityResult.none))) {
        _updateCache(false);
        return false;
      }

      // 3. For Web, basic connectivity is enough
      if (kIsWeb) {
        _updateCache(true);
        return true;
      }

      // 4. For Mobile, instead of blocking DNS lookup, we'll assume online 
      // if basic connectivity is active. The actual API call will handle 
      // the real internet check. This prevents UI freezes.
      _updateCache(true);
      return true;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false;
    }
  }

  static void _updateCache(bool status) {
    _lastOnlineStatus = status;
    _lastCheckTime = DateTime.now();
  }

  /// Stream of connectivity changes (for real-time UI updates).
  Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;

  // ── CRUD ──────────────────────────────────────────────────────────────────
  Future<List<ReportDraft>> getDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    
    final List<ReportDraft> validDrafts = [];
    for (final e in raw) {
      try {
        validDrafts.add(ReportDraft.fromJson(jsonDecode(e) as Map<String, dynamic>));
      } catch (err) {
        // Abaikan data draft lama yang korup atau tidak sesuai struktur model terbaru
        debugPrint('Failed to parse draft, skipping: $err');
      }
    }
    
    validDrafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return validDrafts;
  }

  Future<void> saveDraft(ReportDraft draft) async {
    final drafts = await getDrafts();
    // Replace if same id, otherwise prepend
    final idx = drafts.indexWhere((d) => d.id == draft.id);
    if (idx >= 0) {
      drafts[idx] = draft;
    } else {
      drafts.insert(0, draft);
    }
    await _persist(drafts);
  }

  Future<void> deleteDraft(String id) async {
    final drafts = await getDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _persist(drafts);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  Future<int> getDraftCount() async {
    final drafts = await getDrafts();
    return drafts.length;
  }

  Future<void> _persist(List<ReportDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = drafts.map((d) => jsonEncode(d.toJson())).toList();
    await prefs.setStringList(_prefKey, raw);
  }

  // ── Sync ─────────────────────────────────────────────────────────────────
  /// Tries to upload all pending drafts. Calls [onEach] per draft with result.
  Future<void> syncAll({
    required Future<bool> Function(ReportDraft draft) uploadFn,
    void Function(ReportDraft draft, bool success)? onEach,
  }) async {
    if (!await isOnline()) return;
    final drafts = await getDrafts();
    for (final draft in drafts) {
      try {
        final ok = await uploadFn(draft);
        if (ok) {
          await deleteDraft(draft.id);
        }
        onEach?.call(draft, ok);
      } catch (_) {
        onEach?.call(draft, false);
      }
    }
  }
}
