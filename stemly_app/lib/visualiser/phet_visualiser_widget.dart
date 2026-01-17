import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PhetVisualiserWidget extends StatefulWidget {
  final String url;
  final String title;

  const PhetVisualiserWidget({
    super.key, 
    required this.url,
    required this.title
  });

  @override
  State<PhetVisualiserWidget> createState() => _PhetVisualiserWidgetState();
}

class _PhetVisualiserWidgetState extends State<PhetVisualiserWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
             if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Center(
             child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
          ),
        
        // Interaction overlay info (optional)
        // Since PhET captures touches, we might want a way to inform user
      ],
    );
  }
}
