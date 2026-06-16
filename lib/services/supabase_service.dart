import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver.dart';
import '../models/transfer_history.dart';
import '../models/activity_log.dart';

class SupabaseService {
  static Future<void> init() async {
    await Supabase.initialize(
      url: 'https://jydphzqoctdhfoduxtel.supabase.co',
      anonKey: 'sb_publishable_WpGoSD5GlJ4iGBi0z7mspQ_x-dvNJIm',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Drivers
  static Future<List<Driver>> fetchDrivers() async {
    final response = await client
        .from('drivers')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => Driver.fromJson(json)).toList();
  }

  static Stream<List<Driver>> driversStream() {
    return client
        .from('drivers')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((json) => Driver.fromJson(json)).toList());
  }

  static Future<void> addDriver(Map<String, dynamic> driverData) async {
    try {
      await client.from('drivers').insert(driverData);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw 'ይህ መረጃ (ስልክ፣ ሰሌዳ ወይም ፋይዳ) አስቀድሞ ተመዝግቧል።';
      }
      rethrow;
    }
  }

  static Future<void> updateDriver(String id, Map<String, dynamic> updates) async {
    await client.from('drivers').update(updates).eq('id', id);
  }

  static Future<void> bulkUpdateDriversMadiya(List<String> ids, String targetMadiya) async {
    await client.from('drivers').update({'madiya': targetMadiya}).inFilter('id', ids);
  }

  static Future<Driver?> verifyMadiyaQueueByQR(String qrData) async {
    // We assume qrData is either the ID or the Plate Number
    final response = await client
        .from('drivers')
        .select()
        .or('id.eq.$qrData,plate.eq.${qrData.toUpperCase()}')
        .maybeSingle();

    if (response != null) {
      final driver = Driver.fromJson(response);
      // Update status to 'In Progress' upon verification
      await updateDriver(driver.id, {'live_status': 'In Progress'});
      return driver;
    }
    return null;
  }

  // Transfer History
  static Future<List<TransferHistory>> fetchTransferHistory() async {
    final response = await client
        .from('transfer_history')
        .select()
        .order('transferred_at', ascending: false);
    return (response as List).map((json) => TransferHistory.fromJson(json)).toList();
  }

  static Stream<List<TransferHistory>> transferHistoryStream() {
    return client
        .from('transfer_history')
        .stream(primaryKey: ['id'])
        .order('transferred_at', ascending: false)
        .map((data) => data.map((json) => TransferHistory.fromJson(json)).toList());
  }

  static Future<void> addTransferRecord(Map<String, dynamic> record) async {
    // Synchronize field names with updated schema cache
    // Ensuring driver_name and plate are explicitly mapped from the incoming record
    final Map<String, dynamic> historyData = {
      'driver_id': record['driver_id'],
      'driver_name': record['driver_name'] ?? 'Unknown',
      'plate': record['plate'] ?? 'Unknown',
      'from_madiya': record['from_madiya'],
      'to_madiya': record['to_madiya'],
      'transferred_by': record['transferred_by'],
    };

    await client.from('transfer_history').insert(historyData);

    // Also insert into 'transfers' table as per user request
    try {
      await client.from('transfers').insert({
        'driver_name': record['driver_name'] ?? 'Unknown',
        'plate': record['plate'] ?? 'Unknown',
        'from_station': record['from_madiya'],
        'to_station': record['to_madiya'],
      });
    } catch (e) {
      print("Error inserting into transfers table: $e");
    }
  }

  // Activity Logs Stream
  static Stream<List<ActivityLog>> activityLogsStream() {
    return client
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => ActivityLog.fromJson(json)).toList());
  }

  // Announcements
  static Future<List<Map<String, dynamic>>> fetchAnnouncements() async {
    final response = await client
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Stream<List<Map<String, dynamic>>> announcementsStream() {
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // Statistics
  static Future<Map<String, int>> fetchStatistics() async {
    final driversCount = await client.from('drivers').count(CountOption.exact);
    final pendingCount = await client.from('drivers').count(CountOption.exact).eq('status', 'Pending');
    final transfersCount = await client.from('transfer_history').count(CountOption.exact);

    return {
      'total_drivers': driversCount,
      'pending_requests': pendingCount,
      'total_transfers': transfersCount,
    };
  }

  // Activity Logs
  static Future<void> logActivity(ActivityLog log) async {
    try {
      await client.from('activity_logs').insert(log.toJson());
    } catch (e) {
      print("Logging error: $e");
    }
  }

  static Future<List<ActivityLog>> fetchActivityLogs() async {
    final response = await client
        .from('activity_logs')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((json) => ActivityLog.fromJson(json)).toList();
  }
}
