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
import '../services/firebase_auth_service.dart';
import '../storage/history_store.dart';
import '../visualiser/visualiser_factory.dart';
import '../visualiser/visualiser_models.dart';

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
  final Map<String, bool> expanded = {};

  VisualTemplate? visualiserTemplate;
  Widget? visualiserWidget;
  bool loadingVisualiser = true;
  String? _scanHistoryId; // Added for history tracking

  // AI Chat state
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  bool _isSendingChat = false;
  final ScrollController _chatScrollController = ScrollController();

  String get serverIp => AppConfig.baseUrl;

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    for (var key in widget.notesJson.keys) {
      expanded[key] = false;
    }

    _loadVisualiser();
  }

  // ==========================================================
  // VISUALISER LOADER
  // ==========================================================
  Future<void> _loadVisualiser() async {
    setState(() => loadingVisualiser = true);

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        debugPrint("❌ No Firebase token");
        if (mounted) setState(() => loadingVisualiser = false);
        return;
      }

      final response = await http.post(
        Uri.parse("$serverIp/visualiser/generate"),
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
        debugPrint("❌ Visualiser API Error: ${response.statusCode}");
        if (mounted) setState(() => loadingVisualiser = false);
        return;
      }

      final data = jsonDecode(response.body);
      
      // Inject history_id into templateJson if present (to ensure VisualTemplate has it)
      final templateJson = data["template"];
      if (data.containsKey("history_id")) {
        templateJson["history_id"] = data["history_id"];
        
        // Save history ID to store
        if (widget.historyItem != null) {
           // We need to access the backing field since it's final? 
           // Wait, ScanHistory fields are final?
           // I modified ScanHistory to have final visualiserHistoryId? 
           // No, I added it as final String? visualiserHistoryId.
           // I cannot update it!
           
           // I should have made it non-final or mutable.
           // Or I iterate and replace the item in HistoryStore.
           // But HistoryStore stores the OBJECTS.
        }
      }

      final template = VisualTemplate.fromJson(templateJson);

      // Store the history ID for updates
      if (data.containsKey("history_id")) {
        _scanHistoryId = data["history_id"];
      }

      // Persist ID to History Store
      if (template.historyId != null && widget.historyItem != null) {
          _updateHistoryItem(template.historyId!);
      }

      if (mounted) {
        setState(() {
          visualiserTemplate = template;
          visualiserWidget = VisualiserFactory.create(
            template,
            onSimulationUpdate: (stats) {
              setState(() => _simulationStats = stats);
            },
          );
          loadingVisualiser = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Visualiser error: $e");
      if (mounted) setState(() => loadingVisualiser = false);
    }
  }

  // ==========================================================
  // HELPER: Update History Item & Store
  // ==========================================================
  Future<void> _updateHistoryItem(String historyId) async {
    if (widget.historyItem != null) {
      widget.historyItem!.visualiserHistoryId = historyId;
      await HistoryStore.update();
    }
  }

  // ==========================================================
  // CREATE VISUALISER WIDGET
  // ==========================================================
  Map<String, String> _simulationStats = {};

  // ==========================================================
  // VISUALISER TAB UI
  // ==========================================================
  // NEW STATE FOR IMAGE GEN
  String? generatedImageUrl;
  bool generatingImage = false;

  Future<void> _generateImage() async {
    setState(() => generatingImage = true);
    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$serverIp/visualiser/generate-image"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"prompt": "${widget.topic} ${widget.variables.join(' ')}"}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => generatedImageUrl = data["image_url"]);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate image")),
        );
      }
    } catch (e) {
      debugPrint("Image gen error: $e");
    } finally {
      if (mounted) setState(() => generatingImage = false);
    }
  }

  void _updateWidgetFromTemplate() {
    if (visualiserTemplate == null) return;
    setState(() {
      visualiserWidget = VisualiserFactory.create(
        visualiserTemplate!,
        onSimulationUpdate: (stats) {
          setState(() => _simulationStats = stats);
        },
      );
    });
  }

  Future<void> _sendMessage() async {
      final text = _chatController.text.trim();
      if (text.isEmpty) return;

      setState(() {
        _chatMessages.add({"text": text, "isUser": true});
        _isSendingChat = true;
        _chatController.clear();
      });

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      try {
        if (visualiserTemplate == null) {
           setState(() {
              _chatMessages.add({"text": "No active simulation to control.", "isUser": false});
              _isSendingChat = false;
           });
           return;
        }

        final auth = context.read<FirebaseAuthService>();
        final token = await auth.getIdToken();

        // Convert parameters to map
        final params = <String, dynamic>{};
        visualiserTemplate!.parameters.forEach((k, v) => params[k] = v.value);

        final response = await http.post(
          Uri.parse("$serverIp/visualiser/update"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
             "template_id": visualiserTemplate!.templateId,
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
               visualiserTemplate!.parameters.forEach((key, param) {
                  if (newParams.containsKey(key)) {
                     param.value = newParams[key];
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

  Widget _visualiser(Color deepBlue) {
    if (loadingVisualiser) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: deepBlue),
            const SizedBox(height: 16),
            Text("Generating Simulation...", 
              style: TextStyle(color: deepBlue, fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      );
    }

    if (visualiserWidget == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (generatedImageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    generatedImageUrl!, 
                    height: 300, 
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: deepBlue)));
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (!generatingImage && generatedImageUrl == null) ...[
                 Icon(Icons.image_search_rounded, size: 60, color: deepBlue.withValues(alpha: 0.5)),
                 const SizedBox(height: 16),
                 Text(
                  "No interactive simulation available.",
                  style: TextStyle(fontSize: 16, color: deepBlue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],

              if (generatingImage)
                 Column(children: [
                   CircularProgressIndicator(color: deepBlue),
                   const SizedBox(height: 10),
                   Text("Generating AI Diagram...", style: TextStyle(color: deepBlue))
                 ])
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generateImage,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(generatedImageUrl == null ? "Generate AI Diagram" : "Regenerate Diagram"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: deepBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. EQUATION & PROBLEM TARGET CARD
          _buildEquationAndVariablesCard(deepBlue),

          // 1. VISUALISER CARD
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: deepBlue.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // The Interactive Widget
                  Positioned.fill(child: visualiserWidget!),
                  
                  // Overlay Gradient for better visibility of controls (optional)
                  // Positioned(
                  //   top: 0, left: 0, right: 0, height: 60,
                  //   child: Container(
                  //     decoration: BoxDecoration(
                  //       gradient: LinearGradient(
                  //         colors: [Colors.black12, Colors.transparent],
                  //         begin: Alignment.topCenter,
                  //         end: Alignment.bottomCenter
                  //       )
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. CONTROLS & STATUS CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: deepBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.tune_rounded, size: 20, color: deepBlue),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Simulation Parameters",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: deepBlue,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),

                // Live Stats (Chips)
                if (_simulationStats.isNotEmpty) ...[
                   Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: _simulationStats.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(e.key, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(e.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                  const SizedBox(height: 20),
                ],

                // Parameters List
                if (visualiserTemplate != null && visualiserTemplate!.parameters.isNotEmpty)
                  ...visualiserTemplate!.parameters.entries.map((e) {
                      final v = e.value.value;
                      // Determine if we can show a slider (if range is known)
                      // For now, simpler robust list
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text(
                              e.key, 
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: deepBlue.withValues(alpha: 0.8),
                              ),
                            ),
                            const Spacer(),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: deepBlue.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  v.toStringAsFixed(2),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: deepBlue,
                                    fontSize: 15
                                  ),
                                ),
                            ),
                          ],
                        ),
                      );
                  })
                else 
                   const Padding(
                     padding: EdgeInsets.symmetric(vertical: 10),
                     child: Text("No adjustable parameters"),
                   ),
              ],
            ),
          ),

          // 3. AI CHAT SECTION (Managed in separate method/widget potentially, but kept inline or below)
          const SizedBox(height: 24),
          _buildAiAssistantCard(deepBlue),
          
          // Bottom spacer for scrolling
          const SizedBox(height: 80), 
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard(Color deepBlue) {
     return Card(
        elevation: 0,
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
        child: ExpansionTile(
          initiallyExpanded: true, // Keep open by default for engagement
          shape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: deepBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: deepBlue, size: 22),
          ),
          title: Text(
            "AI Assistant",
            style: TextStyle(
              color: deepBlue,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          subtitle: Text(
            "Ask to change parameters or explain concepts",
            style: TextStyle(color: deepBlue.withValues(alpha: 0.5), fontSize: 13),
          ),
          children: [
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Messages Area
                  Expanded(
                    child: _chatMessages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  "Try: 'Set velocity to 50' or 'Explain gravity'",
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _chatScrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _chatMessages.length,
                            itemBuilder: (context, index) {
                              final msg = _chatMessages[index];
                              final isUser = msg["isUser"] == true;
                              return Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                  decoration: BoxDecoration(
                                    color: isUser ? deepBlue : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                                      bottomRight: Radius.circular(isUser ? 4 : 16),
                                    ),
                                    boxShadow: isUser ? [] : [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: Text(
                                    msg["text"] ?? "",
                                    style: TextStyle(
                                      color: isUser ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Input Area
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: "Type a command...",
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: deepBlue,
                              shape: BoxShape.circle,
                            ),
                            child: _isSendingChat
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    final deepBlue = Theme.of(context).primaryColor;
    
    return DefaultTabController(
      length: 3,
      initialIndex: 1, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text("Scan Results", style: TextStyle(color: deepBlue, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: deepBlue),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: TabBar(
            labelColor: deepBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: deepBlue,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Notes", icon: Icon(Icons.description_rounded)),
              Tab(text: "Visualiser", icon: Icon(Icons.play_circle_fill_rounded)),
              Tab(text: "Quiz", icon: Icon(Icons.quiz_rounded)),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Prevent horizontal swipe if simulations capture touch
          children: [
            _notes(Colors.white, deepBlue),
            _visualiser(deepBlue),
            _quizTab(deepBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildEquationAndVariablesCard(Color deepBlue) {
    final target = widget.targetQuestion ?? widget.historyItem?.targetQuestion;
    final formula = widget.latexFormula ?? widget.historyItem?.latexFormula;
    final structured = widget.structuredVariables.isNotEmpty
        ? widget.structuredVariables
        : (widget.historyItem?.structuredVariables ?? []);

    if (target == null && formula == null && structured.isEmpty && widget.variables.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: deepBlue.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Question Banner
          if (target != null && target.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🎯", style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Target Objective",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          target,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Governing Formula Card
          if (formula != null && formula.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.functions, size: 16, color: Colors.blue.shade300),
                      const SizedBox(width: 6),
                      Text(
                        "Governing Equation",
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade200, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    formula,
                    style: const TextStyle(
                      fontFamily: "monospace",
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Structured Variables Chips
          if (structured.isNotEmpty) ...[
            Text(
              "Extracted Physics Variables",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: structured.map((v) {
                final symbol = v["symbol"]?.toString() ?? "";
                final name = v["name"]?.toString() ?? symbol;
                final val = v["value"];
                final unit = v["unit"]?.toString() ?? "";
                final isTarget = v["is_target"] == true;

                final displayVal = val != null ? "$val $unit".trim() : "? (To Find)";

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTarget ? Colors.red.withValues(alpha: 0.1) : deepBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isTarget ? Colors.red.withValues(alpha: 0.4) : deepBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTarget ? Colors.redAccent : deepBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          symbol.isNotEmpty ? symbol : name,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            displayVal,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isTarget ? Colors.red.shade700 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else if (widget.variables.isNotEmpty) ...[
            Text(
              "Detected Variables",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.variables.map((v) {
                return Chip(
                  backgroundColor: deepBlue.withValues(alpha: 0.08),
                  label: Text(v, style: TextStyle(fontSize: 12, color: deepBlue, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // NOTES TAB
  // ==========================================================
  Widget _notes(Color cardColor, Color deepBlue) {
    if (widget.notesJson.containsKey("error")) {
      return ErrorStateView(
        title: "Notes Generation Failed",
        message: widget.notesJson["error"]?.toString() ?? "Could not generate notes for this problem.",
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEquationAndVariablesCard(deepBlue),
          if (isDegraded) ...[
            const DegradedModeBanner(),
            const SizedBox(height: 8),
          ],
          ...widget.notesJson.entries.where((e) => e.key != 'degraded').map((entry) {
            final key = entry.key;
            expanded.putIfAbsent(key, () => false);

            return _expandableCard(
              title: _formatKey(key),
              expanded: expanded[key]!,
              onTap: () => setState(() => expanded[key] = !expanded[key]!),
              child: _buildContent(entry.value, deepBlue),
              cardColor: Theme.of(context).cardColor,
              deepBlue: deepBlue,
            );
          }),
        ],
      ),
    );
  }

  // ==========================================================
  // QUIZ TAB  (REDESIGNED)
  // ==========================================================
  Widget _quizTab(Color deepBlue) {
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
                  color: deepBlue,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: deepBlue.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.quiz_rounded, size: 48, color: Colors.white),
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
                      "Test your knowledge on ${widget.topic}",
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
                            color: deepBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune, color: deepBlue, size: 24),
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
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: deepBlue,
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
                        activeTrackColor: deepBlue,
                        inactiveTrackColor: deepBlue.withValues(alpha: 0.2),
                        thumbColor: deepBlue,
                        overlayColor: deepBlue.withValues(alpha: 0.2),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
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
                    backgroundColor: deepBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: deepBlue.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    "Questions are generated by AI based on your topic",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
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
        color: isIncluded ? color.withValues(alpha: 0.15) : Colors.grey.shade200,
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
  // START QUIZ (API CALL with QuizSkeleton and typed errors)
  // ==========================================================
  Future<void> _startQuiz(int count) async {
    if (!mounted) return;

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
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        _showQuizError("Authentication required. Please sign in again.");
        return;
      }

      final response = await http.get(
        Uri.parse("$serverIp/quiz/generate?topic=${widget.topic}&count=$count"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 45));

      // Close loading skeleton
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 429) {
        _showQuizError("Daily AI generation limit reached or server busy. Please try again later.");
        return;
      }

      if (response.statusCode != 200) {
        _showQuizError("Failed to generate quiz. Server returned status: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);

      // Check for error in response
      if (data is Map && data.containsKey("error") && (data["questions"] == null || (data["questions"] as List).isEmpty)) {
        _showQuizError(data["error"]?.toString() ?? "Quiz generation failed");
        return;
      }

      // Navigate to quiz screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => QuizPlayScreen(quizData: data)),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showQuizError("Unable to connect to server. Please check your connection.");
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

  // ==========================================================
  // UI HELPERS
  // ==========================================================

  Widget _expandableCard({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
    required Color cardColor,
    required Color deepBlue,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: deepBlue,
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 30,
                    color: deepBlue,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 260),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(dynamic value, Color deepBlue) {
    if (value is String) {
      return Text(value, style: TextStyle(fontSize: 15, color: deepBlue));
    }

    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value
            .map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "• $v",
                  style: TextStyle(fontSize: 15, color: deepBlue),
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
              (e) => Text(
                "${e.key}: ${e.value}",
                style: TextStyle(fontSize: 15, color: deepBlue),
              ),
            )
            .toList(),
      );
    }

    return Text(
      value.toString(),
      style: TextStyle(fontSize: 15, color: deepBlue),
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
