import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/ocr_scan_result.dart';
import '../services/camera_service.dart';
import '../services/ocr_service.dart';

class LiveScannerScreen extends StatefulWidget {
  const LiveScannerScreen({super.key});

  @override
  State<LiveScannerScreen> createState() => _LiveScannerScreenState();
}

class _LiveScannerScreenState extends State<LiveScannerScreen> {
  final _camera = CameraService();
  final _ocr = OcrService();
  final List<String> _names = [];
  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastCandidate;
  DateTime? _detectedDate;
  Timer? _guidanceTimer;
  int _candidateHits = 0;
  bool _processing = false;
  bool _completed = false;
  bool _showCloserGuide = false;
  String? _error;

  CameraController? get _controller => _camera.controller;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final controller = await _camera.initialize();
      if (!mounted) return;
      setState(() {});
      await controller.startImageStream(_processFrame);
      _guidanceTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_completed && _detectedDate == null) {
          setState(() => _showCloserGuide = true);
        }
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      final denied =
          error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt';
      setState(() {
        _error = denied ? '실시간 인식을 사용하려면 카메라 권한이 필요해요.' : '카메라를 시작하지 못했어요.';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '카메라를 시작하지 못했어요.');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processing || _completed) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessedAt) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastProcessedAt = now;
    final inputImage = _camera.toInputImage(image);
    if (inputImage == null) return;

    _processing = true;
    try {
      final text = await _ocr.recognize(inputImage);
      var foundName = false;
      for (final name in extractProductNameCandidates(text)) {
        if (!_names.contains(name)) {
          _names.add(name);
          foundName = true;
        }
      }
      if (foundName && mounted) setState(() {});

      final dates = extractDateCandidates(text);
      if (dates.isEmpty || !mounted) {
        _candidateHits = 0;
        _lastCandidate = null;
        return;
      }
      final candidate = dates.last;
      if (_lastCandidate == candidate) {
        _candidateHits++;
      } else {
        _lastCandidate = candidate;
        _candidateHits = 1;
      }
      setState(() => _detectedDate = candidate);
      if (_candidateHits >= 2) await _completeScan(candidate, automatic: true);
    } catch (_) {
      // 다음 카메라 프레임에서 다시 시도합니다.
    } finally {
      _processing = false;
    }
  }

  Future<void> _completeScan(DateTime? date, {bool automatic = false}) async {
    if (_completed) return;
    _completed = true;
    _guidanceTimer?.cancel();
    await _controller?.stopImageStream();
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    if (date != null) setState(() => _detectedDate = date);
    if (automatic) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      OcrScanResult(
        expiryDate: date,
        productNameCandidates: _names.take(5).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _guidanceTimer?.cancel();
    _camera.dispose();
    _ocr.dispose();
    super.dispose();
  }

  String get _guideMessage {
    if (_showCloserGuide && _detectedDate == null && _names.isEmpty) {
      return '인식되지 않았어요. 조금 더 가까이 맞춰주세요';
    }
    if (_detectedDate == null) return '상품명 또는 소비기한을 화면 안에 맞춰주세요';
    return '날짜를 확인하고 있어요. 잠시만 유지해 주세요';
  }

  String get _continueLabel {
    if (_detectedDate == null) return '상품명만 입력하고 계속';
    if (_names.isEmpty) return '날짜만 입력하고 계속';
    return '인식 결과로 계속';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('소비기한 스캔'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
      ),
      body:
          _error != null
              ? _CameraError(message: _error!)
              : controller == null || !controller.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: CameraPreview(controller)),
                  Container(color: Colors.black.withValues(alpha: 0.18)),
                  Center(
                    child: Container(
                      height: 135,
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              _detectedDate == null
                                  ? Colors.white
                                  : const Color(0xFF67E29C),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 20,
                    left: 24,
                    right: 24,
                    child: Center(child: _ScanningBadge()),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 68,
                    child: Column(
                      children: [
                        if (_detectedDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6B4F),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              formatDate(_detectedDate!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Text(
                          _guideMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_names.isNotEmpty || _detectedDate != null) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            key: const Key('continueWithPartialOcrButton'),
                            onPressed: () => _completeScan(_detectedDate),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(_continueLabel),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

class _ScanningBadge extends StatelessWidget {
  const _ScanningBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF67E29C),
          ),
        ),
        SizedBox(width: 9),
        Text(
          '상품 정보 인식 중',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 52,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 17),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

@Deprecated('Use LiveScannerScreen instead.')
typedef LiveDateScannerPage = LiveScannerScreen;
