import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/errors/api_exceptions.dart';
import '../data/services/stemly_api_service.dart';
import '../data/storage/offline_storage.dart';
import '../models/scan_history.dart';
import '../storage/history_store.dart';
import '../widgets/bottom_nav_bar.dart';
import 'image_cropper_screen.dart';
import 'scan_result_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isProcessing = false;
  bool _isLoadingDialogShown = false;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // ==========================================================
  // IMAGE CAPTURE / PICKER (WITH CLIENT PRE-COMPRESSION & CROPPER)
  // ==========================================================
  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessing || !mounted) return;

    try {
      setState(() => _isProcessing = true);

      // Improvement 1: Hardware-accelerated client-side pre-compression (80% network boost)
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );

      if (photo == null || !mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      File finalImage = File(photo.path);

      // Improvement 2: Document Cropper / ROI Selection UI
      // Allows students to crop directly around the problem/formula/diagram
      final File? cropped = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageCropperScreen(originalImage: finalImage),
        ),
      );

      if (cropped != null) {
        finalImage = cropped;
      }

      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }

      _showLoading();

      // 1. Perform Local OCR on cropped region
      final extractedText = await _performOCR(finalImage.path);

      // 2. Upload and generate via StemlyApiService
      await _uploadScan(finalImage, extractedText);
    } catch (e) {
      if (mounted) {
        _hideLoading();
        setState(() => _isProcessing = false);
        _showError("Failed to process image: $e");
      }
    }
  }

  Future<String> _performOCR(String path) async {
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint("OCR extraction failed (will rely on vision model): $e");
      return "";
    }
  }

  // ==========================================================
  // UPLOAD AND ANALYSIS PIPELINE
  // ==========================================================
  Future<void> _uploadScan(File image, String ocrText) async {
    final apiService = Provider.of<StemlyApiService>(context, listen: false);

    try {
      final imageBytes = await image.readAsBytes();
      final filename = image.path.split(Platform.pathSeparator).last;

      debugPrint("Uploading pre-compressed scan: ${imageBytes.lengthInBytes} bytes");

      // 1. Upload scan to backend with OCR context
      final scanData = await apiService.uploadScan(
        imageBytes: imageBytes,
        filename: filename,
        ocrText: ocrText,
      );

      final topic = scanData['topic']?.toString() ?? "Physics Problem";
      final rawVars = scanData['variables'] as List<dynamic>? ?? [];
      final variables = rawVars.map((e) => e.toString()).toList();

      // Improvement 3: Strongly-typed structured variables, target question, and formula
      final rawStructured = scanData['structured_variables'] as List<dynamic>? ?? [];
      final structuredVariables = rawStructured.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final targetQuestion = scanData['target_question']?.toString();
      final latexFormula = scanData['latex_formula']?.toString();

      final historyId = scanData['history_id']?.toString();
      final bool isDegraded = scanData['degraded'] == true;

      // 2. Save image locally for offline display
      String savedLocalPath = image.path;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
        final localFile = File('${scansDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await image.copy(localFile.path);
        savedLocalPath = localFile.path;
      } catch (e) {
        debugPrint("Warning saving local image: $e");
      }

      // 3. Generate structured notes
      final notesResponse = await apiService.generateNotes(
        topic: topic,
        variables: variables,
        imagePath: savedLocalPath,
        historyId: historyId,
        ocrText: ocrText,
      );

      final notesData = (notesResponse['notes'] as Map<String, dynamic>?) ?? {};
      final bool notesDegraded = notesResponse['degraded'] == true || isDegraded;

      // 4. Save to Offline Storage & History
      final historyItem = ScanHistory(
        imagePath: savedLocalPath,
        topic: topic,
        variables: variables,
        structuredVariables: structuredVariables,
        targetQuestion: targetQuestion,
        latexFormula: latexFormula,
        notesJson: notesData,
        timestamp: DateTime.now(),
        visualiserHistoryId: historyId,
      );

      await HistoryStore.add(historyItem);
      await OfflineStorage.saveLastNotes(
        topic: topic,
        notes: notesData,
        variables: variables,
      );

      if (mounted) {
        _hideLoading();
        setState(() => _isProcessing = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              topic: topic,
              variables: variables,
              structuredVariables: structuredVariables,
              targetQuestion: targetQuestion,
              latexFormula: latexFormula,
              notesJson: notesData,
              imagePath: savedLocalPath,
              historyItem: historyItem,
              isDegraded: notesDegraded,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        _hideLoading();
        setState(() => _isProcessing = false);
        _showError(e.friendlyMessage);
      }
    } catch (e) {
      if (mounted) {
        _hideLoading();
        setState(() => _isProcessing = false);
        _showError("Unable to analyze worksheet. Please try again.");
      }
    }
  }

  // ==========================================================
  // LOADING & ERROR MODALS
  // ==========================================================
  void _showLoading() {
    _isLoadingDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(height: 20),
                Text(
                  "Analyzing STEM Problem...",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  "Extracting equations and synthesizing simulations",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (!_isLoadingDialogShown || !mounted) return;
    _isLoadingDialogShown = false;
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // UI PRESENTATION
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.cardColor,
        elevation: 0.4,
        title: Text(
          "STEMLY",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: cs.primary,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Text(
                "Scan → Visualize → Learn",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 36),

              // Main Scan Card
              Hero(tag: "scanBtn", child: _scanBox(theme, cs)),

              const SizedBox(height: 28),

              // Quick Action Buttons (Gallery upload + Offline cached notes)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label: "Choose worksheet image from gallery",
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 20),
                      label: const Text("Gallery"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (OfflineStorage.lastNotes != null) ...[
                    const SizedBox(width: 14),
                    Semantics(
                      button: true,
                      label: "Open last cached notes offline",
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          final cached = OfflineStorage.lastNotes!;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScanResultScreen(
                                topic: cached["topic"]?.toString() ?? "Offline Notes",
                                variables: List<String>.from(cached["variables"] ?? []),
                                notesJson: Map<String, dynamic>.from(cached["notes"] ?? {}),
                                imagePath: "",
                                isDegraded: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bookmark_outline, size: 20),
                        label: const Text("Last Notes"),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _scanBox(ThemeData theme, ColorScheme cs) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.68,
        child: AspectRatio(
          aspectRatio: 1,
          child: AbsorbPointer(
            absorbing: _isProcessing,
            child: Semantics(
              button: true,
              label: "Scan STEM problem with camera",
              child: InkWell(
                onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: cs.primary,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 38,
                                height: 38,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.camera_alt_rounded,
                                color: cs.onPrimary,
                                size: 54,
                              ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isProcessing ? "Analyzing..." : "Scan to Learn",
                        style: TextStyle(
                          fontSize: 20,
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Equations, diagrams, graphs",
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
