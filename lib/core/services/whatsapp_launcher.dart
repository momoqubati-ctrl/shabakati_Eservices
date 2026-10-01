import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class WhatsAppLauncher {
  /// Opens a direct WhatsApp chat with the customer technical support number.
  /// First attempts the native whatsapp:// scheme, then falls back to https://wa.me/.
  static Future<bool> openSupportChat({String? message}) async {
    final phone = ApiConfig.whatsappSupportPhone;
    final defaultMsg = 'مرحباً، أحتاج إلى مساعدة بخصوص خدمات شبكتي الإلكترونية';
    final text = message ?? defaultMsg;
    final encodedText = Uri.encodeComponent(text);

    // 1. Direct App Protocol (bypasses browser redirect if installed)
    final appUri = Uri.parse('whatsapp://send?phone=$phone&text=$encodedText');
    // 2. Official Meta wa.me Universal Web Link
    final webUri = Uri.parse('https://wa.me/$phone?text=$encodedText');

    try {
      if (await canLaunchUrl(appUri)) {
        return await launchUrl(appUri);
      } else {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('WhatsApp native launch failed, using fallback: $e');
      try {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }
}
