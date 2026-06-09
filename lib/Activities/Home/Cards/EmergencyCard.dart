import 'package:flutter/material.dart';
import '../../MDRRMO/EmergencyScreen.dart';

class EmergencyCard{

  Widget buildEmergencyCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emergency_share_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Emergency Dispatch (24/7)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF991B1B))),
                      Text("Local DRRM Hotlines", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStaticEmergencyIcon(Icons.local_police_rounded, "Police"),
                _buildStaticEmergencyIcon(Icons.fire_truck_rounded, "Fire"),
                _buildStaticEmergencyIcon(Icons.medical_services_rounded, "Medical"),
                _buildStaticEmergencyIcon(Icons.support_outlined, "Coast Guard"),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyScreen()));
                },
                icon: const Icon(Icons.shield_rounded, size: 20),
                label: const Text("ACCESS EMERGENCY CENTER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStaticEmergencyIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFECACA)),
              boxShadow: [
                BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
              ]
          ),
          child: Icon(icon, color: const Color(0xFFDC2626), size: 22),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF991B1B))),
      ],
    );
  }
}
