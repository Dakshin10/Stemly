class ScanHistory {
  final String topic;
  final List<String> variables;
  final String imagePath;
  final Map<String, dynamic> notesJson;
  bool isStarred;
  final DateTime timestamp;
  List<Map<String, dynamic>> quizResults;
  String? visualiserHistoryId;
  final List<Map<String, dynamic>> structuredVariables;
  final String? targetQuestion;
  final String? latexFormula;

  ScanHistory({
    required this.topic,
    required this.variables,
    required this.imagePath,
    required this.notesJson,
    this.isStarred = false,
    required this.timestamp,
    this.quizResults = const [],
    this.visualiserHistoryId,
    this.structuredVariables = const [],
    this.targetQuestion,
    this.latexFormula,
  });

  Map<String, dynamic> toJson() {
    return {
      "topic": topic,
      "variables": variables,
      "imagePath": imagePath,
      "notesJson": notesJson,
      "isStarred": isStarred,
      "timestamp": timestamp.toIso8601String(),
      "quizResults": quizResults,
      "visualiserHistoryId": visualiserHistoryId,
      "structuredVariables": structuredVariables,
      "targetQuestion": targetQuestion,
      "latexFormula": latexFormula,
    };
  }

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    return ScanHistory(
      topic: json["topic"] ?? "Unknown",
      variables: List<String>.from(json["variables"] ?? []),
      imagePath: json["imagePath"] ?? "",
      notesJson: Map<String, dynamic>.from(json["notesJson"] ?? {}),
      isStarred: json["isStarred"] ?? false,
      timestamp: DateTime.tryParse(json["timestamp"] ?? "") ?? DateTime.now(),
      quizResults: List<Map<String, dynamic>>.from(
        (json["quizResults"] ?? []).map((x) => Map<String, dynamic>.from(x)),
      ),
      visualiserHistoryId: json["visualiserHistoryId"],
      structuredVariables: List<Map<String, dynamic>>.from(
        (json["structuredVariables"] ?? []).map(
          (x) => Map<String, dynamic>.from(x),
        ),
      ),
      targetQuestion: json["targetQuestion"],
      latexFormula: json["latexFormula"],
    );
  }

  factory ScanHistory.fromApiJson(Map<String, dynamic> json) {
    DateTime ts;
    final rawTs = json["timestamp"];
    if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return ScanHistory(
      topic: json["topic"] ?? "Unknown",
      variables: List<String>.from(json["variables"] ?? []),
      imagePath: json["image_path"] ?? json["imagePath"] ?? "",
      notesJson: json["notes"] is Map ? Map<String, dynamic>.from(json["notes"]) : {},
      isStarred: json["isStarred"] ?? false,
      timestamp: ts,
      quizResults: const [],
      visualiserHistoryId: json["_id"]?.toString(),
      structuredVariables: List<Map<String, dynamic>>.from(
        (json["structured_variables"] ?? []).map(
          (x) => Map<String, dynamic>.from(x),
        ),
      ),
      targetQuestion: json["target_question"] ?? json["targetQuestion"],
      latexFormula: json["latex_formula"] ?? json["latexFormula"],
    );
  }
}
