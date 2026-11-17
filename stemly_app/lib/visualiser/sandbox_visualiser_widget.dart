import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/theme.dart';

class SandboxVisualiserWidget extends StatefulWidget {
  final String htmlContent;
  final String title;

  const SandboxVisualiserWidget({
    super.key,
    required this.htmlContent,
    required this.title,
  });

  @override
  State<SandboxVisualiserWidget> createState() => _SandboxVisualiserWidgetState();
}

class _SandboxVisualiserWidgetState extends State<SandboxVisualiserWidget> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant SandboxVisualiserWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _controller?.loadHtmlString(widget.htmlContent);
    }
  }

  void _initController() {
    if (widget.htmlContent.isEmpty) {
      _isLoading = false;
      return;
    }

    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0B0F19))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
            onNavigationRequest: (NavigationRequest request) {
              // Strictly disallow external navigation to maintain sandbox security
              return NavigationDecision.prevent;
            },
          ),
        )
        ..loadHtmlString(widget.htmlContent);
    } catch (e) {
      // Fallback for headless tests or environments without native webview platform
      debugPrint("Sandbox webview init: $e");
      _isLoading = false;
    }
  }

  void _reloadSimulation() {
    setState(() => _isLoading = true);
    _controller?.loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary(context);
    final cardBg = isDark ? const Color(0xFF161B26) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    if (widget.htmlContent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code_off_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                "Empty Simulation Content",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                "No HTML5 simulation code was provided.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Control Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.capsule),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        "AI Sandbox",
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title.isNotEmpty ? widget.title : "Micro-Simulation",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: "Restart Simulation",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: _reloadSimulation,
                ),
              ],
            ),
          ),
          // Webview simulation surface
          Expanded(
            child: Stack(
              children: [
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
