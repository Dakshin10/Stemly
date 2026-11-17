import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../presentation/components/components.dart';
import '../strings.dart';
import '../theme/theme.dart';

/// HIG-compliant Interactive Document Cropper.
/// Provides a distraction-free dark canvas, 44x44 dp touch targets on corner handles,
/// image rotation controls, and 52 dp action buttons.
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
  int _rotationDegrees = 0; // 0, 90, 180, 270

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
          _errorMessage = "Unable to load image: $e";
          _isLoading = false;
        });
      }
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
  }

  void _rotateCounterClockwise() {
    setState(() {
      _rotationDegrees = (_rotationDegrees - 90 + 360) % 360;
    });
  }

  void _resetCrop() {
    setState(() {
      _normalizedCrop = const Rect.fromLTWH(0.05, 0.1, 0.9, 0.8);
      _rotationDegrees = 0;
    });
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

      final left = (_normalizedCrop.left * imgW).clamp(0.0, imgW - 10);
      final top = (_normalizedCrop.top * imgH).clamp(0.0, imgH - 10);
      final right = (_normalizedCrop.right * imgW).clamp(left + 10, imgW);
      final bottom = (_normalizedCrop.bottom * imgH).clamp(top + 10, imgH);

      final cropWidth = max(20.0, right - left);
      final cropHeight = max(20.0, bottom - top);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Handle rotation if rotated
      if (_rotationDegrees != 0) {
        final rad = _rotationDegrees * pi / 180.0;
        canvas.translate(cropWidth / 2, cropHeight / 2);
        canvas.rotate(rad);
        canvas.translate(-cropWidth / 2, -cropHeight / 2);
      }

      final srcRect = Rect.fromLTWH(left, top, cropWidth, cropHeight);
      final dstRect = Rect.fromLTWH(0, 0, cropWidth, cropHeight);

      canvas.drawImageRect(
        _decodedImage!,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(cropWidth.toInt(), cropHeight.toInt());

      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.pop(context, widget.originalImage);
        return;
      }

      final croppedBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final croppedFile =
          File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await croppedFile.writeAsBytes(croppedBytes);

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      debugPrint("Crop error: $e");
      if (mounted) {
        Navigator.pop(context, widget.originalImage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          AppStrings.cropTitle,
          style: AppTypography.headline(context).copyWith(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context, widget.originalImage),
          tooltip: AppStrings.cancel,
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primary(context),
                strokeWidth: 3,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.body(context).copyWith(color: Colors.white70),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final viewW = constraints.maxWidth;
                    // Reserve 160 dp for controls and action buttons
                    final viewH = max(100.0, constraints.maxHeight - 160);

                    final imgW = _decodedImage!.width.toDouble();
                    final imgH = _decodedImage!.height.toDouble();

                    final scaleX = viewW / imgW;
                    final scaleY = viewH / imgH;
                    final scale = min(scaleX, scaleY);

                    final displayW = imgW * scale;
                    final displayH = imgH * scale;

                    final offsetX = (viewW - displayW) / 2;
                    final offsetY = (viewH - displayH) / 2;

                    final imageRect = Rect.fromLTWH(offsetX, offsetY, displayW, displayH);

                    final screenCrop = Rect.fromLTRB(
                      imageRect.left + _normalizedCrop.left * displayW,
                      imageRect.top + _normalizedCrop.top * displayH,
                      imageRect.left + _normalizedCrop.right * displayW,
                      imageRect.top + _normalizedCrop.bottom * displayH,
                    );

                    return Column(
                      children: [
                        // CROP VIEW CANVAS
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
                                    newLeft =
                                        (_normalizedCrop.left + deltaX).clamp(0.0, newRight - minSize);
                                    newTop =
                                        (_normalizedCrop.top + deltaY).clamp(0.0, newBottom - minSize);
                                    break;
                                  case _HandleType.topRight:
                                    newRight =
                                        (_normalizedCrop.right + deltaX).clamp(newLeft + minSize, 1.0);
                                    newTop =
                                        (_normalizedCrop.top + deltaY).clamp(0.0, newBottom - minSize);
                                    break;
                                  case _HandleType.bottomLeft:
                                    newLeft =
                                        (_normalizedCrop.left + deltaX).clamp(0.0, newRight - minSize);
                                    newBottom =
                                        (_normalizedCrop.bottom + deltaY).clamp(newTop + minSize, 1.0);
                                    break;
                                  case _HandleType.bottomRight:
                                    newRight =
                                        (_normalizedCrop.right + deltaX).clamp(newLeft + minSize, 1.0);
                                    newBottom =
                                        (_normalizedCrop.bottom + deltaY).clamp(newTop + minSize, 1.0);
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

                                _normalizedCrop =
                                    Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
                              });
                            },
                            onPanEnd: (_) => _activeHandle = _HandleType.none,
                            child: CustomPaint(
                              painter: _CropperPainter(
                                image: _decodedImage!,
                                imageRect: imageRect,
                                cropRect: screenCrop,
                                rotation: _rotationDegrees,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),

                        // TOOLBAR & ACTIONS
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenMargin,
                            vertical: AppSpacing.sm,
                          ),
                          color: AppColors.surfaceDark,
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // TOOL BUTTONS ROW (Rotate, Reset)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildToolButton(
                                      icon: Icons.rotate_left_rounded,
                                      label: AppStrings.rotateLeft,
                                      onTap: _rotateCounterClockwise,
                                    ),
                                    _buildToolButton(
                                      icon: Icons.refresh_rounded,
                                      label: AppStrings.resetCrop,
                                      onTap: _resetCrop,
                                    ),
                                    _buildToolButton(
                                      icon: Icons.rotate_right_rounded,
                                      label: AppStrings.rotateRight,
                                      onTap: _rotateClockwise,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // ACTION BUTTONS (RETAKE & USE PHOTO)
                                Row(
                                  children: [
                                    Expanded(
                                      child: SecondaryButton(
                                        label: AppStrings.retake,
                                        onPressed: () => Navigator.pop(context, null),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: PrimaryButton(
                                        label: AppStrings.usePhoto,
                                        icon: const Icon(Icons.check_rounded, size: 20),
                                        onPressed: _applyCropAndReturn,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypography.caption(context).copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _HandleType _hitTestHandle(Offset pos, Rect crop) {
    // 44 dp touch target radius (at least 22 radius = 44x44 dp)
    const handleRadius = 28.0;

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
  final int rotation;

  static final Paint _dimPaint = Paint()..color = AppColors.scrimDark;
  static final Paint _borderPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;
  static final Paint _gridPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.2)
    ..strokeWidth = 1.0;
  static final Paint _cornerPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  _CropperPainter({
    required this.image,
    required this.imageRect,
    required this.cropRect,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

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

    // 4. Draw Rule of Thirds grid
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

    // 5. Draw 4 Corner Handles (Apple style corner brackets / rounded dots)
    const cornerSize = 12.0;
    canvas.drawCircle(cropRect.topLeft, cornerSize / 2, _cornerPaint);
    canvas.drawCircle(cropRect.topRight, cornerSize / 2, _cornerPaint);
    canvas.drawCircle(cropRect.bottomLeft, cornerSize / 2, _cornerPaint);
    canvas.drawCircle(cropRect.bottomRight, cornerSize / 2, _cornerPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CropperPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.rotation != rotation;
  }
}
