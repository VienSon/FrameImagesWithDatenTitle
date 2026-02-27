import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class FrameRenderer {
  Future<Uint8List> render({
    required Uint8List originalBytes,
    required String title,
    required String dateTimeText,
    required String locationText,
    Color backgroundColor = const Color(0xFFF8F4EC),
  }) async {
    final codec = await ui.instantiateImageCodec(originalBytes);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;

    final photoW = image.width;
    final photoH = image.height;

    final shortSide = photoW < photoH ? photoW : photoH;
    final sideBorder = (shortSide * 0.06).round();
    final topBorder = (shortSide * 0.06).round();
    final bottomBorder = (shortSide * 0.28).round();

    final outW = photoW + sideBorder * 2;
    final outH = photoH + topBorder + bottomBorder;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      Paint()..color = backgroundColor,
    );

    canvas.drawImage(image, Offset(sideBorder.toDouble(), topBorder.toDouble()), Paint());

    final horizontalPadding = sideBorder * 0.9;
    final textWidth = outW - horizontalPadding * 2;
    final baselineY = topBorder + photoH + (bottomBorder * 0.16);

    final safeTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final metaText = '$dateTimeText\n$locationText';

    final titlePainter = TextPainter(
      text: TextSpan(
        text: safeTitle,
        style: TextStyle(
          color: const Color(0xFF1D1D1D),
          fontSize: shortSide * 0.06,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(minWidth: 0, maxWidth: textWidth.toDouble());

    titlePainter.paint(
      canvas,
      Offset((outW - titlePainter.width) / 2, baselineY.toDouble()),
    );

    final metaPainter = TextPainter(
      text: TextSpan(
        text: metaText,
        style: TextStyle(
          color: const Color(0xFF3E3E3E),
          fontSize: shortSide * 0.035,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '...',
    )..layout(minWidth: 0, maxWidth: textWidth.toDouble());

    final metaTop = baselineY + titlePainter.height + (shortSide * 0.02);
    metaPainter.paint(canvas, Offset((outW - metaPainter.width) / 2, metaTop));

    final finalImage = await recorder.endRecording().toImage(outW, outH);
    final data = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Failed to encode final image bytes.');
    }
    return data.buffer.asUint8List();
  }
}
