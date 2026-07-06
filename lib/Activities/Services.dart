import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/CommunityIssueReport.dart';
import 'package:url_launcher/url_launcher.dart';

class Services extends StatelessWidget {
  const Services({super.key});

  static const _elguUrl = "https://elgu-gasan-marinduque.e.gov.ph/";
  static const _primaryDark = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);

  Future<void> _openPermitPortal() async {
    final uri = Uri.parse(_elguUrl);
    final mode = !kIsWeb && Platform.isAndroid
        ? LaunchMode.inAppBrowserView
        : LaunchMode.externalApplication;
    if (!await launchUrl(uri, mode: mode)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = [
      _ServiceItem(
        icon: Icons.business_center_rounded,
        iconAsset: "assets/dict_logo.png",
        badgeAsset: "assets/elgu_logo-removebg-preview.png",
        title: "Business Permit",
        description: "Apply or renew through the official DICT eLGU portal.",
        color: const Color(0xFF2563EB),
        actionLabel: "Open Portal",
        onTap: _openPermitPortal,
      ),
      _ServiceItem(
        icon: Icons.report_problem_rounded,
        title: "Community Issue",
        description:
            "Report road, streetlight, sanitation, and safety concerns.",
        color: const Color(0xFF0F766E),
        actionLabel: "Create Report",
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CommunityIssueReport()),
        ),
      ),
      const _ServiceItem(
        icon: Icons.cleaning_services_rounded,
        title: "Cemetery Clean Up",
        description: "Request cemetery cleaning and maintenance assistance.",
        color: Color(0xFF059669),
        actionLabel: "Coming Soon",
        disabled: true,
      ),
      const _ServiceItem(
        icon: Icons.hub_rounded,
        title: "Action Center",
        description: "Request financial, burial, food, and other assistance.",
        color: Color(0xFF7C3AED),
        actionLabel: "Coming Soon",
        disabled: true,
      ),
      const _ServiceItem(
        icon: Icons.airport_shuttle_rounded,
        title: "Request Ambulance",
        description: "Request immediate emergency medical transportation.",
        color: Color(0xFFDC2626),
        actionLabel: "Coming Soon",
        disabled: true,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primaryDark,
        elevation: 0,
        title: const Text(
          "Municipal Service",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 900
              ? 4
              : width >= 620
              ? 3
              : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: width >= 620 ? 0.92 : 0.82,
            ),
            itemBuilder: (_, index) => _serviceCard(services[index]),
          );
        },
      ),
    );
  }

  Widget _serviceCard(_ServiceItem service) {
    final displayColor = service.disabled
        ? const Color(0xFF98A2B3)
        : service.color;
    return Material(
      color: service.disabled ? const Color(0xFFF2F4F7) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: service.disabled
              ? const Color(0xFFD0D5DD)
              : displayColor.withValues(alpha: 0.18),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: service.disabled ? null : service.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: service.iconAsset == null
                    ? Icon(service.icon, color: displayColor, size: 28)
                    : Padding(
                        padding: const EdgeInsets.all(7),
                        child: Image.asset(
                          service.iconAsset!,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                service.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: service.disabled ? _textSecondary : _primaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  service.description,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: service.disabled
                        ? const Color(0xFF98A2B3)
                        : _textSecondary,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (service.badgeAsset != null) ...[
                    Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Image.asset(
                        service.badgeAsset!,
                        width: 42,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      service.actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: service.disabled
                            ? const Color(0xFF98A2B3)
                            : displayColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (!service.disabled) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: displayColor,
                      size: 14,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.actionLabel,
    this.onTap,
    this.iconAsset,
    this.badgeAsset,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String actionLabel;
  final VoidCallback? onTap;
  final String? iconAsset;
  final String? badgeAsset;
  final bool disabled;
}
