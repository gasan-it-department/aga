import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PHIVOLCSEarthquakeInfo extends StatefulWidget {
  const PHIVOLCSEarthquakeInfo({super.key});

  static final Uri earthquakeInfoUri = Uri.parse(
    'https://www.phivolcs.dost.gov.ph/earthquake-information/',
  );

  @override
  State<PHIVOLCSEarthquakeInfo> createState() => _PHIVOLCSEarthquakeInfoState();
}

class _PHIVOLCSEarthquakeInfoState extends State<PHIVOLCSEarthquakeInfo> {
  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _emergencyRed = const Color(0xFFEF4444);
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
      ..loadRequest(PHIVOLCSEarthquakeInfo.earthquakeInfoUri);

    _controller = controller;
  }

  Future<void> _openExternal() async {
    await launchUrl(
      PHIVOLCSEarthquakeInfo.earthquakeInfoUri,
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
          if (!kIsWeb && _loadingProgress < 100) _buildLoadingBar(),
          if (_hasLoadError) _buildLoadError(),
          _buildSourceBadge(context),
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
          color: _primaryDark.withValues(alpha: 0.92),
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
                    'Earthquake Information',
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
                    'Official PHIVOLCS earthquake page',
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
              tooltip: 'Open PHIVOLCS',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
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
          color: _emergencyRed,
        ),
      ),
    );
  }

  Widget _buildSourceBadge(BuildContext context) {
    return Positioned(
      left: 16,
      right: MediaQuery.of(context).size.width < 560 ? 16 : null,
      bottom: MediaQuery.of(context).padding.bottom + 20,
      child: Container(
        width: MediaQuery.of(context).size.width < 560 ? null : 390,
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
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _emergencyRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.crisis_alert_rounded,
                color: _emergencyRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Data source: DOST-PHIVOLCS. Use this page as official reference and verify time-sensitive advisories.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
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
            Icon(Icons.public_off_rounded, color: _emergencyRed, size: 42),
            const SizedBox(height: 12),
            Text(
              'PHIVOLCS page unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check internet connection or open the page externally.',
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
          colors: [Color(0xFF0F172A), Color(0xFF4C0519)],
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
              Icon(Icons.crisis_alert_rounded, color: _emergencyRed, size: 48),
              const SizedBox(height: 14),
              Text(
                'Open PHIVOLCS',
                style: TextStyle(
                  color: _primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Embedded WebView is available in the Android app. On web, open the official PHIVOLCS page in a browser tab.',
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
                  label: const Text('Open PHIVOLCS'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
