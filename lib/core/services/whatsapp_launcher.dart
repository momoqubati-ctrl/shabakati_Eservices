import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class WhatsAppLauncher {
  /// ينظف ويهيئ رقم الهاتف للواتساب الدولي (بما يشمل أرقام اليمن 967)
  static String sanitizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }
    // في حال إدخال الرقم المحلي 07xxxxxxxx يتم تحويله إلى 9677xxxxxxxx
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      cleaned = '967${cleaned.substring(1)}';
    } else if (cleaned.length == 9 && cleaned.startsWith('7')) {
      cleaned = '967$cleaned';
    }
    return cleaned;
  }

  /// يفتح محادثة واتساب مباشرة مع أي رقم ورسالة محددة
  static Future<bool> openChat({required String phone, required String message}) async {
    final sanitized = sanitizePhone(phone);
    final encodedText = Uri.encodeComponent(message);

    // 1. بروتوكول تطبيق واتساب المباشر
    final appUri = Uri.parse('whatsapp://send?phone=$sanitized&text=$encodedText');
    // 2. رابط الويب الرسمي القياسي
    final webUri = Uri.parse('https://wa.me/$sanitized?text=$encodedText');

    try {
      if (await canLaunchUrl(appUri)) {
        return await launchUrl(appUri);
      } else {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('WhatsApp chat launch error: $e');
      try {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  /// يفتح محادثة الدعم الفني المباشرة
  static Future<bool> openSupportChat({String? message}) async {
    final phone = ApiConfig.whatsappSupportPhone;
    const defaultMsg = 'مرحباً، أحتاج إلى مساعدة بخصوص خدمات شبكتي الإلكترونية';
    return openChat(phone: phone, message: message ?? defaultMsg);
  }

  /// يرسل بيانات المفتاح / الكود الرقمي إلى رقم العميل عبر واتساب
  static Future<bool> sendKeyToCustomer({
    required String phone,
    required String keyOrUrl,
    String? orderId,
  }) async {
    final isUrl = keyOrUrl.trim().toLowerCase().startsWith('http://') ||
        keyOrUrl.trim().toLowerCase().startsWith('https://');

    final msg = '''
مرحباً، إليك تفاصيل ${isUrl ? 'رابط الخدمة / التفعيل' : 'كود التفعيل / المفتاح الرقمي'} لطلبك:
🔑 ${isUrl ? 'الرابط' : 'الكود'}: $keyOrUrl
${orderId != null && orderId.isNotEmpty ? '📋 رقم الطلب: $orderId\n' : ''}شكراً لتعاملك مع بوابة شبكتي للخدمات الرقمية!
'''.trim();

    return openChat(phone: phone, message: msg);
  }
}
