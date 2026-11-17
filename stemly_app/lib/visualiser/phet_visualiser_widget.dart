import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PhetVisualiserWidget extends StatefulWidget {
  final String url;
  final String title;

  static bool isAllowedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.isScheme('https') &&
        (uri.host == 'phet.colorado.edu' ||
            uri.host.endsWith('.phet.colorado.edu')) &&
        uri.path.startsWith('/sims/html/');
  }

  const PhetVisualiserWidget({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PhetVisualiserWidget> createState() => _PhetVisualiserWidgetState();
}

class _PhetVisualiserWidgetState extends State<PhetVisualiserWidget> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final isAllowed = PhetVisualiserWidget.isAllowedUrl(widget.url);
    if (isAllowed) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {},
            onPageStarted: (String url) {},
            onPageFinished: (String url) {
              if (mounted) setState(() => _isLoading = false);
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) setState(() => _isLoading = false);
            },
            onNavigationRequest: (NavigationRequest request) {
              final uri = Uri.tryParse(request.url);
              if (uri != null &&
                  uri.isScheme('https') &&
                  (uri.host == 'phet.colorado.edu' ||
                      uri.host.endsWith('.phet.colorado.edu'))) {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PhetVisualiserWidget.isAllowedUrl(widget.url)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, size: 48, color: Colors.amber),
              const SizedBox(height: 12),
              const Text(
                "Restricted External Content",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                "Only simulations hosted on phet.colorado.edu are allowed.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            ),
        ],
      ),
    );
  }
}
