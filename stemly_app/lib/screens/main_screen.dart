import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/errors/api_exceptions.dart';
import '../data/services/stemly_api_service.dart';
import '../data/storage/offline_storage.dart';
import '../models/scan_history.dart';
import '../presentation/components/components.dart';
import '../storage/history_store.dart';
import '../strings.dart';
import '../theme/theme.dart';
import 'image_cropper_screen.dart';
import 'scan_result_screen.dart';

/// HIG-compliant Home Screen for STEMLY.
/// Content-first: Single hero scan card, gallery quick action, last scan rehydration,
/// recent scans list with 56 dp thumbnails, and explore topics chips.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  int _processingStep = 0; // 0: Reading, 1: Identifying, 2: Preparing notes

  final List<String> _exploreTopics = const [
    "Projectile motion",
    "Optics",
    "Kinematics",
    "Circuits",
    "Waves",
    "Thermodynamics",
  ];

  @override
  void initState() {
    super.initState();
    // Warm up offline storage
    OfflineStorage.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  // ==========================================================
  // IMAGE CAPTURE / PICKER PIPELINE
  // ==========================================================
  Future<void> _pickImage(ImageSource source) async {
    if (_isProcessing || !mounted) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );

      if (photo == null || !mounted) return;

      File finalImage = File(photo.path);

      // Launch Document Cropper
      final File? cropped = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageCropperScreen(originalImage: finalImage),
        ),
      );

      if (cropped != null) {
        finalImage = cropped;
      }

      if (!mounted) return;

      await _uploadAndProcessScan(finalImage);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError("Unable to open image: $e");
      }
    }
  }

  Future<void> _uploadAndProcessScan(File image) async {
    final apiService = Provider.of<StemlyApiService>(context, listen: false);

    setState(() {
      _isProcessing = true;
      _processingStep = 0;
    });

    try {
      final imageBytes = await image.readAsBytes();
      final filename = image.path.split(Platform.pathSeparator).last;

      if (mounted) setState(() => _processingStep = 1);

      // 1. Upload scan
      final scanData = await apiService.uploadScan(
        imageBytes: imageBytes,
        filename: filename,
      );

      final topic = scanData['topic']?.toString() ?? "Physics Problem";
      final rawVars = scanData['variables'] as List<dynamic>? ?? [];
      final variables = rawVars.map((e) => e.toString()).toList();
      final extractedText = scanData['extracted_text']?.toString() ?? "";

      final rawStructured = scanData['structured_variables'] as List<dynamic>? ?? [];
      final structuredVariables =
          rawStructured.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final targetQuestion = scanData['target_question']?.toString();
      final latexFormula = scanData['latex_formula']?.toString();
      final historyId = scanData['history_id']?.toString();
      final bool isDegraded = scanData['degraded'] == true;

      // 2. Cache image locally
      String savedLocalPath = image.path;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final scansDir = Directory('${appDir.path}/scans');
        if (!await scansDir.exists()) await scansDir.create(recursive: true);
        final localFile =
            File('${scansDir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await image.copy(localFile.path);
        savedLocalPath = localFile.path;
      } catch (e) {
        debugPrint("Warning saving local image: $e");
      }

      if (mounted) setState(() => _processingStep = 2);

      // 3. Generate notes
      final notesResponse = await apiService.generateNotes(
        topic: topic,
        variables: variables,
        imagePath: savedLocalPath,
        historyId: historyId,
        ocrText: extractedText,
      );

      final notesData = (notesResponse['notes'] as Map<String, dynamic>?) ?? {};
      final bool notesDegraded = notesResponse['degraded'] == true || isDegraded;

      // 4. Save to history
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
        setState(() => _isProcessing = false);
        _showError(e.friendlyMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError("Unable to analyze worksheet. Please try again.");
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error(context),
      ),
    );
  }

  void _continueLastScan() {
    final history = HistoryStore.history;
    if (history.isNotEmpty) {
      final last = history.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            topic: last.topic,
            variables: last.variables,
            structuredVariables: last.structuredVariables,
            targetQuestion: last.targetQuestion,
            latexFormula: last.latexFormula,
            notesJson: last.notesJson,
            imagePath: last.imagePath,
            historyItem: last,
            isDegraded: false,
          ),
        ),
      );
    } else if (OfflineStorage.lastNotes != null) {
      final cached = OfflineStorage.lastNotes!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            topic: cached["topic"]?.toString() ?? "Saved Notes",
            variables: List<String>.from(cached["variables"] ?? []),
            notesJson: Map<String, dynamic>.from(cached["notes"] ?? {}),
            imagePath: "",
            isDegraded: true,
          ),
        ),
      );
    }
  }

  String _formatRelativeDate(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) {
      return "Today";
    } else if (diff.inDays == 1) {
      return "Yesterday";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} days ago";
    } else {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = HistoryStore.history;
    final hasHistory = history.isNotEmpty || OfflineStorage.lastNotes != null;
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Stack(
      children: [
        AppScaffold(
          title: AppStrings.homeTitle,
          isLargeTitle: true,
          currentBottomNavIndex: 0,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),

                // 1. HERO SCAN CARD (THE ONLY FILLED PRIMARY ELEMENT)
                Semantics(
                  button: true,
                  label: "Scan a problem using camera",
                  hint: AppStrings.cameraPermissionRationale,
                  child: InkWell(
                    onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xl,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary(context),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary(context).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            AppStrings.scanCardTitle,
                            style: AppTypography.title2(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            AppStrings.scanCardSubtitle,
                            style: AppTypography.subhead(context).copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // 2. SECONDARY ACTION ROW (GALLERY + CONTINUE LAST SCAN)
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: AppStrings.chooseFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 20),
                        onPressed:
                            _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SecondaryButton(
                        label: AppStrings.continueLastScan,
                        icon: const Icon(Icons.history_rounded, size: 20),
                        onPressed: hasHistory ? _continueLastScan : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 3. EXPLORE TOPICS (HORIZONTAL CHIPS)
                Text(
                  AppStrings.exploreTopics,
                  style: AppTypography.headline(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _exploreTopics.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final topic = _exploreTopics[index];
                      return ActionChip(
                        label: Text(
                          topic,
                          style: AppTypography.footnote(context).copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: AppColors.surface(context),
                        side: BorderSide(color: AppColors.divider(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Explore $topic: scan a problem to begin."),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // 4. RECENT SCANS SECTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.recentScansSection,
                      style: AppTypography.headline(context),
                    ),
                    if (history.isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/history'),
                        child: Text(
                          AppStrings.seeAll,
                          style: AppTypography.subhead(context).copyWith(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                if (history.isEmpty)
                  const EmptyState(
                    icon: Icons.document_scanner_outlined,
                    title: AppStrings.emptyHomeTitle,
                    message: AppStrings.emptyHomeMessage,
                  )
                else
                  GroupedSection(
                    children: history.take(3).map((item) {
                      final file = File(item.imagePath);
                      final hasImage = item.imagePath.isNotEmpty && file.existsSync();

                      return GroupedRow(
                        leading: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(AppRadii.input),
                            image: hasImage
                                ? DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: !hasImage
                              ? Icon(
                                  Icons.science_outlined,
                                  color: AppColors.primary(context),
                                  size: 26,
                                )
                              : null,
                        ),
                        title: item.topic,
                        subtitle: _formatRelativeDate(item.timestamp),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: textSecondary,
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScanResultScreen(
                                topic: item.topic,
                                variables: item.variables,
                                structuredVariables: item.structuredVariables,
                                targetQuestion: item.targetQuestion,
                                latexFormula: item.latexFormula,
                                notesJson: item.notesJson,
                                imagePath: item.imagePath,
                                historyItem: item,
                                isDegraded: false,
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),

        // FULL-SCREEN PROCESSING STATE (HIG compliant with step list & cancel)
        if (_isProcessing)
          Positioned.fill(
            child: Material(
              color: AppColors.background(context).withValues(alpha: 0.95),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppStrings.processingTitle,
                        style: AppTypography.title2(context).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Steps
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Column(
                          children: [
                            _buildProgressStep(
                              context,
                              stepIndex: 0,
                              currentIndex: _processingStep,
                              label: AppStrings.stepReadingImage,
                            ),
                            const Divider(height: AppSpacing.md),
                            _buildProgressStep(
                              context,
                              stepIndex: 1,
                              currentIndex: _processingStep,
                              label: AppStrings.stepIdentifyingTopic,
                            ),
                            const Divider(height: AppSpacing.md),
                            _buildProgressStep(
                              context,
                              stepIndex: 2,
                              currentIndex: _processingStep,
                              label: AppStrings.stepPreparingNotes,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      SecondaryButton(
                        label: AppStrings.cancel,
                        onPressed: () {
                          setState(() => _isProcessing = false);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressStep(
    BuildContext context, {
    required int stepIndex,
    required int currentIndex,
    required String label,
  }) {
    final isDone = currentIndex > stepIndex;
    final isCurrent = currentIndex == stepIndex;

    return Row(
      children: [
        if (isDone)
          Icon(Icons.check_circle_rounded, color: AppColors.success(context), size: 22)
        else if (isCurrent)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary(context),
            ),
          )
        else
          Icon(
            Icons.radio_button_unchecked_rounded,
            color: AppColors.textSecondary(context),
            size: 22,
          ),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: AppTypography.body(context).copyWith(
            color: isCurrent
                ? AppColors.textPrimary(context)
                : AppColors.textSecondary(context),
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
