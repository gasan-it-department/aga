import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gasan_port_tracker/Dialogs/LoadingDialog.dart';
import 'package:gasan_port_tracker/FloatingMessages/SnackbarMessenger.dart';
import 'package:gasan_port_tracker/Utility/Utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../ModernBottomsheet/AddEditTravelTicket.dart';
import '../ModernBottomsheet/ModernBottomSheet.dart';

class TravelHistory extends StatefulWidget {
  final String vehicleId;
  final String vehicleName;
  final String vehiclePlateNumber;

  const TravelHistory({
    super.key,
    required this.vehicleId,
    this.vehicleName = "Vehicle",
    required this.vehiclePlateNumber
  });

  @override
  State<TravelHistory> createState() => _TravelHistoryState();
}

class _TravelHistoryState extends State<TravelHistory> {
  final Color bgColor = const Color(0xFFF8FAFC);
  final Color primaryDark = const Color(0xFF0A2E5C);
  final Color borderColor = const Color(0xFFE2E8F0);
  final Color textPrimary = const Color(0xFF1E293B);
  final Color textSecondary = const Color(0xFF64748B);

  final _loadingDialog = LoadingDialog();
  SupabaseClient? _supabase;

  String _selectedFilter = 'All Time';
  final List<String> _filters = ['All Time', 'This Week', 'This Month', 'This Year', 'Custom'];
  DateTime? _customSelectedDate;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _filterScrollController = ScrollController();

  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  final int _itemsPerPage = 15;

  List<Map<String, dynamic>> _travelLogs = [];

  int _totalTrips = 0;
  double _totalDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _supabase = Supabase.instance.client;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreLogs();
      }
    });

    _fetchInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterScrollController.dispose();
    super.dispose();
  }

  String _formatNumberWithCommas(double value, {int decimals = 1}) {
    List<String> parts = value.toStringAsFixed(decimals).split('.');
    parts[0] = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
    return parts.join('.');
  }

  int _getStartEpoch() {
    final now = DateTime.now();
    DateTime start;

    switch (_selectedFilter) {
      case 'This Week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'This Year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'Custom':
        if (_customSelectedDate != null) {
          start = DateTime(_customSelectedDate!.year, _customSelectedDate!.month, _customSelectedDate!.day);
        } else {
          return 0;
        }
        break;
      case 'All Time':
      default:
        return 0;
    }
    return start.millisecondsSinceEpoch;
  }

  int? _getEndEpochIfCustom() {
    if (_selectedFilter == 'Custom' && _customSelectedDate != null) {
      final end = DateTime(_customSelectedDate!.year, _customSelectedDate!.month, _customSelectedDate!.day, 23, 59, 59, 999);
      return end.millisecondsSinceEpoch;
    }
    return null;
  }

  // --- FETCH DATA ---
  Future<void> _fetchInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _travelLogs.clear();
      });

      final int startEpoch = _getStartEpoch();
      final int? endEpoch = _getEndEpochIfCustom();

      var query = _supabase!
          .from('travel_history')
          .select()
          .eq('vehicle_id', widget.vehicleId)
          .gte('departure_time', startEpoch);

      if (endEpoch != null) {
        query = query.lte('departure_time', endEpoch);
      }

      final logsResponse = await query
          .order('departure_time', ascending: false)
          .range(0, _itemsPerPage - 1);

      final List<Map<String, dynamic>> fetchedLogs = List<Map<String, dynamic>>.from(logsResponse);

      double tempDistance = 0.0;
      final allLogsForPeriod = await query;
      for (var log in allLogsForPeriod) {
        tempDistance += double.tryParse(log['distance_km']?.toString() ?? '0') ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _totalDistance = tempDistance;
          _totalTrips = (allLogsForPeriod as List).length;

          _travelLogs = fetchedLogs;
          _hasMoreData = fetchedLogs.length == _itemsPerPage;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching initial data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        if(!e.toString().contains("does not exist")) {
          SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Failed to load travel history.");
        }
      }
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isFetchingMore || !_hasMoreData || _isLoading) return;

    try {
      setState(() => _isFetchingMore = true);

      _currentPage++;
      final int from = _currentPage * _itemsPerPage;
      final int to = from + _itemsPerPage - 1;

      final int startEpoch = _getStartEpoch();
      final int? endEpoch = _getEndEpochIfCustom();

      var query = _supabase!
          .from('travel_history')
          .select()
          .eq('vehicle_id', widget.vehicleId)
          .gte('departure_time', startEpoch);

      if (endEpoch != null) {
        query = query.lte('departure_time', endEpoch);
      }

      final response = await query
          .order('departure_time', ascending: false)
          .range(from, to);

      final List<Map<String, dynamic>> newLogs = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _travelLogs.addAll(newLogs);
          _hasMoreData = newLogs.length == _itemsPerPage;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching more logs: $e");
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }

  // --- ACTIONS ---

  void _showTravelLogOptions(Map<String, dynamic> log) {
    ModernBottomSheet.show(
      context: context,
      title: "Travel Record Options",
      options: [
        SheetOption(
          icon: Icons.download_rounded,
          title: "Download Trip Ticket",
          onTap: () {
            _exportSingleTripTicketToPDF(log);
          },
        ),
        SheetOption(
          icon: Icons.edit_rounded,
          title: "Edit Record",
          onTap: () async {
            final bool? result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditTravelTicket(
                  vehicleId: widget.vehicleId,
                  travelLog: log,
                  plateNumber: widget.vehiclePlateNumber,
                ),
              ),
            );

            if (result == true) {
              _fetchInitialData();
            }
          },
        ),
        SheetOption(
          icon: Icons.delete_forever_rounded,
          title: "Delete Record",
          isDestructive: true,
          onTap: () {
            _deleteTravelLog(log);
          },
        ),
      ],
    );
  }

  Future<void> _deleteTravelLog(Map<String, dynamic> log) async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              const Text("Delete Record", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          content: const Text(
            "Are you sure you want to delete this travel record?",
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) return;

    try {
      if(mounted) _loadingDialog.showLoadingDialog(context);

      await _supabase!
          .from('travel_history')
          .delete()
          .eq('travel_id', log['travel_id']);

      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.success, "Record deleted successfully.");
        _fetchInitialData();
      }
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error deleting: $e");
      }
    }
  }

  Future<void> _exportSingleTripTicketToPDF(Map<String, dynamic> log) async {
    try {
      _loadingDialog.showLoadingDialog(context);

      String formatEpochTime(dynamic epochMs) {
        final int ms = int.tryParse(epochMs?.toString() ?? '0') ?? 0;
        if (ms == 0) return 'N/A';
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        int hour12 = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        String amPm = dt.hour >= 12 ? 'PM' : 'AM';
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} at $hour12:${dt.minute.toString().padLeft(2, '0')} $amPm";
      }

      String formatDouble(dynamic value) {
        final d = double.tryParse(value?.toString() ?? '0') ?? 0.0;
        if (d == 0) return 'N/A';
        return d.toStringAsFixed(2);
      }

      final pdf = pw.Document();

      pw.Widget buildRow(String title, String value) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 4, child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5))),
              pw.Expanded(flex: 5, child: pw.Text(value, style: const pw.TextStyle(fontSize: 9.5))),
            ],
          ),
        );
      }

      pw.Widget buildSectionHeader(String title) {
        return pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
          color: PdfColors.grey300,
          child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                    child: pw.Column(
                        children: [
                          pw.Text("Republic of the Philippines", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.normal)),
                          pw.SizedBox(height: 2),
                          pw.Text("Province of Marinduque", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.normal)),
                          pw.SizedBox(height: 2),
                          pw.Text("MUNICIPALITY OF GASAN", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.normal)),
                          pw.SizedBox(height: 40),

                          pw.Text("DAILY TRIP TICKET", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                        ]
                    )
                ),
                pw.SizedBox(height: 12),

                // Section A
                buildSectionHeader("A. Officials (Authorization)"),
                buildRow("Name of Driver:", log['driver_name']?.toString() ?? 'N/A'),
                buildRow("Plate No:", log['plate_number']?.toString() ?? 'N/A'),
                buildRow("Authorized Passenger:", log['authorized_passenger']?.toString() ?? 'N/A'),
                buildRow("Destination:", log['destination']?.toString() ?? 'N/A'),
                buildRow("Purpose:", log['purpose']?.toString() ?? 'N/A'),

                // Sections B & C (Side-by-Side to save vertical space)
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                buildSectionHeader("B. Driver's Itinerary (Time)"),
                                buildRow("Depart Garage:", formatEpochTime(log['time_depart_garage'])),
                                buildRow("Arrive Destination:", formatEpochTime(log['time_arrive_dest'])),
                                buildRow("Depart Destination:", formatEpochTime(log['time_depart_dest'])),
                                buildRow("Arrive Garage:", formatEpochTime(log['time_arrive_garage'])),
                              ]
                          )
                      ),
                      pw.SizedBox(width: 16),
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                buildSectionHeader("C. Distance & Speedometer"),
                                buildRow("Beginning Odometer:", formatDouble(log['odo_start'])),
                                buildRow("Ending Odometer:", formatDouble(log['odo_end'])),
                                buildRow("Total Distance:", "${formatDouble(log['distance_km'])} km"),
                              ]
                          )
                      ),
                    ]
                ),

                // Section D (Side-by-Side to save vertical space)
                buildSectionHeader("D. Gasoline & Oil Consumption"),
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // GAS COLUMN
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Gasoline (Liters)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.grey700)),
                                pw.SizedBox(height: 4),
                                buildRow("Balance in Tank:", formatDouble(log['gas_balance_start'])),
                                buildRow("Issued from Stock:", formatDouble(log['gas_issued'])),
                                buildRow("Purchased during trip:", formatDouble(log['gas_purchased'])),
                                buildRow("Total Available:", formatDouble(log['gas_total'])),
                                buildRow("Deduct Used during trip:", formatDouble(log['gas_used'])),
                                buildRow("Balance at End of Trip:", formatDouble(log['gas_balance_end'])),
                              ]
                          )
                      ),
                      pw.SizedBox(width: 16),
                      // OIL COLUMN
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Oil Consumption", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.grey700)),
                                pw.SizedBox(height: 4),
                                buildRow("Lubricating Oil Used:", formatDouble(log['lube_oil_used'])),
                                buildRow("Gear Oil Used:", formatDouble(log['gear_oil_used'])),
                                buildRow("Gear Oil Unused:", formatDouble(log['gear_oil_unused'])),
                              ]
                          )
                      ),
                    ]
                ),

                // Section E
                buildSectionHeader("E. Remarks"),
                pw.Text(
                    log['remarks']?.toString().isNotEmpty == true ? log['remarks'].toString() : "No remarks provided.",
                    style: const pw.TextStyle(fontSize: 10)
                ),

                pw.SizedBox(height: 24),

                // --- CERTIFICATIONS & SIGNATURES (Side-by-Side to save space) ---
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // PASSENGER
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("I hereby certify that I used this car on official business as stated above.", style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic)),
                                pw.SizedBox(height: 24), // Space for signature
                                pw.Container(
                                  width: 180,
                                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                                  child: pw.Center(
                                      child: pw.Text(
                                        '',
                                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                        maxLines: 1,
                                      )
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Container(
                                    width: 180,
                                    alignment: pw.Alignment.center,
                                    child: pw.Text("Authorized Passenger", style: const pw.TextStyle(fontSize: 9))
                                ),
                              ]
                          )
                      ),
                      pw.SizedBox(width: 20),
                      // DRIVER
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("I hereby certify to the correctness of the above statement record of travel.", style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic)),
                                pw.SizedBox(height: 24), // Space for signature
                                pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Column(
                                          children: [
                                            pw.Container(
                                              width: 110,
                                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                                              child: pw.Center(
                                                  child: pw.Text(
                                                    '',
                                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                                    maxLines: 1,
                                                  )
                                              ),
                                            ),
                                            pw.SizedBox(height: 2),
                                            pw.Text("Driver", style: const pw.TextStyle(fontSize: 9)),
                                          ]
                                      ),
                                      pw.Column(
                                          children: [
                                            pw.Container(
                                              width: 70,
                                              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                                              child: pw.Center(
                                                  child: pw.Text(
                                                      '',
                                                      style: const pw.TextStyle(fontSize: 10)
                                                  )
                                              ),
                                            ),
                                            pw.SizedBox(height: 2),
                                            pw.Text("Date", style: const pw.TextStyle(fontSize: 9)),
                                          ]
                                      ),
                                    ]
                                )
                              ]
                          )
                      ),
                    ]
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final String dateStr = formatEpochTime(log['departure_time']).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final String filename = "TripTicket_${widget.vehicleName.replaceAll(' ', '_')}_$dateStr.pdf";

      await Printing.sharePdf(bytes: bytes, filename: filename);
      _loadingDialog.dismiss();
    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error generating Ticket PDF: $e");
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_travelLogs.isEmpty) {
      SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "No records to export.");
      return;
    }

    try {
      _loadingDialog.showLoadingDialog(context);

      final int startEpoch = _getStartEpoch();
      final int? endEpoch = _getEndEpochIfCustom();

      var query = _supabase!
          .from('travel_history')
          .select()
          .eq('vehicle_id', widget.vehicleId)
          .gte('departure_time', startEpoch);

      if (endEpoch != null) {
        query = query.lte('departure_time', endEpoch);
      }

      final response = await query.order('departure_time', ascending: false);
      final List<Map<String, dynamic>> allExportLogs = List<Map<String, dynamic>>.from(response);

      final pdf = pw.Document();

      final headers = ['Date', 'Driver', 'Destination', 'Purpose', 'Distance'];

      final data = allExportLogs.map((log) {
        final int epochMs = int.tryParse(log['departure_time']?.toString() ?? '0') ?? 0;
        final dateStr = epochMs > 0
            ? Utility().formatEpochToTime(epochMs ~/ 1000)
            : 'Unknown';

        return [
          dateStr,
          log['driver_name']?.toString() ?? 'N/A',
          log['destination']?.toString() ?? 'N/A',
          log['purpose']?.toString() ?? 'N/A',
          "${double.tryParse(log['distance_km']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0'} km"
        ];
      }).toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("OFFICIAL TRAVEL HISTORY REPORT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text("Vehicle: ${widget.vehicleName}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.Text("Plate/ID: ${widget.vehicleId}", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.Text("Filter Applied: $_selectedFilter", style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.grey400),
                  pw.SizedBox(height: 12),
                ]
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10.0),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0A2E5C)),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
                cellPadding: const pw.EdgeInsets.all(6),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                  4: const pw.FlexColumnWidth(1),
                },
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text("Total Trips: ${_totalTrips.toString()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(width: 20),
                    pw.Text("Total Distance: ${_formatNumberWithCommas(_totalDistance)} km", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ]
              )
            ];
          },
        ),
      );

      if (mounted) _loadingDialog.dismiss();

      final bytes = await pdf.save();
      final String filename = "Travel_History_${widget.vehicleName.replaceAll(' ', '_')}.pdf";
      await Printing.sharePdf(bytes: bytes, filename: filename);

    } catch (e) {
      if (mounted) {
        _loadingDialog.dismiss();
        SnackbarMessenger().showSnackbar(context, SnackbarMessenger.failed, "Error generating PDF: $e");
      }
    }
  }

  String _formatCustomDatePill(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primaryDark,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Travel History", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            Text(widget.vehicleName, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download Table to PDF',
            onPressed: _exportToPDF,
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'Add Travel Log',
            onPressed: () async {
              final bool? result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditTravelTicket(vehicleId: widget.vehicleId, plateNumber: widget.vehiclePlateNumber),
                ),
              );
              if (result == true) {
                _fetchInitialData();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Utility().getMaxScreenSize()),
          child: Column(
            children: [
              _buildDashboardStats(),

              _buildFilters(),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A2E5C)))
                    : _travelLogs.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.explore_off_rounded, size: 48, color: borderColor),
                      const SizedBox(height: 16),
                      Text(
                        "No travel records found for $_selectedFilter.",
                        style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _travelLogs.length + (_isFetchingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _travelLogs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF0A2E5C))),
                      );
                    }
                    return _buildTravelCard(_travelLogs[index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardStats() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          _buildStatCard("Total Trips", _totalTrips.toString(), primaryDark, Icons.timeline_rounded),
          const SizedBox(width: 12),
          _buildStatCard("Distance", "${_formatNumberWithCommas(_totalDistance, decimals: 1)} km", const Color(0xFF10B981), Icons.add_road_rounded),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 54,
      color: bgColor,
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            final targetOffset = _filterScrollController.offset + pointerSignal.scrollDelta.dy;
            _filterScrollController.jumpTo(
                targetOffset.clamp(0.0, _filterScrollController.position.maxScrollExtent)
            );
          }
        },
        child: ListView.builder(
          controller: _filterScrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final isSelected = _selectedFilter == filter;

            String displayText = filter;
            if (filter == 'Custom' && _customSelectedDate != null) {
              displayText = _formatCustomDatePill(_customSelectedDate!);
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter == 'Custom') ...[
                      Icon(Icons.calendar_month_rounded, size: 14, color: isSelected ? Colors.white : textSecondary),
                      const SizedBox(width: 4),
                    ],
                    Text(displayText, style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isSelected ? Colors.white : textSecondary,
                    )),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) async {
                  if (filter == 'Custom') {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _customSelectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: primaryDark)), child: child!);
                      },
                    );

                    if (pickedDate != null) {
                      setState(() {
                        _selectedFilter = 'Custom';
                        _customSelectedDate = pickedDate;
                      });
                      _fetchInitialData();
                    }
                  } else if (!isSelected) {
                    setState(() {
                      _selectedFilter = filter;
                      _customSelectedDate = null;
                    });
                    _fetchInitialData();
                  }
                },
                backgroundColor: Colors.white,
                selectedColor: primaryDark,
                side: BorderSide(color: isSelected ? primaryDark : borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTravelCard(Map<String, dynamic> log) {
    final double distance = double.tryParse(log['distance_km']?.toString() ?? '0') ?? 0.0;
    final String destination = log['destination']?.toString() ?? 'Unknown Destination';
    final String driver = log['driver_name']?.toString() ?? 'Unknown Driver';
    final String purpose = log['purpose']?.toString() ?? 'No purpose provided';

    final int epochMs = int.tryParse(log['departure_time']?.toString() ?? '0') ?? 0;
    final int epochSeconds = epochMs;
    final String formattedDate = Utility().formatEpochToTime(epochSeconds);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: primaryDark.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))
          ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showTravelLogOptions(log),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryDark.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.route_rounded, color: primaryDark, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                                destination,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: textPrimary, letterSpacing: -0.3)
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(formattedDate, style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.badge_rounded, "Driver: $driver", textPrimary),
                      const SizedBox(height: 4),
                      _buildInfoRow(Icons.assignment_rounded, "Purpose: $purpose", textSecondary),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          "${_formatNumberWithCommas(distance, decimals: 1)} km",
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981))
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(icon, size: 14, color: textSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
