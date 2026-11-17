import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../models/scan_history.dart';
import '../presentation/widgets/degraded_banner.dart';
import '../presentation/widgets/shimmer_skeleton.dart';
import '../presentation/widgets/state_views.dart';
import '../quiz/quiz_play_screen.dart';
import '../quiz/quiz_result_screen.dart';
import '../services/firebase_auth_service.dart';
import '../storage/history_store.dart';
import '../visualiser/visualiser_factory.dart';
import '../visualiser/visualiser_models.dart';
import '../widgets/bottom_nav_bar.dart';

class HistoryDetailScreen extends StatefulWidget {
  final ScanHistory history;

  const HistoryDetailScreen({super.key, required this.history});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final Map<String, bool> expanded = {};

  VisualTemplate? visualiserTemplate;
  Widget? visualiserWidget;
  bool loading = true;

  String get serverIp => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();

    for (var key in widget.history.notesJson.keys) {
      expanded[key] = false;
    }

    _loadVisualiser();
  }

  Future<void> _loadVisualiser() async {
    setState(() => loading = true);

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();
      final headers = {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      };

      http.Response response;

      // START CHANGE: Check for existing history ID
      final historyId = widget.history.visualiserHistoryId;
      if (historyId != null && historyId.isNotEmpty) {
        final url = Uri.parse("$serverIp/visualiser/$historyId");
        response = await http.get(url, headers: headers);
      } else {
        // Fallback to generate
        final url = Uri.parse("$serverIp/visualiser/generate");
        response = await http.post(
          url,
          headers: headers,
          body: jsonEncode({
            "topic": widget.history.topic,
            "variables": widget.history.variables,
          }),
        );
      }
      // END CHANGE

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final templateJson = data["template"];

        // Inject history_id if present
        if (data.containsKey("history_id")) {
          templateJson["history_id"] = data["history_id"];
        }

        final template = VisualTemplate.fromJson(templateJson);
        visualiserTemplate = template;
        visualiserWidget = VisualiserFactory.create(template);

        // Save ID if we didn't have it before
        if ((widget.history.visualiserHistoryId == null ||
                widget.history.visualiserHistoryId!.isEmpty) &&
            template.historyId != null) {
          widget.history.visualiserHistoryId = template.historyId;
          HistoryStore.update();
        }
      } else {
        debugPrint("Failed to load visualiser: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("History visualiser error: $e");
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.history;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final accentColor = cs.primary;
    final primaryColor = cs.primaryContainer;
    final background = theme.scaffoldBackgroundColor;
    final cardColor = theme.cardColor;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: background,
        bottomNavigationBar: BottomNavBar(currentIndex: 1),

        // ---------------- APP BAR (same as ScanResultScreen) ----------------
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          iconTheme: IconThemeData(color: accentColor),

          title: Text(
            "Scan Details",
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),

          actions: [
            IconButton(
              icon: Icon(
                h.isStarred ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 28,
              ),
              onPressed: () {
                setState(() => h.isStarred = !h.isStarred);
              },
            ),
          ],

          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(55),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: cs.onPrimary,
                  unselectedLabelColor: accentColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: "AI Visualiser"),
                    Tab(text: "AI Quiz"),
                    Tab(text: "AI Notes"),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ---------------- BODY ----------------
        body: TabBarView(
          children: [
            _visualiserTab(h, accentColor),
            _quizTab(accentColor),
            _notesTab(h, cardColor, accentColor),
          ],
        ),
      ),
    );
  }

  // ---------------- VISUAL TAB ----------------
  Widget _visualiserTab(ScanHistory h, Color accentColor) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: accentColor),
            const SizedBox(height: 16),
            Text(
              "Loading Visualisation...",
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Checking if widget is available
    final widgetAvailable = visualiserWidget != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. VISUALISER CARD
          if (widgetAvailable)
            Container(
              height: 340,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [Positioned.fill(child: visualiserWidget!)],
                ),
              ),
            )
          else
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "No visualisation available",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // 2. SCANNED IMAGE CARD
          Text(
            "Original Scan",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.file(
                File(h.imagePath),
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, _, _) => Container(
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Text("Image file not found")),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 3. DETAILS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow("Topic", h.topic, accentColor, Icons.topic_rounded),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _detailRow(
                  "Variables",
                  h.variables.join(", "),
                  accentColor,
                  Icons.functions_rounded,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1),
                ),
                _detailRow(
                  "Date",
                  "${h.timestamp.day}/${h.timestamp.month}/${h.timestamp.year}  ${h.timestamp.hour}:${h.timestamp.minute.toString().padLeft(2, '0')}",
                  accentColor,
                  Icons.calendar_today_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- NOTES TAB ----------------
  Widget _notesTab(ScanHistory h, Color cardColor, Color accentColor) {
    if (h.notesJson.containsKey("error")) {
      return ErrorStateView(
        title: "Notes Error",
        message:
            h.notesJson["error"]?.toString() ?? "Could not load saved notes.",
      );
    }

    if (h.notesJson.isEmpty) {
      return const EmptyStateView(
        icon: Icons.notes_rounded,
        title: "No Notes Available",
        message: "No notes saved for this history item.",
      );
    }

    final bool isDegraded = h.notesJson["degraded"] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          if (isDegraded) ...[
            const DegradedModeBanner(),
            const SizedBox(height: 10),
          ],
          ...h.notesJson.entries.where((e) => e.key != 'degraded').map((entry) {
            final key = entry.key;
            return _expandableCard(
              title: _formatKey(key),
              expanded: expanded[key]!,
              onTap: () => setState(() => expanded[key] = !expanded[key]!),
              child: _contentBuilder(entry.value, accentColor),
              accentColor: accentColor,
              cardColor: cardColor,
            );
          }),
        ],
      ),
    );
  }

  Widget _expandableCard({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
    required Color cardColor,
    required Color accentColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 28,
                    color: accentColor,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _contentBuilder(dynamic value, Color accentColor) {
    if (value is String) {
      return Text(value, style: TextStyle(color: accentColor, fontSize: 15));
    }
    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "• $e",
                  style: TextStyle(color: accentColor, fontSize: 15),
                ),
              ),
            )
            .toList(),
      );
    }
    if (value is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "${e.key}: ${e.value}",
                  style: TextStyle(color: accentColor, fontSize: 15),
                ),
              ),
            )
            .toList(),
      );
    }
    return const Text("Unsupported format");
  }

  String _formatKey(String raw) {
    if (raw.isEmpty) return "";
    return raw.replaceAll("_", " ").replaceFirst(raw[0], raw[0].toUpperCase());
  }

  // ==========================================================
  // QUIZ TAB
  // ==========================================================
  Widget _quizTab(Color accentColor) {
    double count = 5;

    return StatefulBuilder(
      builder: (context, setStateSB) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.quiz_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "AI Quiz Generator",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Test your knowledge on ${widget.history.topic}",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Settings Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune, color: accentColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          "Quiz Settings",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Question count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Number of Questions",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${count.toInt()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: accentColor,
                        inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                        thumbColor: accentColor,
                        overlayColor: accentColor.withValues(alpha: 0.2),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                        ),
                      ),
                      child: Slider(
                        min: 3,
                        max: 15,
                        divisions: 12,
                        value: count,
                        onChanged: (v) => setStateSB(() => count = v),
                      ),
                    ),

                    // Difficulty indicators
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _difficultyChip("Easy", Colors.green, true),
                        _difficultyChip("Medium", Colors.orange, true),
                        _difficultyChip("Hard", Colors.red, true),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _startQuiz(count.toInt()),
                  icon: const Icon(Icons.auto_awesome, size: 22),
                  label: const Text(
                    "Generate AI Quiz",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: accentColor.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Info text

              // ---------------- HISTORY LIST ----------------
              if (widget.history.quizResults.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    Icon(Icons.history, size: 20, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      "Previous Quizzes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...widget.history.quizResults.map((r) {
                  final score = r["score"];
                  final total = r["total"];
                  final pct = r["percentage"];
                  final date =
                      DateTime.tryParse(r["timestamp"] ?? "") ?? DateTime.now();

                  final Color color = pct >= 80
                      ? Colors.green
                      : (pct >= 50 ? Colors.orange : Colors.red);

                  final Map<String, dynamic> quizData = r["quizData"] != null
                      ? Map<String, dynamic>.from(r["quizData"])
                      : {};
                  final Map<String, dynamic> rawAnswers = r["answers"] != null
                      ? Map<String, dynamic>.from(r["answers"])
                      : {};

                  return GestureDetector(
                    onTap: () {
                      if (quizData.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Details not available for this quiz.",
                            ),
                          ),
                        );
                        return;
                      }

                      // Parse answers: JSON keys are strings, Map<int,int> needs ints
                      final Map<int, int> answerMap = {};
                      rawAnswers.forEach((k, v) {
                        final key = int.tryParse(k);
                        if (key != null && v is int) {
                          answerMap[key] = v;
                        }
                      });

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizResultScreen(
                            quizData: quizData,
                            answers: answerMap,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Score Circle
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                "$pct%",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Score: $score / $total",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${date.day}/${date.month}/${date.year} • ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _difficultyChip(String label, Color color, bool isIncluded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isIncluded
            ? color.withValues(alpha: 0.15)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isIncluded ? color : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isIncluded) Icon(Icons.check, size: 14, color: color),
          if (isIncluded) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: isIncluded ? color : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // START QUIZ
  // ==========================================================
  Future<void> _startQuiz(int count) async {
    final auth = context.read<FirebaseAuthService>();
    final token = await auth.getIdToken();

    if (!mounted) return;

    if (token == null) {
      _showQuizError("Authentication required. Please sign in again.");
      return;
    }

    // Show Quiz Skeleton in bottom sheet while generating
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: const QuizSkeleton(),
      ),
    );

    try {
      final response = await http
          .get(
            Uri.parse(
              "$serverIp/quiz/generate?topic=${widget.history.topic}&count=$count",
            ),
            headers: {"Authorization": "Bearer $token"},
          )
          .timeout(const Duration(seconds: 120));

      // Close loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 429) {
        _showQuizError("AI is busy. Please wait a moment and try again.");
        return;
      }

      if (response.statusCode != 200) {
        _showQuizError(
          "Failed to generate quiz. Error: ${response.statusCode}",
        );
        return;
      }

      final data = jsonDecode(response.body);

      // Check for error in response
      if (data is Map &&
          data.containsKey("error") &&
          (data["questions"] == null || (data["questions"] as List).isEmpty)) {
        _showQuizError(data["error"]?.toString() ?? "Quiz generation failed");
        return;
      }

      // Navigate to quiz screen
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuizPlayScreen(quizData: data)),
        );

        // If returned with results, save them
        if (result != null && result is Map && mounted) {
          setState(() {
            // Cast to Map<String, dynamic> manually to match the type
            widget.history.quizResults.insert(
              0,
              Map<String, dynamic>.from(result),
            );
            // Save to disk
            HistoryStore.update();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Quiz result saved to history!")),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context))
        Navigator.of(context, rootNavigator: true).pop();
      // Only show error if we haven't navigated away or if it's a real error
      if (e.toString().contains("Timeout")) {
        _showQuizError("Connection timed out. Please try again.");
      } else {
        debugPrint("Quiz error: $e");
      }
    }
  }

  void _showQuizError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Quiz Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
