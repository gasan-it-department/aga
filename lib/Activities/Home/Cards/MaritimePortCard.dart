
import 'package:flutter/material.dart';

import '../../Maritime/ViewShippingLinesDetails.dart';

class MaritimePortCard{
  Widget buildMaritimePortCard(BuildContext context, List<Map<String, dynamic>> availablePorts, String? selectedPortFilterId, Color primaryDark, void Function (String? data) onChanged){
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Port & Maritime", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryDark, letterSpacing: -0.5)),
          const SizedBox(height: 12),

          Row(
            children: [
              if (availablePorts.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                        ]
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPortFilterId,
                        isExpanded: true,
                        isDense: true,
                        hint: Text("All Ports", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark)),
                        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primaryDark),
                        items: [
                          DropdownMenuItem(value: null, child: Text("All Ports", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark))),
                          ...availablePorts.map((p) => DropdownMenuItem(
                            value: p['port_id'].toString(),
                            child: Text(p['port_name'].toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryDark), overflow: TextOverflow.ellipsis),
                          ))
                        ],
                        onChanged: (val) {
                          onChanged(val);
                        },
                      ),
                    ),
                  ),
                ),

              const Spacer(),

              SizedBox(
                height: 38,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: primaryDark.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ViewShippingLinesDetails()));
                  },
                  icon: Icon(Icons.visibility_rounded, size: 16, color: primaryDark),
                  label: Text("View All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: primaryDark)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
