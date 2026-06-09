import 'package:flutter/material.dart';

class ViewSchedules {
  static void showBottomSheet({
    required BuildContext context,
    required String shippingLineName,
    required List<dynamic> schedules,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // <-- Prevents tapping outside to close
      enableDrag: false,    // <-- Prevents dragging down to close
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ScheduleBottomSheetContent(
          shippingLineName: shippingLineName,
          schedules: schedules,
        );
      },
    );
  }
}

class _ScheduleBottomSheetContent extends StatefulWidget {
  final String shippingLineName;
  final List<dynamic> schedules;

  const _ScheduleBottomSheetContent({
    required this.shippingLineName,
    required this.schedules,
  });

  @override
  State<_ScheduleBottomSheetContent> createState() => _ScheduleBottomSheetContentState();
}

class _ScheduleBottomSheetContentState extends State<_ScheduleBottomSheetContent> {
  // Theme Colors
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color primaryGreen = const Color(0xFF059669);
  final Color surfaceColor = const Color(0xFFF8FAFC);
  final Color borderColor = const Color(0xFFE2E8F0);

  // Filter State: 'All', 'AM', or 'PM'
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    // Bound the bottom sheet to max 85% of screen
    final double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- 1. Header (No Drag Handle, No Top Close Button) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.directions_boat_rounded, color: primaryGreen, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "OPERATING SCHEDULES",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.shippingLineName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: borderColor),

          // --- 2. Filter Bar ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Text(
                  "FILTER:",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0), // slightly darker slate for contrast
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: ['All', 'AM', 'PM'].map((filter) {
                        final bool isSelected = _selectedFilter == filter;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedFilter = filter),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: isSelected ? primaryGreen : textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- 3. Body (Scrollable List) ---
          Flexible(
            child: widget.schedules.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
              padding: const EdgeInsets.all(24.0),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.schedules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final schedule = widget.schedules[index];
                return _buildScheduleCard(schedule);
              },
            ),
          ),

          // --- 4. Fixed Bottom Close Button ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: borderColor)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Schedule Card Widget ---
  Widget _buildScheduleCard(dynamic schedule) {
    final String route = schedule['route'] ?? 'Route unavailable';
    final String status = schedule['status'] ?? 'Fixed';
    final String shipType = schedule['shipType'] ?? 'Unknown Type';
    final List<dynamic> rawTimes = schedule['times'] ?? [];

    // Filter the times based on the selected segment (All, AM, PM)
    final List<dynamic> filteredTimes = rawTimes.where((time) {
      if (_selectedFilter == 'All') return true;
      return time.toString().toUpperCase().contains(_selectedFilter);
    }).toList();

    final bool isTentative = status.toLowerCase() == 'tentative';
    final Color badgeColor = isTentative ? const Color(0xFFD97706) : primaryGreen;
    final Color badgeBgColor = isTentative ? const Color(0xFFFEF3C7) : primaryGreen.withValues(alpha: 0.1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section: Route, Ship Type, and Status Badge
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: textPrimary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.directions_boat_outlined, size: 14, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            shipType,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: badgeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom section: Filtered Departure Times Wrap
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DEPARTURE TIMES",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                filteredTimes.isEmpty
                    ? Text("No $_selectedFilter departures listed for this route.",
                    style: TextStyle(color: textSecondary, fontStyle: FontStyle.italic, fontSize: 13))
                    : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: filteredTimes.map((time) => _buildTimeChip(time.toString())).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Time Chip UI ---
  Widget _buildTimeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: 14, color: primaryGreen),
          const SizedBox(width: 6),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Empty State Widget ---
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          Text(
            "No Schedules Available",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "There are currently no operating schedules listed for this shipping line.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
