import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';

class FareAndScheduleDialog extends StatefulWidget {
  final String shippingLineName;
  final List fares;
  final List schedules;

  const FareAndScheduleDialog({
    super.key,
    required this.shippingLineName,
    required this.fares,
    required this.schedules,
  });

  @override
  State<FareAndScheduleDialog> createState() => _FareAndScheduleDialogState();
}

class _FareAndScheduleDialogState extends State<FareAndScheduleDialog> {
  // --- FILTER STATE ---
  String _timeFilter = 'All'; // Can be 'All', 'AM', or 'PM'

  @override
  Widget build(BuildContext context) {
    const Color primaryDark = Color(0xFF0A2E5C);
    const Color textPrimary = Color(0xFF1E293B);
    const Color textSecondary = Color(0xFF64748B);
    const Color accentBlue = Color(0xFF3B82F6);
    const Color outlineColor = Color(0xFFE2E8F0);
    const Color bgColor = Color(0xFFF8FAFC);

    // --- SMART SCHEDULE PROCESSOR WITH FILTERING ---
    List<Widget> scheduleCards = [];

    for (var s in widget.schedules) {
      if (s is Map && s.containsKey('route')) {
        // CASE 1: Your specific JSON structure
        List allTimes = s['times'] is List ? s['times'] : [];

        // Filter the times based on selection
        List filteredTimes = allTimes.where((time) {
          if (_timeFilter == 'All') return true;
          return time.toString().toUpperCase().contains(_timeFilter);
        }).toList();

        // Only add the route card if it has times that match the filter (or if 'All' is selected and it's just empty)
        if (_timeFilter == 'All' || filteredTimes.isNotEmpty) {
          scheduleCards.add(_buildRouteCard(
              routeData: s,
              filteredTimes: filteredTimes, // Pass the filtered list
              primaryDark: primaryDark,
              accentBlue: accentBlue,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              outlineColor: outlineColor
          ));
        }

      } else if (s is Map) {
        // CASE 2: Generic fallback for other JSON Maps
        String displayJson = s.values.map((val) => val.toString()).join("  •  ");
        if (_timeFilter == 'All' || displayJson.toUpperCase().contains(_timeFilter)) {
          scheduleCards.add(_buildSimpleScheduleItem(displayJson, accentBlue, textPrimary, outlineColor));
        }
      } else {
        // CASE 3: Fallback for Plain Text
        String text = s.toString();
        List<String> lines = text.split(RegExp(r'\n+'));
        for (var line in lines) {
          if (line.trim().isNotEmpty) {
            if (_timeFilter == 'All' || line.toUpperCase().contains(_timeFilter)) {
              scheduleCards.add(_buildSimpleScheduleItem(line.trim(), accentBlue, textPrimary, outlineColor));
            }
          }
        }
      }
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- HEADER WITH CLOSE BUTTON ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: outlineColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryDark.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.business_rounded, color: primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.shippingLineName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryDark, height: 1.2),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: textSecondary, size: 24),
                  style: IconButton.styleFrom(backgroundColor: bgColor),
                )
              ],
            ),
          ),

          // --- SCROLLABLE CONTENT ---
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SCHEDULE TITLE ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: accentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.calendar_month_rounded, size: 14, color: accentBlue),
                      ),
                      const SizedBox(width: 10),
                      const Text("DEPARTURE SCHEDULE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- AM / PM FILTER PILLS ---
                  Row(
                    children: [
                      _buildFilterPill('All', accentBlue, outlineColor, textSecondary),
                      const SizedBox(width: 8),
                      _buildFilterPill('AM', accentBlue, outlineColor, textSecondary),
                      const SizedBox(width: 8),
                      _buildFilterPill('PM', accentBlue, outlineColor, textSecondary),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- SCHEDULE CARDS RENDER ---
                  if (scheduleCards.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: outlineColor)),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: textSecondary),
                          const SizedBox(width: 8),
                          Expanded(child: Text("No ${_timeFilter == 'All' ? '' : '$_timeFilter '}schedules available.", style: const TextStyle(color: textSecondary, fontStyle: FontStyle.italic, fontSize: 13))),
                        ],
                      ),
                    )
                  else
                    ...scheduleCards,

                  const SizedBox(height: 12),
                  const Divider(height: 1, color: outlineColor),
                  const SizedBox(height: 24),

                  // --- FARES SECTION ---
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.payments_rounded, size: 14, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 10),
                      const Text("STANDARD FARES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 1.2)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (widget.fares.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: outlineColor)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: textSecondary),
                          SizedBox(width: 8),
                          Text("No fare information available.", style: TextStyle(color: textSecondary, fontStyle: FontStyle.italic, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: widget.fares.map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                            boxShadow: [
                              BoxShadow(color: accentBlue.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4))
                            ]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_num_rounded, size: 14, color: accentBlue),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${f['type'] ?? 'Fare'}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, letterSpacing: 0.5)),
                                Text("₱${Utility().formatPrice(f['price'])}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8))),
                              ],
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ),

          // --- FOOTER ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: outlineColor)),
            ),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Got it", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTER PILL WIDGET ---
  Widget _buildFilterPill(String label, Color accentColor, Color outlineColor, Color textSecondary) {
    bool isSelected = _timeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timeFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? accentColor : outlineColor, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isSelected ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }

  // --- PREMIUM ROUTE CARD ---
  Widget _buildRouteCard({
    required Map routeData,
    required List filteredTimes, // Accepts the pre-filtered times list
    required Color primaryDark,
    required Color accentBlue,
    required Color textPrimary,
    required Color textSecondary,
    required Color outlineColor
  }) {
    String routeName = routeData['route'] ?? 'Unknown Route';
    String shipType = routeData['shipType'] ?? '';
    String status = routeData['status'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Solid Blue Route Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: primaryDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(routeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 13, letterSpacing: 0.5))),
              ],
            ),
          ),

          // Info Bar: Ship Type & Status
          if (shipType.isNotEmpty || status.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  if (shipType.isNotEmpty) ...[
                    const Icon(Icons.directions_boat_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(shipType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                    const SizedBox(width: 16),
                  ],
                  if (status.isNotEmpty) ...[
                    const Icon(Icons.info_rounded, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                  ]
                ],
              ),
            ),

          // Body: Departure Times (Using the filtered list)
          Padding(
            padding: const EdgeInsets.all(16),
            child: filteredTimes.isEmpty
                ? Text("No ${_timeFilter == 'All' ? '' : '$_timeFilter '}times available.", style: TextStyle(color: textSecondary, fontSize: 13, fontStyle: FontStyle.italic))
                : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: filteredTimes.map((time) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_filled_rounded, size: 14, color: accentBlue),
                    const SizedBox(width: 6),
                    Text(time.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E3A8A))),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGET FOR FALLBACK TEXT ---
  Widget _buildSimpleScheduleItem(String text, Color accentColor, Color textColor, Color outlineColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: outlineColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
          ]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.access_time_filled_rounded, size: 16, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.bold, height: 1.4))),
        ],
      ),
    );
  }
}
