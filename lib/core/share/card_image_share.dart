import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Captures the widget tree behind [boundaryKey] (which must wrap a
/// RepaintBoundary) and shares it as a PNG. Falls back to text-only share
/// when the capture fails for any reason (no context yet, wrong render
/// object, null byte data).
Future<bool> shareWidgetAsImage({
  required GlobalKey boundaryKey,
  required String fallbackText,
  String? subject,
  double pixelRatio = 3.0,
}) async {
  final ctx = boundaryKey.currentContext;
  if (ctx == null) {
    await SharePlus.instance.share(
      ShareParams(text: fallbackText, subject: subject),
    );
    return false;
  }
  final boundary = ctx.findRenderObject();
  if (boundary == null || boundary is! RenderRepaintBoundary) {
    await SharePlus.instance.share(
      ShareParams(text: fallbackText, subject: subject),
    );
    return false;
  }
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    await SharePlus.instance.share(
      ShareParams(text: fallbackText, subject: subject),
    );
    return false;
  }
  final pngBytes = bytes.buffer.asUint8List();
  final file = XFile.fromData(
    pngBytes,
    mimeType: 'image/png',
    name: 'brevio-card.png',
    length: pngBytes.lengthInBytes,
  );
  await SharePlus.instance.share(
    ShareParams(
      files: [file],
      text: fallbackText,
      subject: subject,
    ),
  );
  return true;
}
