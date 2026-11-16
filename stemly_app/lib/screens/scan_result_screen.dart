import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/config/app_config.dart';
import '../models/scan_history.dart';
import '../presentation/components/components.dart';
import '../presentation/widgets/degraded_banner.dart';
import '../presentation/widgets/shimmer_skeleton.dart';
import '../presentation/widgets/state_views.dart';
import '../quiz/quiz_play_screen.dart';
import '../services/firebase_auth_service.dart';
import '../storage/history_store.dart';
import '../strings.dart';
import '../theme/theme.dart';
import '../visualiser/visualiser_factory.dart';
import '../visualiser/visualiser_models.dart';

/// HIG-compliant Scan Result Screen for STEMLY.
/// Content-first: 4:3 Hero simulation canvas at the top, accessible sliders & stat tiles,
/// rendered equations via MathTexView (zero raw LaTeX), clean AI assistant, and structured notes.
class ScanResultScreen extends StatefulWidget {
  final String topic;
  final List<String> variables;
  final Map<String, dynamic> notesJson;
  final String imagePath;
  final ScanHistory? historyItem;
  final bool isDegraded;
  final List<Map<String, dynamic>> structuredVariables;
  final String? targetQuestion;
  final String? latexFormula;

  const ScanResultScreen({
    super.key,
    required this.topic,
    required this.variables,
    required this.notesJson,
    required this.imagePath,
    this.historyItem,
    this.isDegraded = false,
    this.structuredVariables = const [],
    this.targetQuestion,
    this.latexFormula,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final Map<String, bool> _notesExpanded = {};

  VisualTemplate? _visualiserTemplate;
  Widget? _visualiserWidget;
  bool _loadingVisualiser = true;
  String? _scanHistoryId;
  Map<String, String> _simulationStats = {};

  // Image Generation Fallback State
  String? _generatedImageUrl;
  bool _generatingImage = false;

  // AI Chat State
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isSendingChat = false;
  final ScrollController _chatScrollController = ScrollController();

  String get _serverIp => AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();

    for (var key in widget.notesJson.keys) {
      _notesExpanded[key] = false;
    }

    _loadVisualiser();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // ==========================================================
  // VISUALISER LOADER (ZERO BUILD-PHASE SETSTATE)
  // ==========================================================
  Future<void> _loadVisualiser() async {
    setState(() => _loadingVisualiser = true);

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        if (mounted) setState(() => _loadingVisualiser = false);
        return;
      }

      final response = await http.post(
        Uri.parse("$_serverIp/visualiser/generate"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "topic": widget.topic,
          "variables": widget.variables,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Visualiser API Error: ${response.statusCode}");
        if (mounted) setState(() => _loadingVisualiser = false);
        return;
      }

      final data = jsonDecode(response.body);
      final templateJson = data["template"];
      if (data.containsKey("history_id")) {
        templateJson["history_id"] = data["history_id"];
        _scanHistoryId = data["history_id"];
      }

      final template = VisualTemplate.fromJson(templateJson);

      if (template.historyId != null && widget.historyItem != null) {
        widget.historyItem!.visualiserHistoryId = template.historyId;
        HistoryStore.update();
      }

      if (mounted) {
        setState(() {
          _visualiserTemplate = template;
          _visualiserWidget = VisualiserFactory.create(
            template,
            onSimulationUpdate: (stats) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _simulationStats = stats);
              });
            },
          );
          _loadingVisualiser = false;
        });
      }
    } catch (e) {
      debugPrint("Visualiser error: $e");
      if (mounted) setState(() => _loadingVisualiser = false);
    }
  }

  void _updateWidgetFromTemplate() {
    if (_visualiserTemplate == null) return;
    setState(() {
      _visualiserWidget = VisualiserFactory.create(
        _visualiserTemplate!,
        onSimulationUpdate: (stats) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _simulationStats = stats);
          });
        },
      );
    });
  }

  Future<void> _generateImage() async {
    setState(() => _generatingImage = true);
    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$_serverIp/visualiser/generate-image"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"prompt": "${widget.topic} ${widget.variables.join(' ')}"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _generatedImageUrl = data["image_url"]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate image")),
        );
      }
    } catch (e) {
      debugPrint("Image gen error: $e");
    } finally {
      if (mounted) setState(() => _generatingImage = false);
    }
  }

  Future<void> _sendChatMessage(String userText) async {
    final text = userText.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({"text": text, "isUser": true});
      _isSendingChat = true;
      _chatController.clear();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      if (_visualiserTemplate == null) {
        setState(() {
          _chatMessages.add({"text": "No active simulation to control.", "isUser": false});
          _isSendingChat = false;
        });
        return;
      }

      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      final params = <String, dynamic>{};
      _visualiserTemplate!.parameters.forEach((k, v) => params[k] = v.value);

      final response = await http.post(
        Uri.parse("$_serverIp/visualiser/update"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "template_id": _visualiserTemplate!.templateId,
          "parameters": params,
          "user_prompt": text,
          "history_id": _scanHistoryId,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result.containsKey("ai_response")) {
          setState(() {
            _chatMessages.add({"text": result["ai_response"], "isUser": false});
          });
        }

        if (result.containsKey("parameters")) {
          final newParams = result["parameters"] as Map<String, dynamic>;
          bool changed = false;
          _visualiserTemplate!.parameters.forEach((key, param) {
            if (newParams.containsKey(key)) {
              param.value = (newParams[key] as num).toDouble();
              changed = true;
            }
          });
          if (changed) {
            _updateWidgetFromTemplate();
          }
        }
      } else {
        setState(() => _chatMessages.add({"text": "Failed to update parameters.", "isUser": false}));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _chatMessages.add({"text": "Error: ${e.toString()}", "isUser": false});
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingChat = false);
      }
    }
  }

  // ==========================================================
  // ROOT BUILD WITH HIG TAB BAR
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final surface = AppColors.surface(context);
    final textPrimary = AppColors.textPrimary(context);
    final primary = AppColors.primary(context);

    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Visualiser tab hero by default
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: AppStrings.back,
          ),
          title: Text(
            widget.topic,
            style: AppTypography.headline(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: primary,
            labelColor: primary,
            unselectedLabelColor: AppColors.textSecondary(context),
            labelStyle: AppTypography.headline(context).copyWith(fontWeight: FontWeight.bold),
            unselectedLabelStyle: AppTypography.headline(context),
            tabs: const [
              Tab(
                text: AppStrings.tabNotes,
                icon: Icon(Icons.description_outlined, size: 20),
              ),
              Tab(
                text: AppStrings.tabVisualiser,
                icon: Icon(Icons.play_circle_outline_rounded, size: 20),
              ),
              Tab(
                text: AppStrings.tabQuiz,
                icon: Icon(Icons.quiz_outlined, size: 20),
              ),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Simulations capture drag gestures
          children: [
            _buildNotesTab(context),
            _buildVisualiserTab(context),
            _buildQuizSetupTab(context),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // TAB 1: NOTES TAB (WITH MATH RENDERER & ACCORDIONS)
  // ==========================================================
  Widget _buildNotesTab(BuildContext context) {
    if (widget.notesJson.containsKey("error")) {
      return ErrorStateView(
        title: "Notes Generation Failed",
        message: widget.notesJson["error"]?.toString() ?? "Could not synthesize notes for this topic.",
      );
    }

    if (widget.notesJson.isEmpty) {
      return const EmptyStateView(
        icon: Icons.notes_rounded,
        title: "No Notes Available",
        message: "Notes could not be synthesized for this topic.",
      );
    }

    final bool isDegraded = widget.isDegraded || (widget.notesJson["degraded"] == true);
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Problem Objective & Equation Card
          _buildProblemObjectiveCard(context),

          if (isDegraded) ...[
            const DegradedModeBanner(),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Notes Accordions
          ...widget.notesJson.entries.where((e) => e.key != 'degraded' && e.key != 'error').map((entry) {
            final key = entry.key;
            final isExpanded = _notesExpanded[key] ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    border: Border.all(color: divider),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: PageStorageKey<String>(key),
                      initiallyExpanded: isExpanded,
                      onExpansionChanged: (val) {
                        setState(() => _notesExpanded[key] = val);
                      },
                      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                      title: Text(
                        _formatKey(key),
                        style: AppTypography.headline(context),
                      ),
                      children: [
                        _buildNoteContent(context, entry.value),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildNoteContent(BuildContext context, dynamic value) {
    if (value is String) {
      if (value.contains(r'\') || value.contains('^') || value.contains('_')) {
        return MathTexView(
          formula: value,
          textStyle: AppTypography.body(context),
        );
      }
      return Text(
        value,
        style: AppTypography.body(context).copyWith(height: 1.4),
      );
    }

    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.map((item) {
          final str = item.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: AppTypography.body(context).copyWith(color: AppColors.primary(context))),
                Expanded(
                  child: str.contains(r'\')
                      ? MathTexView(formula: str, textStyle: AppTypography.body(context))
                      : Text(str, style: AppTypography.body(context)),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    if (value is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              "${_formatKey(e.key.toString())}: ${e.value}",
              style: AppTypography.body(context),
            ),
          );
        }).toList(),
      );
    }

    return Text(value.toString(), style: AppTypography.body(context));
  }

  // ==========================================================
  // TAB 2: VISUALISER TAB (HERO 4:3 CANVAS AT VERY TOP)
  // ==========================================================
  Widget _buildVisualiserTab(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HERO: INTERACTIVE SIMULATION CANVAS (4:3 RATIO, MAX 40% HEIGHT)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: min(350.0, MediaQuery.of(context).size.height * 0.40),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: _buildSimulationContent(context),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 2. TELEMETRY STAT TILES (RANGE, MAX HEIGHT, FLIGHT TIME)
          if (_simulationStats.isNotEmpty) ...[
            Row(
              children: _simulationStats.entries.take(3).map((e) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                      border: Border.all(color: divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.key,
                          style: AppTypography.footnote(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.value,
                          style: AppTypography.headline(context).copyWith(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 3. SIMULATION PARAMETERS (SLIDERS WITH MONOSPACE VALUES & RESET)
          if (_visualiserTemplate != null && _visualiserTemplate!.parameters.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: AppColors.primary(context), size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            AppStrings.simulationParameters,
                            style: AppTypography.headline(context),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // Reset to defaults
                          _loadVisualiser();
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, AppSpacing.minTouchTarget),
                        ),
                        child: Text(
                          AppStrings.resetCrop,
                          style: AppTypography.footnote(context).copyWith(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  ..._visualiserTemplate!.parameters.entries.map((e) {
                    final param = e.value;
                    final double val = param.value;
                    final double minVal = param.min;
                    final double maxVal =
                        param.max > param.min ? param.max : (val > 0 ? val * 2 : 100.0);
                    final String label = param.label.isNotEmpty ? param.label : _formatKey(e.key);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: AppTypography.subhead(context)),
                              Text(
                                "${val.toStringAsFixed(1)} ${param.unit}".trim(),
                                style: AppTypography.numeric(context, fontSize: 13),
                              ),
                            ],
                          ),
                          Slider(
                            value: val.clamp(minVal, maxVal),
                            min: minVal,
                            max: maxVal,
                            activeColor: AppColors.primary(context),
                            onChanged: (newVal) {
                              setState(() {
                                param.value = newVal;
                                _updateWidgetFromTemplate();
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 4. PROBLEM TARGET & FORMULAS CARD (WITH MATHTEXVIEW)
          _buildProblemObjectiveCard(context),

          const SizedBox(height: AppSpacing.md),

          // 5. AI ASSISTANT CARD
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.primary(context), size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.aiAssistant,
                      style: AppTypography.headline(context),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.aiAssistantPlaceholder,
                  style: AppTypography.footnote(context),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Suggestion chips
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ActionChip(
                      label: Text(
                        AppStrings.chipExplainGravity,
                        style: AppTypography.caption(context),
                      ),
                      onPressed: () => _sendChatMessage("Explain gravity in this problem"),
                    ),
                    ActionChip(
                      label: Text(
                        AppStrings.chipSetVelocity,
                        style: AppTypography.caption(context),
                      ),
                      onPressed: () => _sendChatMessage("Set velocity to 50"),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Chat Messages Container
                Container(
                  height: 180,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(AppRadii.input),
                  ),
                  child: _chatMessages.isEmpty
                      ? Center(
                          child: Text(
                            "Type a question to explore this concept.",
                            style: AppTypography.footnote(context),
                          ),
                        )
                      : ListView.builder(
                          controller: _chatScrollController,
                          itemCount: _chatMessages.length,
                          itemBuilder: (context, idx) {
                            final msg = _chatMessages[idx];
                            final isUser = msg["isUser"] == true;

                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? AppColors.primary(context)
                                      : surface,
                                  borderRadius: BorderRadius.circular(AppRadii.button),
                                ),
                                child: Text(
                                  msg["text"] ?? "",
                                  style: AppTypography.subhead(context).copyWith(
                                    color: isUser ? Colors.white : textPrimary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Chat Input Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: AppTypography.body(context),
                        decoration: InputDecoration(
                          hintText: "Ask AI assistant...",
                          hintStyle: AppTypography.subhead(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.input),
                            borderSide: BorderSide(color: divider),
                          ),
                        ),
                        onSubmitted: _sendChatMessage,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      icon: _isSendingChat
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary(context),
                              ),
                            )
                          : Icon(Icons.send_rounded, color: AppColors.primary(context)),
                      onPressed: _isSendingChat ? null : () => _sendChatMessage(_chatController.text),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildSimulationContent(BuildContext context) {
    if (_loadingVisualiser) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary(context),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Preparing interactive simulation...",
              style: AppTypography.subhead(context),
            ),
          ],
        ),
      );
    }

    if (_visualiserWidget != null) {
      return _visualiserWidget!;
    }

    // Fallback if no simulation available
    if (_generatedImageUrl != null) {
      return Image.network(
        _generatedImageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textSecondary(context)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Could not load diagram",
                style: AppTypography.subhead(context),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 48, color: AppColors.textSecondary(context)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Interactive simulation unavailable for this topic.",
              style: AppTypography.subhead(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_generatingImage)
              const CircularProgressIndicator(strokeWidth: 2.5)
            else
              SecondaryButton(
                label: "Generate diagram",
                icon: const Icon(Icons.auto_awesome, size: 18),
                onPressed: _generateImage,
                width: 200,
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PROBLEM OBJECTIVE & FORMULAS (ZERO EMOJIS, WITH MATHTEXVIEW)
  // ==========================================================
  Widget _buildProblemObjectiveCard(BuildContext context) {
    final target = widget.targetQuestion ?? widget.historyItem?.targetQuestion;
    final formula = widget.latexFormula ?? widget.historyItem?.latexFormula;
    final structured = widget.structuredVariables.isNotEmpty
        ? widget.structuredVariables
        : (widget.historyItem?.structuredVariables ?? []);

    if (target == null && formula == null && structured.isEmpty && widget.variables.isEmpty) {
      return const SizedBox.shrink();
    }

    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Target Objective
          if (target != null && target.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: AppColors.primary(context).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.track_changes_rounded,
                    color: AppColors.primary(context),
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.targetObjective,
                          style: AppTypography.footnote(context).copyWith(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          target,
                          style: AppTypography.subhead(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Governing Formula Card with MathTexView (NO raw LaTeX!)
          if (formula != null && formula.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.all(color: divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.functions_rounded, size: 16, color: AppColors.primary(context)),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.governingEquation,
                        style: AppTypography.caption(context).copyWith(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: MathTexView(
                      formula: formula,
                      textStyle: AppTypography.subhead(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Extracted Physical Variables
          if (structured.isNotEmpty) ...[
            Text(
              AppStrings.physicalVariables,
              style: AppTypography.subhead(context).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: structured.map((v) {
                final symbol = v["symbol"]?.toString() ?? "";
                final name = v["name"]?.toString() ?? symbol;
                final val = v["value"];
                final unit = v["unit"]?.toString() ?? "";
                final isTarget = v["is_target"] == true;

                final displayVal = val != null ? "$val $unit".trim() : AppStrings.toFind;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTarget
                        ? AppColors.warning(context).withValues(alpha: 0.1)
                        : AppColors.surfaceVariant(context),
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    border: Border.all(
                      color: isTarget
                          ? AppColors.warning(context).withValues(alpha: 0.4)
                          : divider,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTarget
                              ? AppColors.warning(context)
                              : AppColors.primary(context),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          symbol.isNotEmpty ? symbol : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "$name: $displayVal",
                        style: AppTypography.footnote(context).copyWith(
                          color: isTarget
                              ? AppColors.warning(context)
                              : AppColors.textPrimary(context),
                          fontWeight: isTarget ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // TAB 3: QUIZ SETUP TAB
  // ==========================================================
  double _quizQuestionCount = 5;
  int _selectedDifficulty = 1; // 0: Easy, 1: Medium, 2: Hard

  Widget _buildQuizSetupTab(BuildContext context) {
    final surface = AppColors.surface(context);
    final divider = AppColors.divider(context);

    return StatefulBuilder(
      builder: (context, setQuizState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),

              // Header Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: divider),
                ),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: AppColors.primary(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      "${AppStrings.quizSetupHeader}${widget.topic}",
                      style: AppTypography.title2(context).copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.quizDisclaimer,
                      style: AppTypography.caption(context),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Settings Section
              GroupedSection(
                title: "Quiz configuration",
                children: [
                  GroupedRow(
                    leading: Icon(Icons.format_list_numbered_rounded, color: AppColors.primary(context), size: 22),
                    title: AppStrings.questionCount,
                    trailing: Text(
                      "${_quizQuestionCount.toInt()}",
                      style: AppTypography.headline(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    child: Slider(
                      min: 3,
                      max: 10,
                      divisions: 7,
                      value: _quizQuestionCount,
                      activeColor: AppColors.primary(context),
                      onChanged: (v) => setQuizState(() => _quizQuestionCount = v),
                    ),
                  ),
                  GroupedRow(
                    leading: Icon(Icons.speed_rounded, color: AppColors.primary(context), size: 22),
                    title: AppStrings.difficulty,
                    trailing: CupertinoSegmentedControl<int>(
                      children: const {
                        0: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(AppStrings.difficultyEasy)),
                        1: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(AppStrings.difficultyMedium)),
                        2: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text(AppStrings.difficultyHard)),
                      },
                      groupValue: _selectedDifficulty,
                      onValueChanged: (val) => setQuizState(() => _selectedDifficulty = val),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Generate Quiz Button
              PrimaryButton(
                label: AppStrings.generateQuiz,
                icon: const Icon(Icons.auto_awesome, size: 20),
                onPressed: () => _startQuiz(_quizQuestionCount.toInt()),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startQuiz(int count) async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.modal)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: const QuizSkeleton(),
      ),
    );

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showQuizError("Authentication required. Please sign in again.");
        return;
      }

      final response = await http.get(
        Uri.parse("$_serverIp/quiz/generate?topic=${widget.topic}&count=$count"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 45));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode != 200) {
        _showQuizError("Quiz generation failed (status ${response.statusCode}).");
        return;
      }

      final data = jsonDecode(response.body);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuizPlayScreen(quizData: data)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showQuizError("Unable to connect to server: $e");
    }
  }

  void _showQuizError(String message) {
    if (!mounted) return;
    AppDialogs.confirm(
      context: context,
      title: "Quiz Error",
      message: message,
      confirmLabel: AppStrings.ok,
    );
  }

  String _formatKey(String raw) {
    if (raw.isEmpty) return "";
    return raw
        .replaceAll("_", " ")
        .trim()
        .replaceFirst(raw[0], raw[0].toUpperCase());
  }
}
