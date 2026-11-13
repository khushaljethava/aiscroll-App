import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Captures the widget tree behind [boundaryKey] (which must wrap a
/// RepaintBoundary) and shares it as a PNG. Falls back to text-only share
/// when the capture fails for any reason (no context yet, wrong render
/// object, null byte data).
///
/// Returns true unless the user dismissed the share sheet, so callers only
/// reward real shares. Platforms that can't report the outcome
/// (`unavailable`) count as shared.
Future<bool> shareWidgetAsImage({
  required GlobalKey boundaryKey,
  required String fallbackText,
  String? subject,
  double pixelRatio = 3.0,
}) async {
  final textOnly = ShareParams(text: fallbackText, subject: subject);
  final boundary = boundaryKey.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return _share(textOnly);
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? bytes =
      await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return _share(textOnly);
  final pngBytes = bytes.buffer.asUint8List();
  final file = XFile.fromData(
    pngBytes,
    mimeType: 'image/png',
    name: 'brevio-card.png',
    length: pngBytes.lengthInBytes,
  );
  return _share(ShareParams(
    files: [file],
    text: fallbackText,
    subject: subject,
  ));
}

Future<bool> _share(ShareParams params) async {
  final result = await SharePlus.instance.share(params);
  return result.status != ShareResultStatus.dismissed;
}
