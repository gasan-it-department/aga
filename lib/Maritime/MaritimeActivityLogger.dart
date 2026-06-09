import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaritimeActivityLogger {
  static final _supabase = Supabase.instance.client;
  static const String _tableName = 'maritime_logs';

  // Define the maximum number of logs to keep
  static const int _maxLogsLimit = 300;

  /// Globally callable function to CREATE a new log entry.
  /// Example: MaritimeActivityLogger.createLog(title: "Port Added", message: "Gasan Port was created.", creatorId: "user123");
  static Future<bool> createLog({
    required String title,
    required String message,
    required String creatorId,
  }) async {
    try {
      // 1. Insert the new log
      await _supabase.from(_tableName).insert({
        'log_title': title,
        'log_message': message,
        'log_creator': creatorId,
        'log_id': Utility().generateUniqueID(),
        'log_added_date': Utility().getCurrentMSEpochTime(),
      });

      // 2. Automatically enforce the 300 items limit
      await _enforceLogLimit();

      debugPrint("Maritime Log Saved: $title");
      return true;
    } catch (e) {
      debugPrint("Failed to create maritime log: $e");
      return false;
    }
  }

  /// Helper function to prune the table if it exceeds the max limit
  static Future<void> _enforceLogLimit() async {
    try {
      // Fetch the exact timestamp of the 300th log (Index 299 because it's 0-indexed)
      final thresholdResponse = await _supabase
          .from(_tableName)
          .select('log_added_date')
          .order('log_added_date', ascending: false) // Sort newest first
          .range(_maxLogsLimit - 1, _maxLogsLimit - 1)
          .maybeSingle();

      // If a 300th log exists, it means we have reached or exceeded our capacity
      if (thresholdResponse != null) {
        final thresholdDate = thresholdResponse['log_added_date'];

        // Delete all logs that are older (less than) the 300th log's date
        await _supabase
            .from(_tableName)
            .delete()
            .lt('log_added_date', thresholdDate);

        debugPrint("Log cleanup complete. Oldest logs removed.");
      }
    } catch (e) {
      debugPrint("Failed to clean up old logs: $e");
    }
  }

  /// Globally callable function to FETCH recent logs.
  /// Example: final logs = await MaritimeActivityLogger.fetchLogs(limit: 5);
  static Future<List<Map<String, dynamic>>> fetchLogs({int limit = 10}) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('log_added_date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Failed to fetch maritime logs: $e");
      return [];
    }
  }
}
