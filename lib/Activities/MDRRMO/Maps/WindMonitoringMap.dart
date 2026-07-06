import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WindMonitoringMap extends StatefulWidget {
  const WindMonitoringMap({super.key});

  static final Uri windyEmbedUri = Uri.parse(
    'https://embed.windy.com/embed.html?type=map'
    '&location=coordinates'
    '&metricRain=mm'
    '&metricTemp=%C2%B0C'
    '&metricWind=km%2Fh'
    '&zoom=8'
    '&overlay=wind'
    '&product=ecmwf'
    '&level=surface'
    '&lat=13.394'
    '&lon=121.956'
    '&message=true',
  );

  @override
  State<WindMonitoringMap> createState() => _WindMonitoringMapState();
}

class _WindMonitoringMapState extends State<WindMonitoringMap> {
  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _windBlue = const Color(0xFF0EA5E9);
  final Color _teal = const Color(0xFF14B8A6);
  final Color _amber = const Color(0xFFF59E0B);
  final Color _muted = const Color(0xFF64748B);

  WebViewController? _controller;
  int _loadingProgress = 0;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _setupWebView();
  }

  void _setupWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_primaryDark)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadingProgress = progress);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _hasLoadError = false;
              _loadingProgress = 0;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loadingProgress = 100);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _hasLoadError = true);
          },
        ),
      )
      ..loadRequest(WindMonitoringMap.windyEmbedUri);

    _controller = controller;
  }

  Future<void> _openExternal() async {
    await launchUrl(
      WindMonitoringMap.windyEmbedUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _reload() async {
    if (kIsWeb || _controller == null) {
      await _openExternal();
      return;
    }
    setState(() {
      _hasLoadError = false;
      _loadingProgress = 0;
    });
    await _controller!.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: kIsWeb
                ? _buildWebFallback()
                : (_controller == null
                      ? const SizedBox.shrink()
                      : WebViewWidget(controller: _controller!)),
          ),
          _buildHeader(context),
          if (!kIsWeb && _loadingProgress < 100) _buildLoadingBar(context),
          if (_hasLoadError) _buildLoadError(),
          _buildInfoPanel(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.of(context).padding.top + 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _primaryDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              tooltip: 'Back',
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Wind Monitoring',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free Windy wind layer for Marinduque',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
              tooltip: 'Open Windy',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: LinearProgressIndicator(
          minHeight: 3,
          value: _loadingProgress <= 0 ? null : _loadingProgress / 100,
          backgroundColor: Colors.transparent,
          color: _windBlue,
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 560;
    return Positioned(
      left: 16,
      right: isCompact ? 16 : null,
      bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Container(
        width: isCompact ? null : 390,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _legendIcon(Icons.air_rounded, _windBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Free Windy Embed',
                    style: TextStyle(
                      color: _primaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'km/h',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Wind', Icons.air_rounded, _windBlue),
                _chip('Rain', Icons.water_drop_rounded, _teal),
                _chip('Forecast', Icons.schedule_rounded, _amber),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Use this for situational awareness only. Automated wind alerts require a forecast data API, which is not part of the free Windy embed.',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Container(
        width: 320,
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: _windBlue, size: 42),
            const SizedBox(height: 12),
            Text(
              'Wind map unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check internet connection or open Windy externally.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openExternal,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF0B3B58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 360,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.air_rounded, color: _windBlue, size: 48),
              const SizedBox(height: 14),
              Text(
                'Open Windy Map',
                style: TextStyle(
                  color: _primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Embedded WebView is available in the Android app. On web, open the free Windy map in a browser tab.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Windy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
