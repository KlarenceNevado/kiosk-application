import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/i_system_repository.dart';

class WebSystemRepository implements ISystemRepository {
  final _supabase = Supabase.instance.client;

  // Helper: Emits immediately, then every [interval]
  Stream<List<Map<String, dynamic>>> _pollingStream(
      Future<List<Map<String, dynamic>>> Function() fetcher,
      {Duration interval = const Duration(seconds: 15)}) async* {
    // Emit once immediately
    try {
      yield await fetcher();
    } catch (_) {
      yield <Map<String, dynamic>>[];
    }
    // Then poll periodically
    yield* Stream.periodic(interval).asyncMap((_) async {
      try {
        return await fetcher();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    });
  }

  // Cache streams so they aren't re-created on each property access
  late final Stream<List<Map<String, dynamic>>> _announcementStream =
      _pollingStream(() => fetchAnnouncements()).asBroadcastStream();

  late final Stream<List<Map<String, dynamic>>> _alertStream =
      _pollingStream(() => fetchAlerts()).asBroadcastStream();

  late final Stream<List<Map<String, dynamic>>> _scheduleStream =
      _pollingStream(() async {
        try {
          final response = await _supabase
              .from('schedules')
              .select()
              .eq('is_deleted', false);
          return List<Map<String, dynamic>>.from(response);
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      }).asBroadcastStream();

  @override
  Stream<List<Map<String, dynamic>>> get announcementStream => _announcementStream;

  @override
  Stream<List<Map<String, dynamic>>> get alertStream => _alertStream;

  @override
  Stream<List<Map<String, dynamic>>> get scheduleStream => _scheduleStream;

  @override
  Future<List<Map<String, dynamic>>> fetchAnnouncements({dynamic currentUser}) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_deleted', false)
          .eq('is_active', true)
          .order('timestamp', ascending: false);
      
      List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(response);

      if (currentUser != null) {
        final int age = currentUser.age;
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
          if (target == 'SENIORS' && age >= 60) return true;
          if (target == 'CHILDREN' && age <= 12) return true;
          return false;
        }).toList();
      }
      return filtered;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAlerts({dynamic currentUser}) async {
    try {
      final response = await _supabase
          .from('alerts')
          .select()
          .eq('is_deleted', false)
          .eq('is_active', true)
          .order('timestamp', ascending: false);
      
      List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(response);

      if (currentUser != null) {
        final int age = currentUser.age;
        filtered = filtered.where((a) {
          final target = (a['target_group'] ?? a['targetGroup'])?.toString().toUpperCase() ?? 'ALL';
          if (target == 'ALL' || target == 'BROADCAST_ALL') return true;
          if (target == 'SENIORS' && age >= 60) return true;
          if (target == 'CHILDREN' && age <= 12) return true;
          return false;
        }).toList();
      }
      return filtered;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> reactToAnnouncement(String announcementId, String emoji, String userId) async {
    try {
      final response = await _supabase.from('announcements').select('reactions').eq('id', announcementId).single();
      Map<String, dynamic> reactions = {};
      if (response['reactions'] is Map) {
        reactions = Map<String, dynamic>.from(response['reactions']);
      }
      
      List<dynamic> users = List<dynamic>.from(reactions[emoji] ?? []);
      if (users.contains(userId)) {
        users.remove(userId);
      } else {
        users.add(userId);
      }
      
      if (users.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = users;
      }

      await _supabase.from('announcements').update({'reactions': reactions}).eq('id', announcementId);
    } catch (_) {}
  }

  @override
  Future<void> syncNow({dynamic authRepo, dynamic historyRepo}) async {
    if (historyRepo != null && authRepo != null && authRepo.currentUser != null) {
      await historyRepo.loadUserHistory(authRepo.currentUser.id);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders(String userId) async => [];

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async => 1;

  @override
  Future<int> updateReminder(Map<String, dynamic> reminder) async => 1;
}
