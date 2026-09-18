import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/prescription/prescription_ocr_service.dart';
import '../../themes/app_theme.dart';
import '../../widgets/sidebar.dart';
import 'prescription_review_screen.dart';

/// Capture/upload step of the prescription-to-reminder flow.
///
/// Handles image selection, permission denial, processing progress with
/// useful status text, and every error state with a manual-entry fallback.
class ScanPrescriptionScreen extends StatefulWidget {
  const ScanPrescriptionScreen({super.key});

  @override
  State<ScanPrescriptionScreen> createState() => _ScanPrescriptionScreenState();
}

class _ScanPrescriptionScreenState extends State<ScanPrescriptionScreen> {
  final _picker = ImagePicker();
  Uint8List? _preview;
  bool _processing = false;
  String _status = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    // The user can only reach this screen by explicitly choosing to scan,
    // so starting the camera straight away matches intent.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick(fromCamera: true));
  }

  Future<void> _pick({required bool fromCamera}) async {
    setState(() {
      _error = null;
      _processing = true;
      _status = fromCamera ? 'Opening camera…' : 'Opening gallery…';
    });

    try {
      final XFile? file;
      if (fromCamera) {
        final camOk = await _ensureCameraPermission();
        if (!camOk) {
          if (!mounted) return;
          _showPermissionDenied();
          return;
        }
        file = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 90,
        );
      } else {
        file = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2000,
          maxHeight: 2000,
          imageQuality: 90,
        );
      }

      if (!mounted) return;
      if (file == null) {
        // User cancelled — stay on the scan screen, no error.
        setState(() => _processing = false);
        return;
      }

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        setState(() {
          _processing = false;
          _error = 'That image could not be read. Try a different photo.';
        });
        return;
      }
      setState(() {
        _preview = bytes;
        _status = 'Enhancing prescription…';
      });

      await _runScan(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Could not process that image. Try another photo or use '
            'manual entry.';
      });
    }
  }

  Future<void> _runScan(Uint8List bytes) async {
    try {
      setState(() => _status = 'Reading prescription…');
      // Let the status render before the heavy pipeline + network call.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final result = await PrescriptionOcrService.scan(bytes);

      if (!mounted) return;
      setState(() => _status = 'Identifying medications…');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrescriptionReviewScreen(
            result: result,
            previewBytes: _preview,
          ),
        ),
      );
    } on PrescriptionScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.userMessage;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Something went wrong while reading the prescription. '
            'Please try again or use manual entry.';
        // Never log image bytes or extracted medical data.
      });
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied || status.isRestricted) return false;
    status = await Permission.camera.request();
    return status.isGranted;
  }

  void _showPermissionDenied() {
    setState(() => _processing = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera Permission Needed'),
        content: const Text(
          'To scan a prescription, LifeSphere needs camera access. You can '
          'also upload a photo from your gallery instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pick(fromCamera: false);
            },
            child: const Text('Use Gallery'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prescription'),
      ),
      body: SafeArea(
        child: _processing ? _buildProcessing() : _buildIdle(),
      ),
    );
  }

  // ------------------------------------------------------------ processing

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _preview == null
                ? Container(
                    width: 180,
                    height: 180,
                    color: AppTheme.background,
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : Image.memory(
                    _preview!,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 28),
          Text(_status, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ idle

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.document_scanner_rounded,
                size: 52,
                color: AppTheme.secondary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 14),
              Text(
                'Photograph the prescription',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Lay the paper flat, avoid shadows, and fill the frame. '
                'You will review everything before any reminder is created.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppTheme.danger, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton.icon(
                onPressed: () => _pick(fromCamera: true),
                icon: const Icon(Icons.photo_camera_rounded, size: 20),
                label: const Text('Take Photo'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pick(fromCamera: false),
                icon: const Icon(Icons.photo_library_rounded, size: 20),
                label: const Text('Upload from Gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
