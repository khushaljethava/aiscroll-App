import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the platform browser. Silently no-ops on invalid URLs.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
