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
    try {
      final response = await client
          .from('drivers')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((json) => Driver.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching drivers: $e");
      return [];
    }
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
      print("❌ PostgrestException adding driver: ${e.message}");
      rethrow;
    } catch (e) {
      print("❌ Generic error adding driver: $e");
      rethrow;
    }
  }

  static Future<void> updateDriver(String id, Map<String, dynamic> updates) async {
    if (id.isEmpty || id == "null") {
      print("⚠️ Attempted to update driver with invalid ID: $id");
      return;
    }
    try {
      await client.from('drivers').update(updates).eq('id', id);
    } catch (e) {
      print("❌ Error updating driver $id: $e");
      rethrow;
    }
  }

  static Future<void> bulkUpdateDriversMadiya(List<String> ids, String targetMadiya) async {
    if (ids.isEmpty) return;
    try {
      // In PostgREST 2.7.0 (and recent supabase_flutter 2.x),
      // the correct filter method for "WHERE column IN (...)" is inFilter().
      await client.from('drivers').update({'madiya': targetMadiya}).inFilter('id', ids);
    } catch (e) {
      print("❌ Database bulk update error: $e");
      rethrow;
    }
  }

  static Future<Driver?> verifyMadiyaQueueByQR(String qrData) async {
    if (qrData.isEmpty) return null;

    try {
      // STEP 1: Try by driver_id
      final response = await client
          .from('drivers')
          .select()
          .eq('id', qrData)
          .maybeSingle();

      if (response != null) {
        final driver = Driver.fromJson(response);

        await updateDriver(driver.id, {
          'live_status': 'In Progress'
        });

        return driver;
      }

      // STEP 2: Fallback by plate number
      final plateResponse = await client
          .from('drivers')
          .select()
          .eq('plate', qrData.toUpperCase())
          .maybeSingle();

      if (plateResponse != null) {
        final driver = Driver.fromJson(plateResponse);

        await updateDriver(driver.id, {
          'live_status': 'In Progress'
        });

        return driver;
      }

    } catch (e) {
      print("❌ QR Verification Error: $e");
    }

    return null;
  }

  // Transfer History
  static Future<List<TransferHistory>> fetchTransferHistory() async {
    const String tableName = 'transfer_history';
    print("🔍 Querying table: $tableName");
    try {
      final response = await client
          .from(tableName)
          .select()
          .order('transferred_at', ascending: false);

      print("========== TRANSFER HISTORY ==========");
      print(response);

      if ((response as List).isNotEmpty) {
        print("First Record:");
        print(response.first);
      }
      print("======================================");

      final List<dynamic> data = response;
      print("✅ Successfully fetched ${data.length} rows from $tableName");

      return data.map((json) {
        try {
          return TransferHistory.fromJson(json);
        } catch (e) {
          print("❌ Mapping Error in fetchTransferHistory: $e");
          print("Offending JSON: $json");
          rethrow;
        }
      }).toList();
    } on PostgrestException catch (e) {
      print("❌ PostgREST Error fetching $tableName: ${e.message} (Code: ${e.code})");
      return [];
    } catch (e) {
      print("❌ Generic Error fetching $tableName: $e");
      return [];
    }
  }

  static Stream<List<TransferHistory>> transferHistoryStream() {
    return client
        .from('transfer_history')
        .stream(primaryKey: ['id'])
        .order('transferred_at', ascending: false)
        .map((data) {
      print("📦 Stream received ${data.length} records");

      if (data.isNotEmpty) {
        print("First Stream Record:");
        print(data.first);
      }

      return data.map((json) {
        try {
          return TransferHistory.fromJson(json);
        } catch (e) {
          print("❌ Mapping Error in transferHistoryStream: $e");
          print("Offending JSON: $json");
          rethrow;
        }
      }).toList();
    });
  }

  static Future<void> addTransferRecord(Map<String, dynamic> record) async {
    try {
      // Synchronize field names with updated schema cache
      final Map<String, dynamic> historyData = {
        'driver_id': record['driver_id'],
        'driver_name': record['driver_name'] ?? 'Unknown',
        'plate': record['plate'] ?? 'Unknown',
        'from_madiya': record['from_madiya'],
        'to_madiya': record['to_madiya'],
        'transferred_by': record['transferred_by'],
      };

      await client.from('transfer_history').insert(historyData);

      // Also insert into 'transfers' table
      await client.from('transfers').insert({
        'driver_name': record['driver_name'] ?? 'Unknown',
        'plate': record['plate'] ?? 'Unknown',
        'from_station': record['from_madiya'],
        'to_station': record['to_madiya'],
      });
    } catch (e) {
      print("❌ Error adding transfer record: $e");
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
    try {
      final response = await client
          .from('announcements')
          .select('id, title, content, created_at')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("❌ Error fetching announcements: $e");
      return [];
    }
  }

  static Stream<List<Map<String, dynamic>>> announcementsStream() {
    return client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  // Reports
  static Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      final response = await client
          .from('reports')
          .select('id, reporter_name, title, description, status, admin_response, created_at')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("❌ Error fetching reports: $e");
      return [];
    }
  }

  static Stream<List<Map<String, dynamic>>> reportsStream() {
    return client
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static Future<void> addReport(Map<String, dynamic> reportData) async {
    try {
      await client.from('reports').insert(reportData);
    } catch (e) {
      print("❌ Error adding report: $e");
      rethrow;
    }
  }

  static Future<void> updateReport(String reportId, Map<String, dynamic> updates) async {
    if (reportId.isEmpty || reportId == "null") return;
    try {
      await client.from('reports').update(updates).eq('id', reportId);
    } catch (e) {
      print("❌ Error updating report $reportId: $e");
      rethrow;
    }
  }

  // Statistics
  static Future<Map<String, int>> fetchStatistics() async {
    try {
      final driversCount = await client.from('drivers').count(CountOption.exact);
      final pendingCount = await client.from('drivers').count(CountOption.exact).eq('status', 'Pending');
      final transfersCount = await client.from('transfer_history').count(CountOption.exact);

      return {
        'total_drivers': driversCount,
        'pending_requests': pendingCount,
        'total_transfers': transfersCount,
      };
    } catch (e) {
      print("❌ Error fetching statistics: $e");
      return {
        'total_drivers': 0,
        'pending_requests': 0,
        'total_transfers': 0,
      };
    }
  }

  // Activity Logs
  static Future<void> logActivity(ActivityLog log) async {
    try {
      await client.from('activity_logs').insert(log.toJson());
    } catch (e) {
      print("❌ Logging error: $e");
    }
  }

  static Future<List<ActivityLog>> fetchActivityLogs() async {
    try {
      final response = await client
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((json) => ActivityLog.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching activity logs: $e");
      return [];
    }
  }
}
