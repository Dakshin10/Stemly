import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Interactive Document Cropper and Region-of-Interest selector.
/// Allows students to crop directly around equations, diagrams, or problem statements
/// to eliminate background noise and maximize OCR/Vision detection accuracy.
class ImageCropperScreen extends StatefulWidget {
  final File originalImage;

  const ImageCropperScreen({
    super.key,
    required this.originalImage,
  });

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  ui.Image? _decodedImage;
  bool _isLoading = true;
  String? _errorMessage;

  // Normalized crop coordinates [0.0 - 1.0] relative to original image
  Rect _normalizedCrop = const Rect.fromLTWH(0.05, 0.1, 0.9, 0.8);

  // Active drag handle
  _HandleType _activeHandle = _HandleType.none;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.originalImage.readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        completer.complete(img);
      });
      final img = await completer.future;

      if (mounted) {
        setState(() {
          _decodedImage = img;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load image: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applyCropAndReturn() async {
    if (_decodedImage == null) {
      Navigator.pop(context, widget.originalImage);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final imgW = _decodedImage!.width.toDouble();
      final imgH = _decodedImage!.height.toDouble();

      // Convert normalized rect to actual pixel coordinates
      final left = (_normalizedCrop.left * imgW).clamp(0.0, imgW - 10);
      final top = (_normalizedCrop.top * imgH).clamp(0.0, imgH - 10);
      final right = (_normalizedCrop.right * imgW).clamp(left + 10, imgW);
      final bottom = (_normalizedCrop.bottom * imgH).clamp(top + 10, imgH);

      final cropWidth = max(20.0, right - left);
      final cropHeight = max(20.0, bottom - top);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final srcRect = Rect.fromLTWH(left, top, cropWidth, cropHeight);
      final dstRect = Rect.fromLTWH(0, 0, cropWidth, cropHeight);

      canvas.drawImageRect(_decodedImage!, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(cropWidth.toInt(), cropHeight.toInt());

      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.pop(context, widget.originalImage);
        return;
      }

      final croppedBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await croppedFile.writeAsBytes(croppedBytes);

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      debugPrint("Crop failed: $e, falling back to original");
      if (mounted) {
        Navigator.pop(context, widget.originalImage);
      }
    }
  }

  void _resetToFull() {
    setState(() {
      _normalizedCrop = const Rect.fromLTWH(0.02, 0.02, 0.96, 0.96);
    });
  }

  void _presetCenterProblem() {
    setState(() {
      _normalizedCrop = const Rect.fromLTWH(0.1, 0.2, 0.8, 0.6);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Crop STEM Problem",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, widget.originalImage),
        ),
        actions: [
          TextButton.icon(
            onPressed: _applyCropAndReturn,
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            label: const Text(
              "Analyze",
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final viewW = constraints.maxWidth;
                    final viewH = constraints.maxHeight - 90; // reserve space for toolbar

                    final imgW = _decodedImage!.width.toDouble();
                    final imgH = _decodedImage!.height.toDouble();

                    // Calculate fit inside viewport
                    final scaleX = viewW / imgW;
                    final scaleY = viewH / imgH;
                    final scale = min(scaleX, scaleY);

                    final displayW = imgW * scale;
                    final displayH = imgH * scale;

                    final offsetX = (viewW - displayW) / 2;
                    final offsetY = (viewH - displayH) / 2;

                    final imageRect = Rect.fromLTWH(offsetX, offsetY, displayW, displayH);

                    // Convert normalized crop rect to screen coordinates
                    final screenCrop = Rect.fromLTRB(
                      imageRect.left + _normalizedCrop.left * displayW,
                      imageRect.top + _normalizedCrop.top * displayH,
                      imageRect.left + _normalizedCrop.right * displayW,
                      imageRect.top + _normalizedCrop.bottom * displayH,
                    );

                    return Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onPanStart: (details) {
                              _activeHandle = _hitTestHandle(details.localPosition, screenCrop);
                            },
                            onPanUpdate: (details) {
                              if (_activeHandle == _HandleType.none) return;

                              setState(() {
                                final deltaX = details.delta.dx / displayW;
                                final deltaY = details.delta.dy / displayH;

                                double newLeft = _normalizedCrop.left;
                                double newTop = _normalizedCrop.top;
                                double newRight = _normalizedCrop.right;
                                double newBottom = _normalizedCrop.bottom;

                                const minSize = 0.1;

                                switch (_activeHandle) {
                                  case _HandleType.topLeft:
                                    newLeft = (_normalizedCrop.left + deltaX).clamp(0.0, newRight - minSize);
                                    newTop = (_normalizedCrop.top + deltaY).clamp(0.0, newBottom - minSize);
                                    break;
                                  case _HandleType.topRight:
                                    newRight = (_normalizedCrop.right + deltaX).clamp(newLeft + minSize, 1.0);
                                    newTop = (_normalizedCrop.top + deltaY).clamp(0.0, newBottom - minSize);
                                    break;
                                  case _HandleType.bottomLeft:
                                    newLeft = (_normalizedCrop.left + deltaX).clamp(0.0, newRight - minSize);
                                    newBottom = (_normalizedCrop.bottom + deltaY).clamp(newTop + minSize, 1.0);
                                    break;
                                  case _HandleType.bottomRight:
                                    newRight = (_normalizedCrop.right + deltaX).clamp(newLeft + minSize, 1.0);
                                    newBottom = (_normalizedCrop.bottom + deltaY).clamp(newTop + minSize, 1.0);
                                    break;
                                  case _HandleType.body:
                                    final width = _normalizedCrop.width;
                                    final height = _normalizedCrop.height;
                                    newLeft = (_normalizedCrop.left + deltaX).clamp(0.0, 1.0 - width);
                                    newTop = (_normalizedCrop.top + deltaY).clamp(0.0, 1.0 - height);
                                    newRight = newLeft + width;
                                    newBottom = newTop + height;
                                    break;
                                  default:
                                    break;
                                }

                                _normalizedCrop = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
                              });
                            },
                            onPanEnd: (_) => _activeHandle = _HandleType.none,
                            child: CustomPaint(
                              painter: _CropperPainter(
                                image: _decodedImage!,
                                imageRect: imageRect,
                                cropRect: screenCrop,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),

                        // Bottom Toolbar
                        Container(
                          height: 90,
                          color: const Color(0xFF121212),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: SafeArea(
                            top: false,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth - 20),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _toolbarButton(
                                      icon: Icons.crop_free,
                                      label: "Focus",
                                      onTap: _presetCenterProblem,
                                    ),
                                    _toolbarButton(
                                      icon: Icons.fullscreen,
                                      label: "Full Page",
                                      onTap: _resetToFull,
                                    ),
                                    _toolbarButton(
                                      icon: Icons.skip_next_outlined,
                                      label: "Skip",
                                      onTap: () => Navigator.pop(context, widget.originalImage),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      onPressed: _applyCropAndReturn,
                                      icon: const Icon(Icons.check_circle_outline, size: 18),
                                      label: const Text("Scan Selection"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  _HandleType _hitTestHandle(Offset pos, Rect crop) {
    const handleRadius = 32.0;

    if ((pos - crop.topLeft).distance <= handleRadius) return _HandleType.topLeft;
    if ((pos - crop.topRight).distance <= handleRadius) return _HandleType.topRight;
    if ((pos - crop.bottomLeft).distance <= handleRadius) return _HandleType.bottomLeft;
    if ((pos - crop.bottomRight).distance <= handleRadius) return _HandleType.bottomRight;
    if (crop.contains(pos)) return _HandleType.body;

    return _HandleType.none;
  }
}

enum _HandleType { none, topLeft, topRight, bottomLeft, bottomRight, body }

class _CropperPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final Rect cropRect;

  static final Paint _dimPaint = Paint()..color = const Color(0x99000000);
  static final Paint _borderPaint = Paint()
    ..color = const Color(0xFF60A5FA)
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;
  static final Paint _gridPaint = Paint()
    ..color = const Color(0x44FFFFFF)
    ..strokeWidth = 1.0;
  static final Paint _cornerPaint = Paint()
    ..color = const Color(0xFF3B82F6)
    ..style = PaintingStyle.fill;

  _CropperPainter({
    required this.image,
    required this.imageRect,
    required this.cropRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw source image
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, src, imageRect, Paint());

    // 2. Draw dim overlay with hole for cropRect
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cropPath = Path()..addRect(cropRect);
    final overlayPath = Path.combine(PathOperation.difference, bgPath, cropPath);
    canvas.drawPath(overlayPath, _dimPaint);

    // 3. Draw crop border
    canvas.drawRect(cropRect, _borderPaint);

    // 4. Draw Rule of Thirds grid inside cropRect
    final thirdW = cropRect.width / 3.0;
    final thirdH = cropRect.height / 3.0;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        _gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        _gridPaint,
      );
    }

    // 5. Draw 4 Corner Handles
    const cornerSize = 14.0;
    canvas.drawCircle(cropRect.topLeft, cornerSize / 2, _cornerPaint);
    canvas.drawCircle(cropRect.topRight, cornerSize / 2, _cornerPaint);
    canvas.drawCircle(cropRect.bottomLeft, cornerSize / 2, _cornerPaint);
    canvas.drawCircle(cropRect.bottomRight, cornerSize / 2, _cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _CropperPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.imageRect != imageRect;
  }
}
