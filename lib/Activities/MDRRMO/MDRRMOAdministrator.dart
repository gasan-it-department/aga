import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/MDRRMOLiveMap.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/PHIVOLCSEarthquakeInfo.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/PHIVOLCSHazardMap.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/Maps/WindMonitoringMap.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/MDRRMOPersonnelList.dart';
import 'package:gasan_port_tracker/Activities/MDRRMO/AmbulanceRequests.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'MDRRMONotificationCenter.dart';
import 'UnitDispatch.dart';
import 'IncidentReports.dart';

class MdrrmoAdministrator extends StatefulWidget {
  const MdrrmoAdministrator({super.key});

  @override
  State<MdrrmoAdministrator> createState() => _MdrrmoAdministratorState();
}

class _MdrrmoAdministratorState extends State<MdrrmoAdministrator> {
  final _supabase = Supabase.instance.client;

  final Color bgColor = const Color(0xFFF8FAFC);
  final Color surfaceColor = const Color(0xFFFFFFFF);
  final Color primaryDark = const Color(0xFF0F172A);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);
  final Color emergencyRed = const Color(0xFFEF4444);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color lockedBgColor = const Color(0xFFF1F5F9);
  final Color warningAmber = const Color(0xFFF59E0B);

  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();

  String _userName = "Loading...";
  String _userEmail = "";
  String? _avatarUrl;
  String _municipalityName = "MDRRMO";
  int _municipalityZipCode = 0;

  // Analytics Stats
  int _totalPersonnel = 0;
  int _activeUnits = 0; // Dispatched
  int _totalUnits = 0; // Total registered fleets
  int _pendingReports = 0;
  int _yearlyIncidents = 0;
  List<double> _weeklyIncidentCounts = [0, 0, 0, 0, 0, 0, 0]; // Mon - Sun
  Map<String, int> _incidentTypeBreakdown = {};
  List<double> _monthlyIncidentCounts = List.filled(12, 0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdminData();
    });
  }

  Future<void> _loadAdminData() async {
    _loadingDialog.showLoadingDialog(context);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _loadingDialog.dismiss();
      return;
    }

    try {
      final userData = await _supabase
          .from('user_data')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (userData != null) {
        String tempName = userData['user_name'] ?? "Administrator";
        String tempEmail = userData['user_account'] ?? "";
        String? tempAvatar = userData['avatar_url'];
        String tempZip = "0000";

        final dynamic accessColumn = userData["user_access"];
        if (accessColumn != null && accessColumn is Map) {
          if (accessColumn["municipality_zip_code"] != null) {
            tempZip = accessColumn["municipality_zip_code"].toString();
            _municipalityZipCode = int.tryParse(tempZip)!;
          }
        }

        if (mounted) {
          setState(() {
            _userName = tempName;
            _userEmail = tempEmail;
            _avatarUrl = tempAvatar;
            _municipalityName = _getMunicipalityName(tempZip);
          });
        }
        await _fetchAnalytics(int.tryParse(tempZip) ?? 0);
      }
      _loadingDialog.dismiss();
    } catch (e, stacktrace) {
      debugPrint("Error fetching admin data: $e");
      _loadingDialog.dismiss();
      _classicDialog.setTitle("An error occurred!");
      _classicDialog.setMessage("${e.toString()}\n\nStacktrace: \n$stacktrace");
      _classicDialog.setCancelable(false);
      _classicDialog.setPositiveMessage("Close");
      if (mounted)
        _classicDialog.showOnButtonDialog(
          context,
          () => _classicDialog.dismissDialog(),
        );
    }
  }

  Future<void> _fetchAnalytics(int zipCode) async {
    try {
      // 1. Personnel
      final personnelResponse = await _supabase
          .from('mdrrmo_personnels')
          .select('personnel_id')
          .eq('personnel_municipality', zipCode);

      // 2. Units
      final unitsResponse = await _supabase
          .from('vehicles')
          .select('vehicle_id, vehicle_status')
          .eq('vehicle_municipal_owner', zipCode);
      final List allUnits = unitsResponse as List;
      int dispatchedCount = allUnits
          .where(
            (u) => u['vehicle_status'].toString().toLowerCase() == 'dispatched',
          )
          .length;

      // 3. Incidents
      DateTime now = DateTime.now();
      DateTime startOfYear = DateTime(now.year, 1, 1);
      int startOfYearEpoch = startOfYear.millisecondsSinceEpoch;

      final reportsResponse = await _supabase
          .from('incidents_reports')
          .select(
            'ticket_id, ticket_status, ticket_date_created, ticket_incidents_type',
          )
          .gte('ticket_date_created', startOfYearEpoch);

      final List reports = reportsResponse as List;
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      startOfWeek = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      int startOfWeekEpoch = startOfWeek.millisecondsSinceEpoch;

      List<double> weeklyCounts = [0, 0, 0, 0, 0, 0, 0];
      List<double> monthlyCounts = List.filled(12, 0.0);
      Map<String, int> typeBreakdown = {};
      int pendingCount = 0;

      for (var report in reports) {
        if (report['ticket_status'] == 'pending') pendingCount++;

        String type = report['ticket_incidents_type'] ?? 'Unknown';
        typeBreakdown[type] = (typeBreakdown[type] ?? 0) + 1;

        int createdTime = (report['ticket_date_created'] as num).toInt();
        DateTime date = DateTime.fromMillisecondsSinceEpoch(createdTime);

        if (date.year == now.year) {
          monthlyCounts[date.month - 1]++;
        }

        if (createdTime >= startOfWeekEpoch) {
          int index = date.weekday - 1;
          if (index >= 0 && index < 7) weeklyCounts[index]++;
        }
      }

      if (mounted) {
        setState(() {
          _totalPersonnel = (personnelResponse as List).length;
          _activeUnits = dispatchedCount;
          _totalUnits = allUnits.length;
          _pendingReports = pendingCount;
          _yearlyIncidents = reports.length;
          _weeklyIncidentCounts = weeklyCounts;
          _monthlyIncidentCounts = monthlyCounts;
          _incidentTypeBreakdown = typeBreakdown;
        });
      }
    } catch (e) {
      debugPrint("Error fetching analytics: $e");
    }
  }

  String _getMunicipalityName(String zipCode) {
    switch (zipCode) {
      case "4900":
        return "Boac";
      case "4901":
        return "Mogpog";
      case "4902":
        return "Santa Cruz";
      case "4903":
        return "Torrijos";
      case "4904":
        return "Buenavista";
      case "4905":
        return "Gasan";
      case "0000":
        return "Provincial Command";
      default:
        return "Municipality ($zipCode)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Responsive(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: _buildDashboardContent(crossAxisCount: 2),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: _buildDashboardContent(crossAxisCount: 3),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        _buildSidebar(),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: _buildAppBar(isDesktop: true),
            body: _buildDashboardContent(crossAxisCount: 4, isDesktop: true),
          ),
        ),
      ],
    );
  }

  AppBar _buildAppBar({bool isDesktop = false}) {
    return AppBar(
      elevation: 0,
      backgroundColor: surfaceColor,
      foregroundColor: primaryDark,
      centerTitle: false,
      title: const Text(
        "MDRRMO PANEL",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          fontSize: 18,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: borderColor, height: 1.0),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: surfaceColor,
      child: Column(
        children: [
          _buildSidebarHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSidebarItem(
                  Icons.dashboard_rounded,
                  "Dashboard",
                  true,
                  () {},
                ),
                _buildSidebarItem(
                  Icons.satellite_alt_rounded,
                  "Live Map",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MDRRMOLiveMap()),
                  ),
                ),
                _buildSidebarItem(
                  Icons.campaign_rounded,
                  "Emergency Broadcast",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MDRRMONotificationCenter(),
                    ),
                  ),
                ),
                _buildSidebarItem(
                  Icons.fire_truck_rounded,
                  "Unit Dispatch",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          UnitDispatch(municipalZipCode: _municipalityZipCode),
                    ),
                  ),
                ),
                _buildSidebarItem(
                  Icons.airport_shuttle_rounded,
                  "Ambulance Requests",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AmbulanceRequests(
                        municipalityName: _municipalityName,
                      ),
                    ),
                  ),
                ),
                _buildSidebarItem(
                  Icons.groups_rounded,
                  "Personnel",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MdrrmoPersonnelList(
                        mdrrmoMunicipality: _municipalityZipCode,
                      ),
                    ),
                  ),
                ),
                _buildSidebarItem(
                  Icons.report_problem_rounded,
                  "Incident Reports",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IncidentReports()),
                  ),
                ),
                _buildSidebarSectionLabel("TESTING"),
                _buildSidebarItem(
                  Icons.layers_rounded,
                  "PHIVOLCS Hazard Map",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PHIVOLCSHazardMap(),
                    ),
                  ),
                  badge: "TESTING",
                ),
                _buildSidebarItem(
                  Icons.air_rounded,
                  "Wind Monitoring",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WindMonitoringMap(),
                    ),
                  ),
                  badge: "TESTING",
                ),
                _buildSidebarItem(
                  Icons.crisis_alert_rounded,
                  "Earthquake Info",
                  false,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PHIVOLCSEarthquakeInfo(),
                    ),
                  ),
                  badge: "TESTING",
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: emergencyRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.shield_rounded, color: emergencyRed, size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            "MDRRMO",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 18, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: emergencyRed,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    bool isActive,
    VoidCallback onTap, {
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? emergencyRed.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? emergencyRed : textSecondary,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? emergencyRed : textPrimary,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: emergencyRed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_avatarUrl!)
                  : null,
              backgroundColor: lockedBgColor,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _userEmail,
                    style: TextStyle(color: textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent({
    required int crossAxisCount,
    bool isDesktop = false,
  }) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
            physics: const BouncingScrollPhysics(),
            children: [
              if (!isDesktop) _buildAdminProfileHeader(),
              if (!isDesktop) const SizedBox(height: 24),
              _buildInternalTestWarningCard(),

              if (!isDesktop) ...[
                _buildNationalFleetTrackerCard(),
                const SizedBox(height: 32),
              ],

              _buildSectionTitle(
                Icons.insights_rounded,
                "INSIGHTS & ANALYTICS",
                primaryDark,
              ),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.5 : 1.2,
                children: [
                  _buildStatCard(
                    "Total Personnel",
                    _totalPersonnel.toString(),
                    const Color(0xFF8B5CF6),
                    Icons.groups_rounded,
                  ),
                  _buildStatCard(
                    "Active Units",
                    _activeUnits.toString(),
                    const Color(0xFFF59E0B),
                    Icons.fire_truck_rounded,
                  ),
                  _buildStatCard(
                    "Pending Reports",
                    _pendingReports.toString(),
                    emergencyRed,
                    Icons.report_problem_rounded,
                  ),
                  _buildStatCard(
                    "Yearly Incidents",
                    _yearlyIncidents.toString(),
                    const Color(0xFF10B981),
                    Icons.analytics_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              _buildSectionTitle(
                Icons.auto_graph_rounded,
                "VISUAL PERFORMANCE",
                primaryDark,
              ),
              const SizedBox(height: 16),
              _buildActivityBarChart(),

              const SizedBox(height: 32),

              _buildSectionTitle(
                Icons.pie_chart_rounded,
                "INCIDENT BREAKDOWN",
                primaryDark,
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (context, constraints) {
                  return Responsive.isMobile(context)
                      ? Column(
                          children: [
                            _buildIncidentTypeBreakdown(),
                            const SizedBox(height: 16),
                            _buildMonthlyTrendChart(),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildIncidentTypeBreakdown(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(flex: 3, child: _buildMonthlyTrendChart()),
                          ],
                        );
                },
              ),

              const SizedBox(height: 32),

              if (!isDesktop) ...[
                _buildSectionTitle(
                  Icons.bolt_rounded,
                  "ACTIVE MODULES",
                  emergencyRed,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.85,
                  children: [
                    _buildGridCard(
                      title: "Emergency Broadcast",
                      subtitle: "Send instant alerts to citizens.",
                      icon: Icons.campaign_rounded,
                      iconColor: emergencyRed,
                      isActive: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MDRRMONotificationCenter(),
                        ),
                      ),
                    ),
                    _buildGridCard(
                      title: "Unit Dispatch",
                      subtitle: "$_activeUnits active response fleets.",
                      icon: Icons.fire_truck_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      isActive: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UnitDispatch(
                            municipalZipCode: _municipalityZipCode,
                          ),
                        ),
                      ),
                    ),
                    _buildGridCard(
                      title: "Ambulance Requests",
                      subtitle:
                          "Review patient and deceased transport requests.",
                      icon: Icons.airport_shuttle_rounded,
                      iconColor: const Color(0xFFDC2626),
                      isActive: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AmbulanceRequests(
                            municipalityName: _municipalityName,
                          ),
                        ),
                      ),
                    ),
                    _buildGridCard(
                      title: "Incident Reports",
                      subtitle: "$_pendingReports pending reports.",
                      icon: Icons.report_problem_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      isActive: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IncidentReports(),
                        ),
                      ),
                    ),
                    _buildGridCard(
                      title: "Personnel",
                      subtitle: "$_totalPersonnel registered personnel.",
                      icon: Icons.groups_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      isActive: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MdrrmoPersonnelList(
                            mdrrmoMunicipality: _municipalityZipCode,
                          ),
                        ),
                      ),
                    ),
                    _buildGridCard(
                      title: "Barangay Responders",
                      subtitle: "Manage barangay registered personnel.",
                      icon: Icons.badge_rounded,
                      iconColor: const Color(0xFF0D9488),
                      isActive: false,
                      onTap: null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              _buildSectionTitle(
                Icons.science_rounded,
                "TESTING TOOLS",
                emergencyRed,
              ),
              const SizedBox(height: 6),
              Text(
                "These features are being carefully tested and are not yet available for true operational output.",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: isDesktop ? 4 : crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.2 : 0.85,
                children: [
                  _buildGridCard(
                    title: "PHIVOLCS Hazard Map",
                    subtitle: "View active fault and liquefaction overlays.",
                    icon: Icons.layers_rounded,
                    iconColor: const Color(0xFFDC2626),
                    isActive: true,
                    badge: "TESTING",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PHIVOLCSHazardMap(),
                      ),
                    ),
                  ),
                  _buildGridCard(
                    title: "Wind Monitoring",
                    subtitle: "View free Windy wind conditions.",
                    icon: Icons.air_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    isActive: true,
                    badge: "TESTING",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WindMonitoringMap(),
                      ),
                    ),
                  ),
                  _buildGridCard(
                    title: "Earthquake Info",
                    subtitle:
                        "View the official PHIVOLCS earthquake information page.",
                    icon: Icons.crisis_alert_rounded,
                    iconColor: const Color(0xFFB91C1C),
                    isActive: true,
                    badge: "TESTING",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PHIVOLCSEarthquakeInfo(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionTitle(
                Icons.hourglass_empty_rounded,
                "UPCOMING MODULES",
                textSecondary,
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: isDesktop ? 4 : crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.2 : 0.85,
                children: [
                  _buildGridCard(
                    title: "Evacuation Centers",
                    subtitle: "Manage site statuses.",
                    icon: Icons.house_siding_rounded,
                    iconColor: const Color(0xFF10B981),
                    isActive: false,
                    onTap: null,
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBarChart() {
    double maxVal = _weeklyIncidentCounts.reduce(
      (curr, next) => curr > next ? curr : next,
    );
    double maxY = maxVal == 0 ? 5 : (maxVal / 5).ceil() * 5.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Weekly Incidents",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              Icon(Icons.more_horiz_rounded, size: 18, color: textSecondary),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => primaryDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.toInt().toString(),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ["M", "T", "W", "T", "F", "S", "S"];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            days[value.toInt()],
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: borderColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) {
                  final colors = [
                    const Color(0xFF8B5CF6),
                    const Color(0xFFF59E0B),
                    emergencyRed,
                    const Color(0xFF10B981),
                    const Color(0xFF3B82F6),
                    const Color(0xFF8B5CF6),
                    const Color(0xFF64748B),
                  ];
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _weeklyIncidentCounts[i],
                        color: colors[i],
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: bgColor,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentTypeBreakdown() {
    final sortedTypes = _incidentTypeBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTypes = sortedTypes.take(4).toList();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Emergency Types",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          if (topTypes.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No Data Available",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topTypes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final type = topTypes[index];
                  final double percent = _yearlyIncidents > 0
                      ? type.value / _yearlyIncidents
                      : 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            type.key,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            "${type.value}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: percent,
                        backgroundColor: bgColor,
                        color: _getCategoryColor(type.key),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    double maxVal = _monthlyIncidentCounts.reduce(
      (curr, next) => curr > next ? curr : next,
    );
    double maxY = maxVal == 0 ? 10 : (maxVal / 5).ceil() * 5.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Monthly Trend",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                DateTime.now().year.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => primaryDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      const months = [
                        "JAN",
                        "FEB",
                        "MAR",
                        "APR",
                        "MAY",
                        "JUN",
                        "JUL",
                        "AUG",
                        "SEP",
                        "OCT",
                        "NOV",
                        "DEC",
                      ];
                      return BarTooltipItem(
                        "${months[group.x.toInt()]}\n",
                        const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        children: [
                          TextSpan(
                            text: rod.toY.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          "J",
                          "F",
                          "M",
                          "A",
                          "M",
                          "J",
                          "J",
                          "A",
                          "S",
                          "O",
                          "N",
                          "D",
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            months[value.toInt()],
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: borderColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _monthlyIncidentCounts[i],
                        color: primaryDark.withValues(
                          alpha: 0.2 + (_monthlyIncidentCounts[i] / maxY * 0.8),
                        ),
                        width: 8,
                        borderRadius: BorderRadius.circular(2),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: bgColor,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String type) {
    if (type.contains("Medical")) return const Color(0xFF0D9488);
    if (type.contains("Fire")) return const Color(0xFFEF4444);
    if (type.contains("Accident")) return const Color(0xFFF59E0B);
    return const Color(0xFF3B82F6);
  }

  Widget _buildInternalTestWarningCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warningAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: warningAmber.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_rounded, color: warningAmber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "INTERNAL TESTING PHASE",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: warningAmber,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "This application is currently in a closed internal testing phase and is not yet ready for public distribution.",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryDark,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalFleetTrackerCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryDark.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MDRRMOLiveMap()),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.satellite_alt_rounded,
                    color: Color(0xFF10B981),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "LIVE MAP",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "INCIDENTS MONITORING",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Monitor all active response units across the province. This is shared across all registered municipalities.",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: lockedBgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
              image: _avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _avatarUrl == null
                ? Icon(
                    Icons.person_rounded,
                    size: 30,
                    color: textSecondary.withValues(alpha: 0.5),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ADMINISTRATOR",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: emergencyRed,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: primaryDark,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: emergencyRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: emergencyRed.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_rounded, size: 12, color: emergencyRed),
                      const SizedBox(width: 4),
                      Text(
                        "MDRRMO • $_municipalityName",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: emergencyRed,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isActive,
    required VoidCallback? onTap,
    String? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? surfaceColor : lockedBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? borderColor : borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? iconColor.withValues(alpha: 0.1)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? Colors.transparent : borderColor,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isActive
                            ? iconColor
                            : textSecondary.withValues(alpha: 0.5),
                        size: 28,
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: emergencyRed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    if (badge == null && !isActive)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isActive ? textPrimary : textSecondary,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textSecondary.withValues(
                      alpha: isActive ? 1.0 : 0.7,
                    ),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
