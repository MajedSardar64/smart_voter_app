import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/db_service.dart';
import '../utils/bangla_helper.dart';
import 'voter_detail_screen.dart';
import 'search_results_screen.dart';

class NidLiveScannerScreen extends StatefulWidget {
  const NidLiveScannerScreen({super.key});

  @override
  State<NidLiveScannerScreen> createState() => _NidLiveScannerScreenState();
}

class _NidLiveScannerScreenState extends State<NidLiveScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isDisposed = false;
  bool _isFlashOn = false;
  bool _hasPermissionError = false;

  late AnimationController _laserController;
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // অ্যাপ চালু হওয়ার সাথে সাথে ক্যামেরা পারমিশন ও ইনিশিয়ালাইজেশন
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSmoothCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    // পারমিশন দিয়ে ফিরে আসলে স্বয়ংক্রিয়ভাবে ক্যামেরা রিস্টার্ট হবে (অ্যাপ কাটতে হবে না)
    if (state == AppLifecycleState.resumed) {
      _initSmoothCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopAndDisposeCamera();
    }
  }

  void _initSmoothCamera() async {
    if (_isDisposed) return;

    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _cameraController!.initialize();
        if (_isDisposed) return;

        try {
          await _cameraController!.setFocusMode(FocusMode.auto);
          await _cameraController!.setExposureMode(ExposureMode.auto);
        } catch (_) {}

        if (!mounted || _isDisposed) return;
        setState(() {
          _isCameraReady = true;
          _hasPermissionError = false;
        });
      }
    } catch (e) {
      if (mounted && !_isDisposed) {
        setState(() {
          _hasPermissionError = true;
          _isCameraReady = false;
        });
      }
    }
  }

  void _stopAndDisposeCamera() {
    try {
      _cameraController?.dispose();
      _cameraController = null;
      _isCameraReady = false;
    } catch (_) {}
  }

  void _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    try {
      if (_isFlashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (_) {}
  }

  // ১. জন্মতারিখ -> ২. বাংলা নাম -> ৩. পিতা/মাতা -> ৪. ইংরেজি নাম -> ৫. NID ক্রমানুসারে সার্চ
  Future<void> _captureAndProcess() async {
    if (_isDisposed ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing)
      return;

    try {
      setState(() => _isProcessing = true);

      final XFile picture = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      final parsedData = _extractNidInfo(recognizedText);

      // নির্ধারিত প্রায়োরিটি অনুযায়ী ডাটাবেজে সার্চ
      final results = await DBService.instance.searchByNidOrOCR(
        dob: parsedData['dob'],
        banglaName: parsedData['banglaName'],
        father: parsedData['father'],
        mother: parsedData['mother'],
        englishName: parsedData['englishName'],
        nid: parsedData['nid'],
      );

      try {
        File(picture.path).delete();
      } catch (_) {}

      if (!mounted || _isDisposed) return;
      setState(() => _isProcessing = false);

      if (results.length == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VoterDetailScreen(voter: results.first),
          ),
        );
      } else if (results.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchResultsScreen(
              filterText:
                  'NID: ${parsedData['name']!.isNotEmpty ? parsedData['name'] : parsedData['dob']}',
              directResults: results,
            ),
          ),
        );
      } else {
        _showResultDialog(parsedData);
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Map<String, String> _extractNidInfo(RecognizedText recognized) {
    String extractedNid = '';
    String extractedEnglishName = '';
    String extractedBanglaName = '';
    String extractedFather = '';
    String extractedMother = '';
    String extractedDob = '';

    List<TextLine> allLines = [];
    for (var block in recognized.blocks) {
      allLines.addAll(block.lines);
    }
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rawLines = allLines.map((l) => l.text.trim()).toList();
    final fullText = rawLines.join('\n');

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];

      // ১. জন্মতারিখ (Date of Birth / জন্ম)
      if (line.toLowerCase().contains('birth') ||
          line.contains('Date') ||
          line.contains('জন্ম')) {
        final dobMatch = RegExp(
          r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})|(\d{1,2}[/-]\d{1,2}[/-]\d{4})',
        ).firstMatch(line);
        if (dobMatch != null) {
          extractedDob = dobMatch.group(0)!;
        } else if (i + 1 < rawLines.length) {
          final nextMatch = RegExp(
            r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})|(\d{1,2}[/-]\d{1,2}[/-]\d{4})',
          ).firstMatch(rawLines[i + 1]);
          if (nextMatch != null) extractedDob = nextMatch.group(0)!;
        }
      }

      // ২. বাংলা নাম
      if (line.contains('নাম:') || line.startsWith('নাম')) {
        extractedBanglaName = line.replaceAll(RegExp(r'নাম[:\s]*'), '').trim();
      }

      // ৩. ইংরেজি নাম
      if (line.startsWith('Name') || line.contains('Name:')) {
        extractedEnglishName = line
            .replaceAll(RegExp(r'Name[:\s]*', caseSensitive: false), '')
            .trim();
        if (i > 0 &&
            extractedBanglaName.isEmpty &&
            !rawLines[i - 1].contains('Card') &&
            !rawLines[i - 1].contains('Republic')) {
          extractedBanglaName = rawLines[i - 1]
              .replaceAll(RegExp(r'নাম[:\s]*'), '')
              .trim();
        }
      }

      // ৪. পিতার নাম
      if (line.contains('পিতা:') || line.contains('Father')) {
        extractedFather = line
            .replaceAll(
              RegExp(r'(পিতা|Father)[:\s]*', caseSensitive: false),
              '',
            )
            .trim();
        if (extractedFather.isEmpty && i + 1 < rawLines.length) {
          extractedFather = rawLines[i + 1].trim();
        }
      }

      // ৫. মাতার নাম
      if (line.contains('মাতা:') || line.contains('Mother')) {
        extractedMother = line
            .replaceAll(
              RegExp(r'(মাতা|Mother)[:\s]*', caseSensitive: false),
              '',
            )
            .trim();
        if (extractedMother.isEmpty && i + 1 < rawLines.length) {
          extractedMother = rawLines[i + 1].trim();
        }
      }

      // ৬. NID / ID NO
      if (RegExp(
        r'(NID|ID|NO|No|Card|নং)',
        caseSensitive: false,
      ).hasMatch(line)) {
        final digits = line.replaceAll(RegExp(r'[^\d]'), '');
        if (digits.length >= 10 && digits.length <= 17) extractedNid = digits;
      }
    }

    if (extractedNid.isEmpty) {
      final cleanDigitsMatch = RegExp(r'\b\d{10}\b|\b\d{13}\b|\b\d{17}\b')
          .firstMatch(fullText.replaceAll(' ', ''));
      if (cleanDigitsMatch != null) extractedNid = cleanDigitsMatch.group(0)!;
    }

    return {
      'dob': extractedDob,
      'name': extractedBanglaName.isNotEmpty
          ? extractedBanglaName
          : extractedEnglishName,
      'banglaName': extractedBanglaName,
      'englishName': extractedEnglishName,
      'father': extractedFather,
      'mother': extractedMother,
      'nid': extractedNid,
    };
  }

  void _showResultDialog(Map<String, String> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF00695C)),
            SizedBox(width: 8),
            Text(
              'শনাক্তকৃত তথ্য',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoTile(
              '১. জন্ম তারিখ:',
              data['dob']!.isEmpty
                  ? 'শনাক্ত হয়নি'
                  : BanglaHelper.formatDobToBangla(data['dob']!),
              isBold: true,
            ),
            _infoTile(
              '২. নাম:',
              data['name']!.isEmpty ? 'শনাক্ত হয়নি' : data['name']!,
            ),
            _infoTile(
              '৩. পিতা:',
              data['father']!.isEmpty ? 'শনাক্ত হয়নি' : data['father']!,
            ),
            _infoTile(
              '৪. মাতা:',
              data['mother']!.isEmpty ? 'শনাক্ত হয়নি' : data['mother']!,
            ),
            _infoTile(
              '৫. NID নম্বর:',
              data['nid']!.isEmpty
                  ? 'শনাক্ত হয়নি'
                  : BanglaHelper.toBanglaDigits(data['nid']!),
            ),
            const SizedBox(height: 8),
            const Text(
              'তথ্য দিয়ে ভোটার অনুসন্ধান করবেন?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                _cameraController?.resumePreview();
              } catch (_) {}
            },
            child: const Text(
              'বাতিল / আবার তুলুন',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final results = await DBService.instance.searchByNidOrOCR(
                dob: data['dob'],
                banglaName: data['banglaName'],
                father: data['father'],
                mother: data['mother'],
                englishName: data['englishName'],
                nid: data['nid'],
              );

              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchResultsScreen(
                    filterText:
                        'NID: ${data['name']!.isNotEmpty ? data['name'] : data['dob']}',
                    directResults: results,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00695C),
            ),
            child: const Text(
              'সার্চ করুন',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? const Color(0xFF0D47A1) : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _laserController.dispose();
    _stopAndDisposeCamera();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasPermissionError) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('ক্যামেরা পারমিশন আবশ্যক')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.no_photography,
                  size: 60,
                  color: Colors.orange,
                ),
                const SizedBox(height: 14),
                const Text(
                  'ক্যামেরা ব্যবহারের পারমিশন দিন',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _initSmoothCamera,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ক্যামেরা চালু করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isDisposed ||
        !_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00695C)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _cameraController!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('স্মার্ট এন.আই.ডি স্ক্যানার'),
        centerTitle: true,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.amberAccent : Colors.white,
            ),
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(_cameraController!)),
            ),
          ),

          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.90,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(14),
                color: Colors.black.withOpacity(0.12),
              ),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserController.value * 200,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.greenAccent,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Text(
                          'এনআইডি কার্ড ফ্রেমের ভেতরে সোজা রাখুন',
                          style: TextStyle(
                            color: Colors.white,
                            backgroundColor: Colors.black54,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Text(
                          'নিচের বাটনে চাপ দিলে তাৎক্ষণিক ভোটার বের হবে',
                          style: TextStyle(
                            color: Colors.white70,
                            backgroundColor: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 35,
            child: FloatingActionButton.extended(
              onPressed: _isProcessing ? null : _captureAndProcess,
              backgroundColor: const Color(0xFF00695C),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.camera_alt, size: 24),
              label: Text(
                _isProcessing
                    ? 'স্ক্যান হচ্ছে...'
                    : 'ছবি তুলুন ও ভোটার বের করুন',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
