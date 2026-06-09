import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MyTravelBucketList.dart';
import 'package:gasan_port_tracker/Activities/MyCart.dart';
import 'package:gasan_port_tracker/Activities/UserLikedSpots.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeDrawer {

  // Standard Government Blue for all interactive elements
  final Color govBlue = const Color(0xFF1565C0);

  Widget buildDrawer(
      Color primaryDark, // Your app's primary dark color (e.g., Deep Navy)
      BuildContext context,
      String userName,
      String userEmail,
      bool isMaritime,
      bool isCaptain,
      bool isMDRRAdmin,
      bool isTourismAdmin,
      bool isMDRRPersonnel,
      String? assignedPort, // Kept to avoid breaking your main.dart, but hidden in UI
      String? avatarUrl,
      ) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC), // Crisp, clean background
      child: Column(
        children: [
          // 1. CUSTOM PREMIUM HEADER (Badge Removed)
          _buildCustomHeader(primaryDark, userName, userEmail, avatarUrl),

          // 2. SCROLLABLE MENU ITEMS
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                _buildSectionTitle("Personal"),

                // --- LIKED SPOTS TAB ---
                _buildDrawerItem(
                  context: context,
                  icon: Icons.favorite_rounded,
                  iconColor: govBlue,
                  title: 'Liked Spots',
                  subtitle: 'Your saved tourist destinations',
                  onTap: () {
                    Navigator.of(context).pop();
                    // UNCOMMENT ONCE YOU CREATE THE SCREEN:
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const UserLikedSpots()));
                  },
                ),

                // --- BUCKET LIST TAB ---
                _buildDrawerItem(
                  context: context,
                  icon: Icons.checklist_rounded,
                  iconColor: govBlue,
                  title: 'Bucket List',
                  subtitle: 'Your adventure travel list',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyTravelBucketList()));
                  },
                ),

                // --- MY CART TAB ---
                _buildDrawerItem(
                  context: context,
                  icon: Icons.shopping_cart_rounded,
                  iconColor: govBlue,
                  title: 'My Cart',
                  subtitle: 'Review your items',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MyCart()));
                  },
                ),

                const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Divider(height: 32, color: Color(0xFFE2E8F0))),
                _buildSectionTitle("App & Community"),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.ios_share_rounded,
                  iconColor: govBlue,
                  title: 'Share App',
                  onTap: () async {
                    Navigator.of(context).pop();
                    const String shareText = "Checkout this amazing app!\n\nDownload it here: https://aga-port-tracker.com";
                    SharePlus.instance.share(ShareParams(text: shareText));
                  },
                ),

                _buildDrawerItem(
                  context: context,
                  icon: Icons.star_rounded,
                  iconColor: govBlue,
                  title: 'Rate Us',
                  onTap: () async {
                    Navigator.of(context).pop();
                    final Uri url = Uri.parse('https://play.google.com/store/apps/details?id=com.aga.gasan.app');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to open the link");
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  /// Builds the modern, custom top header
  Widget _buildCustomHeader(Color primaryDark, String userName, String userEmail, String? avatarUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32), // Extra top padding for status bar
      decoration: BoxDecoration(
        color: primaryDark,
        boxShadow: [
          BoxShadow(color: primaryDark.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Icon(Icons.person_rounded, size: 36, color: primaryDark) : null,
            ),
          ),
          const SizedBox(height: 20),

          // User Info
          Text(
            userName,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            userEmail,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Standardized Section Title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B), // Slate 500
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Modern Drawer Item with Tinted Icon Backgrounds and Chevron
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1), // Very subtle blue tint background
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF1E293B), // Slate 800
            letterSpacing: -0.3,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3), // Slate 500
        )
            : null,
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 18), // Subtle right arrow
      ),
    );
  }
}
