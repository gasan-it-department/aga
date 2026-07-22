import 'package:supabase_flutter/supabase_flutter.dart';

class MaritimeDataMapper {
  static Map<String, dynamic>? activeOperation(dynamic value) {
    if (value is! List) return null;
    final operations = value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['completed_at'] == null)
        .toList();
    if (operations.isEmpty) return null;
    operations.sort((a, b) {
      final aDate = DateTime.tryParse(a['updated_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['updated_at']?.toString() ?? '');
      return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    return operations.first;
  }

  static int epoch(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return DateTime.tryParse(value.toString())?.millisecondsSinceEpoch ?? 0;
  }

  static String proofUrl(SupabaseClient client, dynamic path) {
    final value = path?.toString().trim() ?? '';
    if (value.isEmpty ||
        value.startsWith('http://') ||
        value.startsWith('https://')) {
      return value;
    }
    return client.storage.from('vessel-status-proofs').getPublicUrl(value);
  }

  static Map<String, dynamic> normalizeVessel(
    SupabaseClient client,
    Map<String, dynamic> source,
  ) {
    final vessel = Map<String, dynamic>.from(source);
    final operation = activeOperation(vessel['vessel_operations']);
    if (operation == null) {
      vessel['vessel_status'] = {
        'status': 'docked',
        'docked_state': 'docked',
        'operation_id': null,
        'origin': null,
        'destination': null,
        'estimated_transition_earliest': 0,
        'estimated_transition_latest': 0,
      };
      vessel['vessel_current_port'] = null;
      return vessel;
    }

    final status = operation['status']?.toString() ?? 'no_schedule';
    final startedAt = epoch(operation['status_started_at']);
    final earliestAt = epoch(operation['estimated_transition_earliest_at']);
    final latestAt = epoch(operation['estimated_transition_latest_at']);
    final isDepartedOrArrived = status == 'departed' || status == 'arrived';
    final departedAt = isDepartedOrArrived
        ? epoch(operation['actual_departed_at'])
        : 0;
    final arrivedAt = status == 'arrived'
        ? epoch(operation['actual_arrived_at'])
        : 0;
    final duration = latestAt > startedAt
        ? ((latestAt - startedAt) / Duration.millisecondsPerMinute).round()
        : 0;
    final travelDuration = departedAt > 0 && earliestAt > departedAt
        ? ((earliestAt - departedAt) / Duration.millisecondsPerMinute).round()
        : 0;

    vessel['active_operation'] = operation;
    vessel['vessel_current_port'] = operation['current_port_id'];
    vessel['vessel_status'] = {
      'operation_id': operation['operation_id'],
      'origin': operation['origin_port_id'],
      'destination': operation['destination_port_id'],
      'status': status,
      'docked_state': operation['docked_state'] ?? 'docked',
      'departed': departedAt,
      'onboarding_time': status == 'onboarding' ? startedAt : 0,
      'onboarding_duration_minutes': duration,
      'travel_duration_minutes': travelDuration,
      'arrival': arrivedAt,
      'estimated_transition_earliest': earliestAt,
      'estimated_transition_latest': latestAt,
      'boarding_closes_at': epoch(operation['boarding_closes_at']),
      'image_proof': proofUrl(client, operation['proof_image_path']),
      'proof_image_path': operation['proof_image_path'],
      'passenger_level': operation['passenger_level'],
      'passenger_level_source': operation['passenger_level_source'],
      'weather_condition': operation['weather_condition'],
      'no_schedule_reason': operation['no_schedule_reason'],
      'status_note': operation['status_note'],
      'last_confirmed_at': epoch(operation['last_confirmed_at']),
    };
    return vessel;
  }

  static List<Map<String, dynamic>> normalizeVessels(
    SupabaseClient client,
    dynamic response,
  ) {
    return List<Map<String, dynamic>>.from(
      response as List,
    ).map((item) => normalizeVessel(client, item)).toList();
  }

  static Map<String, dynamic> normalizeShippingLine(
    Map<String, dynamic> source,
    Map<String, String> portNames,
  ) {
    final line = Map<String, dynamic>.from(source);
    final profiles = List<Map<String, dynamic>>.from(
      line['shipping_line_route_profiles'] as List? ?? const [],
    );
    line['shipping_line_contact'] = line['contact_number'] ?? '';
    line['shipping_line_status'] = line['is_active'] == false
        ? 'Inactive'
        : 'Active';
    line['shipping_line_added_date'] = epoch(line['created_at']);
    line['shipping_line_schedules'] = profiles.map((profile) {
      final origin =
          portNames[profile['origin_port_id']?.toString()] ?? 'Unknown Port';
      final destination =
          portNames[profile['destination_port_id']?.toString()] ??
          'Unknown Port';
      return {
        'profile_id': profile['profile_id'],
        'origin_port_id': profile['origin_port_id'],
        'destination_port_id': profile['destination_port_id'],
        'route': '$origin to $destination',
        'status': 'Flexible',
        'shipType': profile['vessel_type'] ?? 'All',
        'times': <String>[],
      };
    }).toList();
    final faresByCategory = <String, Map<String, dynamic>>{};
    for (final profile in profiles) {
      final fares = List<Map<String, dynamic>>.from(
        profile['shipping_line_fares'] as List? ?? const [],
      );
      for (final fare in fares) {
        final category = fare['fare_category']?.toString() ?? '';
        if (category.isEmpty || faresByCategory.containsKey(category)) continue;
        faresByCategory[category] = {
          'fare_id': fare['fare_id'],
          'type': category,
          'price': fare['amount']?.toString() ?? '0',
        };
      }
    }
    line['shipping_line_fares'] = faresByCategory.values.toList();
    return line;
  }
}
