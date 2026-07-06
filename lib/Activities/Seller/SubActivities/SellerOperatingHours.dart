import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SellerOperatingHours extends StatefulWidget {
  const SellerOperatingHours({
    super.key,
    required this.sellerId,
    this.initialHours,
  });

  final String sellerId;
  final Map<String, dynamic>? initialHours;

  @override
  State<SellerOperatingHours> createState() => _SellerOperatingHoursState();
}

class _SellerOperatingHoursState extends State<SellerOperatingHours> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final _supabase = Supabase.instance.client;

  final _bg = const Color(0xFFF8FAFC);
  final _ink = const Color(0xFF0F172A);
  final _muted = const Color(0xFF64748B);
  final _line = const Color(0xFFE2E8F0);
  final _blue = const Color(0xFF2563EB);
  final _green = const Color(0xFF10B981);
  final _red = const Color(0xFFEF4444);

  late Map<String, Map<String, dynamic>> _hours;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hours = _normalizeHours(widget.initialHours);
  }

  Map<String, Map<String, dynamic>> _normalizeHours(dynamic raw) {
    Map source = {};

    if (raw is Map) {
      source = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map) {
          source = decoded;
        }
      } catch (_) {
        // Use the default operating hours when parsing fails.
      }
    }

    return {
      for (final day in _days)
        day: {
          'open': source[day] is Map ? source[day]['open'] ?? '08:00' : '08:00',
          'close': source[day] is Map
              ? source[day]['close'] ?? '17:00'
              : '17:00',
          'closed': source[day] is Map ? source[day]['closed'] == true : false,
        },
    };
  }

  Future<void> _pickTime(String day, String field) async {
    final value = _hours[day]![field].toString();
    final parts = value.split(':');

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );

    if (time == null) {
      return;
    }

    setState(() {
      _hours[day]![field] =
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    });
  }

  String _format12Hour(String? value) {
    if (value == null || !value.contains(':')) {
      return '--';
    }

    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return '--';
    }

    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  void _setAllDays() {
    final monday = Map<String, dynamic>.from(_hours['Monday']!);

    setState(() {
      for (final day in _days) {
        _hours[day] = Map<String, dynamic>.from(monday);
      }
    });
  }

  void _setWeekdaysOnly() {
    setState(() {
      for (final day in _days) {
        final isWeekend = day == 'Saturday' || day == 'Sunday';

        _hours[day] = {'open': '08:00', 'close': '17:00', 'closed': isWeekend};
      }
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload = {
        for (final entry in _hours.entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      };

      await _supabase
          .from('sellers')
          .update({'seller_operating_hours': payload})
          .eq('seller_id', widget.sellerId);

      if (!mounted) {
        return;
      }

      Navigator.pop(context, payload);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save operating hours: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _summary() {
    final openDays = _hours.entries
        .where((entry) => entry.value['closed'] != true)
        .length;

    if (openDays == 0) {
      return 'Closed all week';
    }

    if (openDays == 7) {
      return 'Open 7 days a week';
    }

    return 'Open $openDays '
        'day${openDays == 1 ? '' : 's'} a week';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final horizontal = width < 380 ? 12.0 : 16.0;

    final maxWidth = width >= 1100
        ? 980.0
        : width >= 760
        ? 720.0
        : width;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text(
          'Operating Hours',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _line),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 100),
            children: [
              _hero(width),
              const SizedBox(height: 14),
              _quickActions(width),
              const SizedBox(height: 18),
              _scheduleHeader(),
              const SizedBox(height: 10),
              ..._days.map(_dayCard),
            ],
          ),
        ),
      ),

      // Centered save button at the bottom of the screen.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: SizedBox(
              width: width < 480 ? double.infinity : 420,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _saving ? 'Saving...' : 'Save Operating Hours',
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.65),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(double width) {
    final compact = width < 380;

    final icon = Container(
      width: compact ? 42 : 48,
      height: compact ? 42 : 48,
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.schedule_rounded,
        color: _green,
        size: compact ? 24 : 28,
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Store Schedule',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _summary(),
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF123B68),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123B68).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [icon, const SizedBox(height: 12), details],
            )
          : Row(
              children: [
                icon,
                const SizedBox(width: 14),
                Expanded(child: details),
              ],
            ),
    );
  }

  Widget _quickActions(double width) {
    final actions = [
      _quickButton(
        Icons.copy_all_rounded,
        'Copy Monday to all days',
        _setAllDays,
      ),
      _quickButton(
        Icons.business_center_rounded,
        'Weekdays only',
        _setWeekdaysOnly,
      ),
    ];

    if (width >= 780) {
      return Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            Expanded(child: actions[i]),
            if (i != actions.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: actions
          .map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            ),
          )
          .toList(),
    );
  }

  Widget _quickButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: _blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _muted, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleHeader() {
    final openDays = _hours.values
        .where((hours) => hours['closed'] != true)
        .length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weekly Schedule',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Set when customers can place orders',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$openDays/7 open',
            style: TextStyle(
              color: const Color(0xFF047857),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCard(String day) {
    final value = _hours[day]!;
    final closed = value['closed'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFFCFCFD) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: closed ? _line : _blue.withValues(alpha: 0.22),
        ),
        boxShadow: closed
            ? null
            : [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.035),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayHeader = Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: closed ? _bg : _blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    day.substring(0, 3).toUpperCase(),
                    style: TextStyle(
                      color: closed ? _muted : _blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      closed
                          ? 'Closed'
                          : '${_format12Hour(value['open']?.toString())} - '
                                '${_format12Hour(value['close']?.toString())}',
                      style: TextStyle(
                        color: closed ? _muted : _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: !closed,
                activeTrackColor: _green,
                inactiveTrackColor: const Color(0xFFE2E8F0),
                inactiveThumbColor: Colors.white,
                onChanged: (open) {
                  setState(() {
                    value['closed'] = !open;
                  });
                },
              ),
            ],
          );

          final timeControls = Row(
            children: [
              Expanded(child: _timeButton(day, 'open', 'Opening', closed)),
              const SizedBox(width: 8),
              Expanded(child: _timeButton(day, 'close', 'Closing', closed)),
            ],
          );

          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(child: dayHeader),
                const SizedBox(width: 14),
                SizedBox(width: 340, child: timeControls),
              ],
            );
          }

          if (constraints.maxWidth < 340) {
            return Column(
              children: [
                dayHeader,
                const SizedBox(height: 12),
                _timeButton(day, 'open', 'Opening', closed),
                const SizedBox(height: 8),
                _timeButton(day, 'close', 'Closing', closed),
              ],
            );
          }

          return Column(
            children: [dayHeader, const SizedBox(height: 12), timeControls],
          );
        },
      ),
    );
  }

  Widget _timeButton(String day, String field, String label, bool disabled) {
    final value = _hours[day]![field].toString();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: disabled ? null : () => _pickTime(day, field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: disabled ? _bg : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled ? _line : _blue.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: disabled ? _muted : _blue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    disabled ? '--' : _format12Hour(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: disabled ? _muted : _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
