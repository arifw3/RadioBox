import 'package:url_launcher/url_launcher.dart';

/// Store-review "content report / contact" requirement — a cheap mailto:
/// link is enough; there's no support ticket backend to build for a
/// zero-cost app.
Future<void> openContactEmail() async {
  final uri = Uri(
    scheme: 'mailto',
    path: 'seraperzin@gmail.com',
    query: 'subject=${Uri.encodeComponent('Radio Box - İçerik Bildirimi / Contact')}',
  );
  await launchUrl(uri);
}
