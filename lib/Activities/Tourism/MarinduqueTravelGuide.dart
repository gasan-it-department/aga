import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MainNavigation.dart';

class MarinduqueTravelGuide extends StatelessWidget {
  const MarinduqueTravelGuide({super.key, this.currentLocation});

  final String? currentLocation;

  static const _bg = Color(0xFFF6F8FB);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _blue = Color(0xFF0A5EA8);
  static const _green = Color(0xFF059669);
  static const _line = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Marinduque Travel Guide',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              _hero(),
              const SizedBox(height: 18),
              _sectionTitle('Getting to the island'),
              const SizedBox(height: 10),
              _travelOption(
                Icons.directions_boat_filled_rounded,
                'Passenger ferry',
                'Travel through a mainland port serving Marinduque. Confirm the destination port and departure time with the operator before leaving.',
                _blue,
              ),
              const SizedBox(height: 10),
              _travelOption(
                Icons.luggage_rounded,
                'Before departure',
                'Bring a valid ID, arrive ahead of boarding, and keep emergency contacts and accommodation details available offline.',
                _green,
              ),
              const SizedBox(height: 20),
              _sectionTitle('Explore six municipalities'),
              const SizedBox(height: 10),
              _municipalities(),
              const SizedBox(height: 20),
              _sectionTitle('Travel essentials'),
              const SizedBox(height: 10),
              _essentials(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _line)),
          ),
          child: FilledButton.icon(
            onPressed: () {
              MainNavigation.selectedTab.value = 1;
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.explore_rounded),
            label: const Text(
              'Explore Marinduque',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/morion_themed/morion_images/morion_popup_banner.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: _ink.withValues(alpha: 0.68)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentLocation?.trim().isNotEmpty == true
                        ? 'Planning from $currentLocation'
                        : 'Plan your island visit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 46),
                const Text(
                  'Welcome to Marinduque',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Plan your route, discover local destinations, and travel around the Heart of the Philippines.',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      color: _ink,
      fontSize: 17,
      fontWeight: FontWeight.w900,
    ),
  );

  Widget _travelOption(IconData icon, String title, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _municipalities() {
    const entries = [
      ('Boac', Icons.account_balance_rounded),
      ('Buenavista', Icons.wb_sunny_rounded),
      ('Gasan', Icons.sailing_rounded),
      ('Mogpog', Icons.landscape_rounded),
      ('Santa Cruz', Icons.forest_rounded),
      ('Torrijos', Icons.beach_access_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 82,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (_, index) {
            final entry = entries[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Icon(entry.$2, color: _green, size: 23),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      entry.$1,
                      maxLines: 2,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _essentials() {
    const items = [
      (Icons.cloud_outlined, 'Check weather and sea conditions'),
      (Icons.confirmation_number_outlined, 'Confirm tickets and port details'),
      (Icons.health_and_safety_outlined, 'Save emergency contacts offline'),
      (Icons.payments_outlined, 'Carry cash for smaller establishments'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          for (int index = 0; index < items.length; index++) ...[
            Row(
              children: [
                Icon(items[index].$1, color: _blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[index].$2,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (index != items.length - 1)
              const Divider(height: 22, color: _line),
          ],
        ],
      ),
    );
  }
}
