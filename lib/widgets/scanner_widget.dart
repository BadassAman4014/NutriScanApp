import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ui_components.dart';
import '../core/theme.dart';

class ScannerWidget extends StatefulWidget {
  final Function(String barcode) onDetected;
  final double height;

  const ScannerWidget({
    super.key,
    required this.onDetected,
    this.height = 240,
  });

  @override
  State<ScannerWidget> createState() => _ScannerWidgetState();
}

class _ScannerWidgetState extends State<ScannerWidget> {
  late final MobileScannerController _ctrl;
  bool _isCameraActive = true;
  bool _isStarting = false;
  
  // Consensus logic
  final Map<String, int> _barcodeSamples = {};
  final int _requiredSamples = 2; // Even faster consensus
  bool _isProcessing = false;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      formats: [
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
      ],
    );
  }

  Future<void> _toggleCamera() async {
    if (_isStarting) return;

    if (_isCameraActive) {
      setState(() => _isCameraActive = false);
      try {
        await _ctrl.stop();
      } catch (e) {
        debugPrint('Error stopping camera: $e');
      }
    } else {
      setState(() {
        _isCameraActive = true;
        _isStarting = true;
      });
      // Small delay to ensure the widget is rebuilt before starting the controller
      Future.delayed(const Duration(milliseconds: 200), () async {
        try {
          await _ctrl.start();
        } catch (e) {
          debugPrint('Error starting camera: $e');
          if (mounted) setState(() => _isCameraActive = false);
        } finally {
          if (mounted) setState(() => _isStarting = false);
        }
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || !_isCameraActive || _isStarting) return;

    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      
      // Filter out common noise (short strings, non-numeric unless it's code128)
      if (raw.length < 7) continue;

      debugPrint('Detected barcode: $raw');

      // Add to samples
      _barcodeSamples[raw] = (_barcodeSamples[raw] ?? 0) + 1;

      // Start a timer to reset samples if we stop seeing this barcode
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1000), () {
        _barcodeSamples.clear();
      });

      if (_barcodeSamples[raw]! >= _requiredSamples) {
        _isProcessing = true;
        _barcodeSamples.clear();
        HapticFeedback.mediumImpact();
        
        debugPrint('Barcode confirmed: $raw');
        widget.onDetected(raw);

        // Cooldown period
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _isProcessing = false);
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isStarting ? null : _toggleCamera,
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(borderRadiusLg),
          border: Border.all(color: borderSecondary, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadiusLg - 0.5),
          child: Stack(
            children: [
              if (_isCameraActive)
                MobileScanner(
                  key: const ValueKey('scanner'),
                  controller: _ctrl,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: colorDanger, size: 40),
                            const SizedBox(height: 12),
                            Text('Camera Error: ${error.errorCode.name}', 
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _toggleCamera(),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(foregroundColor: colorInfo),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off_rounded, color: colorInfo.withAlpha(150), size: 48),
                        const SizedBox(height: 12),
                        const Text('Camera Inactive', 
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Tap to resume scanning', 
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              // Watermark Logo
              Positioned(
                top: 14,
                left: 14,
                child: Opacity(
                  opacity: 0.8,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/NutriScanLogo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // Custom overlay
              if (_isCameraActive)
                Center(
                  child: CustomPaint(
                    size: const Size(200, 100),
                    painter: ScanFramePainter(),
                  ),
                ),
              // Status overlay when processing
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2, color: colorInfo),
                          SizedBox(height: 12),
                          Text('Confirmed! Fetching...', 
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              // Torch button
              if (_isCameraActive)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {}, // Prevent toggleCamera on tap
                    child: IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                      onPressed: () {
                        _ctrl.toggleTorch();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }
}
