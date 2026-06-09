import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as exc;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Utility/Responsive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:gasan_port_tracker/Dialogs/ClassicDialog.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';

class IncidentReports extends StatefulWidget {
  const IncidentReports({super.key});

  @override
  State<IncidentReports> createState() => _IncidentReportsState();
}

class _IncidentReportsState extends State<IncidentReports> {
  final _supabase = Supabase.instance.client;
  final _loadingDialog = LoadingDialog();
  final _classicDialog = ClassicDialog();
  
  // Premium Enterprise Theme Colors
  final Color primaryDark = const Color(0xFF0F172A);
  final Color backgroundLight = const Color(0xFFF8FAFC);
  final Color surfaceWhite = const Color(0xFFFFFFFF);
  final Color cardBorder = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  // Status Colors
  final Color statusPending = const Color(0xFFEF4444); 
  final Color statusInProgress = const Color(0xFF3B82F6); 
  final Color statusResolved = const Color(0xFF10B981); 

  String _currentStatusFilter = 'All';
  final List<String> _statusFilters = ['All', 'Pending', 'In Progress', 'Resolved'];

  // Date Filters
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  List<int> _availableYears = [];
  final List<String> _months = [
    'All Months', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _generateYearList();
  }

  void _generateYearList() {
    int currentYear = DateTime.now().year;
    _availableYears = List.generate(5, (index) => currentYear - index);
  }

  Future<String?> _promptFileName() async {
    final defaultName = 'Incident_Report_${DateTime.now().millisecondsSinceEpoch}';
    final controller = TextEditingController(text: defaultName);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: surfaceWhite,
          elevation: 8,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusResolved.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.file_download_rounded, color: statusResolved, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Export to Excel",
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Name the report file",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary),
                      decoration: InputDecoration(
                        labelText: "File Name",
                        labelStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                        suffixText: ".xlsx",
                        suffixStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w800, fontSize: 13),
                        filled: true,
                        fillColor: backgroundLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cardBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryDark, width: 1.5)),
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: statusPending)),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: statusPending, width: 1.5)),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return "File name is required";
                        if (v.trim().length > 100) return "File name is too long";
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryDark,
                            foregroundColor: surfaceWhite,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text("Export", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportToExcel() async {
    final String? fileName = await _promptFileName();
    if (fileName == null || fileName.trim().isEmpty) return;
    final String safeName = fileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    _loadingDialog.showLoadingDialog(context);
    try {
      final allTickets = await _supabase
          .from('incidents_reports')
          .select()
          .order('ticket_date_created', ascending: false);

      final filteredTickets = (allTickets as List).where((ticket) {
        if (_currentStatusFilter != 'All') {
          final status = (ticket['ticket_status'] ?? '').toString().toLowerCase();
          final filterStatus = _currentStatusFilter.toLowerCase().replaceAll(' ', '_');
          if (status != filterStatus) return false;
        }
        int createdTime = (ticket['ticket_date_created'] as num).toInt();
        DateTime date = DateTime.fromMillisecondsSinceEpoch(createdTime);
        if (_selectedYear != null && date.year != _selectedYear) return false;
        if (_selectedMonth != null && date.month != _selectedMonth) return false;
        if (_selectedDay != null && date.day != _selectedDay) return false;
        return true;
      }).toList();

      var excel = exc.Excel.createExcel();
      exc.Sheet sheetObject = excel['Incidents'];
      
      sheetObject.appendRow([
        exc.TextCellValue('Ticket ID'),
        exc.TextCellValue('Type'),
        exc.TextCellValue('Status'),
        exc.TextCellValue('Date'),
        exc.TextCellValue('Location'),
        exc.TextCellValue('Description'),
        exc.TextCellValue('Contact')
      ]);
      
      for (var ticket in filteredTickets) {
        sheetObject.appendRow([
          exc.TextCellValue(ticket['ticket_id'].toString()),
          exc.TextCellValue(ticket['ticket_incidents_type'] ?? 'N/A'),
          exc.TextCellValue(ticket['ticket_status'] ?? 'N/A'),
          exc.TextCellValue(_formatDate(ticket['ticket_date_created'])),
          exc.TextCellValue(ticket['ticket_incidents_location'] ?? 'N/A'),
          exc.TextCellValue(ticket['ticket_incidents_description'] ?? 'N/A'),
          exc.TextCellValue(ticket['ticket_incidents_contact_number'] ?? 'N/A'),
        ]);
      }

      final List<int>? fileBytes = excel.save();
      if (fileBytes == null) throw Exception("Failed to generate Excel file.");

      _loadingDialog.dismiss();

      if (kIsWeb) {
        final blob = html.Blob([Uint8List.fromList(fileBytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', '$safeName.xlsx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final filePath = "${directory.path}/$safeName.xlsx";
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        await OpenFile.open(filePath);
      }
    } catch (e) {
      _loadingDialog.dismiss();
      _showError("Export failed: $e");
    }
  }

  Future<void> _updateTicketStatus(Map<String, dynamic> ticket, String newStatus) async {
    try {
      final String ticketId = ticket['ticket_id'].toString();
      final String lowercaseStatus = newStatus.toLowerCase();

      await _supabase
          .from('incidents_reports')
          .update({'ticket_status': lowercaseStatus})
          .eq('ticket_id', ticketId);

      if (lowercaseStatus == 'resolved') {
        final responderId = ticket['ticket_responder_vehicle_id']?.toString();
        if (responderId != null && responderId.isNotEmpty) {
          await _supabase
              .from('vehicles')
              .update({'vehicle_status': 'available'})
              .eq('vehicle_id', responderId);
        }
      }

      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Ticket marked as $newStatus");
      }
    } catch (e) {
      if (mounted) {
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to update status.");
      }
    }
  }

  Future<void> _openMaps(String coordinatesJson) async {
    try {
      final Map<String, dynamic> coords = jsonDecode(coordinatesJson);
      final lat = coords['latitude'];
      final lng = coords['longitude'];
      final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Invalid GPS coordinates.");
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      }
    } catch (e) {
      if (mounted) SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error making call.");
    }
  }

  String _formatDate(dynamic epochMillis) {
    if (epochMillis == null) return "Unknown time";
    int time = (epochMillis is String ? int.tryParse(epochMillis) ?? 0 : epochMillis as num).toInt();
    final date = DateTime.fromMillisecondsSinceEpoch(time);
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return "${date.month}/${date.day}/${date.year} • $hour:$minute $amPm";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text(
            "Incident Reports",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)
        ),
        backgroundColor: surfaceWhite,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_rounded, color: statusResolved),
            onPressed: () => _exportToExcel(),
            tooltip: "Export to Excel",
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: cardBorder, height: 1.0),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.isDesktop(context) ? 1200 : 840),
          child: Column(
            children: [
              _buildFilterBar(),
              Expanded(child: _buildTicketList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: surfaceWhite,
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: [
            BoxShadow(color: primaryDark.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
          ]
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _statusFilters.map((filter) {
                final isSelected = _currentStatusFilter == filter;
                return GestureDetector(
                  onTap: () => setState(() => _currentStatusFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryDark : backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? primaryDark : cardBorder),
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? surfaceWhite : textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        isExpanded: true,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                        items: _availableYears.map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                        onChanged: (val) => setState(() {
                          _selectedYear = val;
                          _selectedDay = null; 
                        }),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        hint: Text("All Months", style: TextStyle(fontSize: 13, color: textSecondary)),
                        isExpanded: true,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
                        items: List.generate(13, (i) => DropdownMenuItem(value: i == 0 ? null : i, child: Text(_months[i]))),
                        onChanged: (val) => setState(() {
                          _selectedMonth = val;
                          _selectedDay = null;
                        }),
                      ),
                    ),
                  ),
                ),
                if (_selectedDay != null || _selectedMonth != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: statusPending),
                    onPressed: () => setState(() {
                      _selectedMonth = null;
                      _selectedDay = null;
                    }),
                  )
                ]
              ],
            ),
          ),
          
          if (_selectedDay != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: statusInProgress.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                "Filtering for: ${_months[_selectedMonth ?? 0]} $_selectedDay, $_selectedYear",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusInProgress),
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('incidents_reports')
          .stream(primaryKey: ['ticket_id'])
          .order('ticket_date_created', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryDark, strokeWidth: 3));
        }

        final allTickets = snapshot.data ?? [];

        final filteredTickets = allTickets.where((ticket) {
          if (_currentStatusFilter != 'All') {
            final status = (ticket['ticket_status'] ?? '').toString().toLowerCase();
            final filterStatus = _currentStatusFilter.toLowerCase().replaceAll(' ', '_');
            if (status != filterStatus) return false;
          }

          int createdTime = (ticket['ticket_date_created'] as num).toInt();
          DateTime date = DateTime.fromMillisecondsSinceEpoch(createdTime);

          if (_selectedYear != null && date.year != _selectedYear) return false;
          if (_selectedMonth != null && date.month != _selectedMonth) return false;
          if (_selectedDay != null && date.day != _selectedDay) return false;

          return true;
        }).toList();

        if (filteredTickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 48, color: textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text("No matching incidents found.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textSecondary)),
              ],
            ),
          );
        }

        return Responsive(
          mobile: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: filteredTickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildTicketCard(filteredTickets[index], isGrid: false),
          ),
          tablet: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 320,
            ),
            itemCount: filteredTickets.length,
            itemBuilder: (context, index) => _buildTicketCard(filteredTickets[index], isGrid: true),
          ),
          desktop: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: 300,
            ),
            itemCount: filteredTickets.length,
            itemBuilder: (context, index) => _buildTicketCard(filteredTickets[index], isGrid: true),
          ),
        );
      },
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, {bool isGrid = false}) {
    final String rawStatus = (ticket['ticket_status'] ?? 'pending').toString().toLowerCase();
    Color accentColor;
    String displayStatus;
    IconData statusIcon;

    if (rawStatus == 'resolved') {
      accentColor = statusResolved;
      displayStatus = "Resolved";
      statusIcon = Icons.check_circle_rounded;
    } else if (rawStatus == 'in_progress' || rawStatus == 'being_responded') {
      accentColor = statusInProgress;
      displayStatus = "In Progress";
      statusIcon = Icons.directions_run_rounded;
    } else {
      accentColor = statusPending;
      displayStatus = "Pending";
      statusIcon = Icons.warning_amber_rounded;
    }

    final String ticketId = ticket['ticket_id']?.toString() ?? '—';
    final String contactNumber = ticket['ticket_incidents_contact_number'] ?? '';
    final bool hasContact = contactNumber.isNotEmpty;

    List<String> imageUrls = [];
    if (ticket['ticket_images'] != null) {
      try {
        imageUrls = List<String>.from(jsonDecode(ticket['ticket_images'].toString()));
      } catch (_) {}
    }

    final dropdownValue = (rawStatus == 'resolved' || rawStatus == 'in_progress' || rawStatus == 'being_responded')
        ? rawStatus
        : 'pending';

    return Container(
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status accent stripe
              Container(width: 5, color: accentColor),

              // Card body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Header ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 11, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  displayStatus.toUpperCase(),
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "#$ticketId",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // ── Incident Type + Description ──────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket['ticket_incidents_type'] ?? 'Emergency',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ticket['ticket_incidents_description'] ?? 'No description provided.',
                            style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.45),
                            maxLines: isGrid ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // ── Meta Info Row ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildInfoColumn(
                                Icons.place_rounded,
                                "LOCATION",
                                ticket['ticket_incidents_location'] ?? 'Unknown',
                              ),
                            ),
                            Container(width: 1, height: 28, color: cardBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
                            Expanded(
                              child: _buildInfoColumn(
                                Icons.phone_rounded,
                                "CONTACT",
                                hasContact ? contactNumber : 'Not provided',
                                isLink: hasContact,
                                onTap: hasContact ? () => _makePhoneCall(contactNumber) : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Date ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: textSecondary.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(ticket['ticket_date_created']),
                            style: TextStyle(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // ── Images (mobile / list only) ──────────────────
                    if (!isGrid && imageUrls.isNotEmpty) ...[
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) => _buildImageThumbnail(imageUrls[idx]),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    const Spacer(),
                    Divider(height: 1, thickness: 1, color: cardBorder),

                    // ── Action Footer ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: backgroundLight,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: cardBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  icon: Icon(Icons.expand_more_rounded, color: textSecondary, size: 18),
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary),
                                  value: dropdownValue,
                                  items: [
                                    const DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                    DropdownMenuItem(
                                      value: (rawStatus == 'being_responded') ? 'being_responded' : 'in_progress',
                                      child: const Text('In Progress'),
                                    ),
                                    const DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                                  ],
                                  onChanged: (newValue) {
                                    if (newValue != null && newValue != rawStatus) _updateTicketStatus(ticket, newValue);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryDark,
                                foregroundColor: surfaceWhite,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                              onPressed: ticket['ticket_incidents_coordinates'] != null
                                  ? () => _openMaps(ticket['ticket_incidents_coordinates'])
                                  : null,
                              icon: const Icon(Icons.map_outlined, size: 15),
                              label: const Text("Map", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value, {VoidCallback? onTap, bool isLink = false}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: isLink ? statusInProgress : textSecondary),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 9, color: textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isLink ? statusInProgress : textPrimary, decoration: isLink ? TextDecoration.underline : null), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(String url) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: InteractiveViewer(child: Image.network(url)),
        ),
      ),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(url, fit: BoxFit.cover),
        ),
      ),
    );
  }

  void _showError(String message) {
    _classicDialog.setTitle("Oops!");
    _classicDialog.setMessage(message);
    _classicDialog.setPositiveMessage("Understood");
    if (mounted) _classicDialog.showOnButtonDialog(context, () => _classicDialog.dismissDialog());
  }
}

