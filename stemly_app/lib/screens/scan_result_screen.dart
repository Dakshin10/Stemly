import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../services/firebase_auth_service.dart';
import '../services/groq_service.dart';

// NEW: Import Quiz Screen
import '../quiz/quiz_play_screen.dart';

// Existing imports
import '../visualiser/visualiser_models.dart';
import '../visualiser/visualiser_factory.dart';
import '../models/scan_history.dart';
import '../storage/history_store.dart';

class ScanResultScreen extends StatefulWidget {
  final String topic;
  final List<String> variables;
  final Map<String, dynamic> notesJson;
  final String imagePath;
  final ScanHistory? historyItem; // NEW

  const ScanResultScreen({
    super.key,
    required this.topic,
    required this.variables,
    required this.notesJson,
    required this.imagePath,
    this.historyItem,
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

  final String serverIp = "http://10.0.2.2:8080";


  @override
  void initState() {
    super.initState();

    debugPrint("SCAN RESULT START");
    debugPrint("Topic: ${widget.topic}");
    debugPrint("Variables: ${widget.variables}");
    debugPrint("Notes Keys: ${widget.notesJson.keys}");

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
  // HELPER: Persist Updates to Backend (Silent)
  // ==========================================================
  Future<void> _persistUpdates(Map<String, dynamic> params) async {
      try {
        final auth = context.read<FirebaseAuthService>();
        final token = await auth.getIdToken();
        if (token == null) return;
        
        final historyId = visualiserTemplate?.historyId;
        final templateId = visualiserTemplate?.templateId;
        
        if (historyId == null || templateId == null) return;

        await http.post(
          Uri.parse("$serverIp/visualiser/update"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({
            "template_id": templateId,
            "parameters": params,
            "history_id": historyId,
            // empty prompt signals "just save"
          }),
        );
      } catch (e) {
        debugPrint("Silent persist failed: $e");
      }
  }

  // ==========================================================
  // CREATE VISUALISER WIDGET
  // ==========================================================
  Map<String, String> _simulationStats = {};

  Widget _createVisualiser(VisualTemplate template) {
    return VisualiserFactory.create(template, onSimulationUpdate: (stats) {
      if (stats.toString() != _simulationStats.toString()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _simulationStats = stats);
        });
      }
    });
  }

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

  // ==========================================================
  // AI CHAT FUNCTION
  // ==========================================================
  Future<void> _sendChatMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _chatMessages.add({"text": message, "isUser": true});
      _chatController.clear();
      _isSendingChat = true;
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    try {
      final auth = context.read<FirebaseAuthService>();
      final token = await auth.getIdToken();

      if (token == null) {
        setState(() {
          _chatMessages.add({"text": "Authentication required.", "isUser": false});
          _isSendingChat = false;
        });
        return;
      }

      // Prepare parameters for API
      Map<String, dynamic> params = {};
      if (visualiserTemplate != null) {
        for (var entry in visualiserTemplate!.parameters.entries) {
          params[entry.key] = entry.value.value;
        }
      }
      
      // Get AI API Key
      final groqService = context.read<GroqService>();
      final aiApiKey = groqService.apiKey;

      final response = await http.post(
        Uri.parse("$serverIp/visualiser/chat"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
          if (aiApiKey != null) "X-AI-API-Key": aiApiKey,
        },
        body: jsonEncode({
          "message": message,
          "topic": widget.topic,
          "parameters": params,
          "history": _chatMessages.map((m) => {"text": m["text"], "isUser": m["isUser"]}).toList(),
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data["type"] == "update" && data["changes"] != null) {
          // AI wants to update visualization
          final changes = data["changes"] as Map<String, dynamic>;
          String updateMsg = "Updated: ";
          bool needsRebuild = false;

          changes.forEach((key, value) {
            // Check for Metadata updates (Equation / Primitives)
            if (key == "equation" || key == "primitives") {
              if (visualiserTemplate != null) {
                visualiserTemplate!.metadata[key] = value;
                updateMsg += "$key updated, ";
                needsRebuild = true;
              }
            }
            // Check for Parameter updates
            else if (visualiserTemplate != null && visualiserTemplate!.parameters.containsKey(key)) {
              final param = visualiserTemplate!.parameters[key]!;
              
              // Safe parse value
              double newValue = 0.0;
              if (value is num) newValue = value.toDouble();
              else if (value is String) newValue = double.tryParse(value) ?? 0.0;

              // Clamp to constraints
              newValue = newValue.clamp(param.min, param.max);
              
              // Apply update
              param.value = newValue;
              updateMsg += "$key = ${newValue.toStringAsFixed(1)}, ";
              needsRebuild = true;
            }
          });

          if (needsRebuild) {
             visualiserWidget = _createVisualiser(visualiserTemplate!);
             // Save changes to DB
             _persistUpdates(visualiserTemplate!.parameters.map((k, v) => MapEntry(k, v.value)));
          }

          setState(() {
            _chatMessages.add({"text": updateMsg.trimRight().replaceAll(RegExp(r', $'), ''), "isUser": false});
          });
        } else {
          // AI explanation
          setState(() {
            _chatMessages.add({"text": data["message"] ?? "No response.", "isUser": false});
          });
        }
      } else {
        setState(() {
          _chatMessages.add({"text": "Error: ${response.statusCode}", "isUser": false});
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add({"text": "Connection error. Try again.", "isUser": false});
      });
    } finally {
      if (mounted) setState(() => _isSendingChat = false);
      
      // Scroll to bottom after response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
                 Icon(Icons.image_search_rounded, size: 60, color: deepBlue.withOpacity(0.5)),
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
          // 1. VISUALISER CARD
          Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: deepBlue.withOpacity(0.08),
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
                  color: Colors.black.withOpacity(0.04),
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
                        color: deepBlue.withOpacity(0.1),
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
                          color: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
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
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
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
                                color: deepBlue.withOpacity(0.8),
                              ),
                            ),
                            const Spacer(),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: deepBlue.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  v is double ? v.toStringAsFixed(2) : v.toString(),
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
                  }).toList()
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
              color: deepBlue.withOpacity(0.1),
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
            style: TextStyle(color: deepBlue.withOpacity(0.5), fontSize: 13),
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
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))
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

  // ==========================================================
  // NOTES TAB
  // ==========================================================
  Widget _notes(Color cardColor, Color deepBlue) {
    if (widget.notesJson.containsKey("error")) {
      return Center(
        child: Text("Error loading notes", style: TextStyle(color: deepBlue)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: widget.notesJson.entries.map((entry) {
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
        }).toList(),
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
                      color: deepBlue.withOpacity(0.3),
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
                        color: Colors.white.withOpacity(0.9),
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
                      color: Colors.black.withOpacity(0.05),
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
                            color: deepBlue.withOpacity(0.1),
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
                        inactiveTrackColor: deepBlue.withOpacity(0.2),
                        thumbColor: deepBlue,
                        overlayColor: deepBlue.withOpacity(0.2),
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
                    shadowColor: deepBlue.withOpacity(0.4),
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
        color: isIncluded ? color.withOpacity(0.15) : Colors.grey.shade200,
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
  // START QUIZ (API CALL with retry and error handling)
  // ==========================================================
  Future<void> _startQuiz(int count) async {
    final auth = context.read<FirebaseAuthService>();
    final token = await auth.getIdToken();

    if (token == null) {
      _showQuizError("Authentication required. Please sign in again.");
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text("Generating ${widget.topic} Quiz...", textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text("This may take a moment", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      final response = await http.get(
        Uri.parse("$serverIp/quiz/generate?topic=${widget.topic}&count=$count"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 120));

      // Close loading dialog
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 429) {
        // Rate limited - show friendly message
        _showQuizError("AI is busy. Please wait a moment and try again.");
        return;
      }

      if (response.statusCode != 200) {
        _showQuizError("Failed to generate quiz. Error: ${response.statusCode}");
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
      // Close loading dialog if still open
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _showQuizError("Connection error: ${e.toString().split(':').first}");
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
