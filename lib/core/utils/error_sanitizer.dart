/// أداة حماية وتنقية رسائل الأخطاء للنظام وتجربة المستخدم
/// تضمن عدم تسريب أي عناوين خوادم، أو روابط، أو استثناءات تقنية، أو أسرار النظام
class ErrorSanitizer {
  /// الرسالة الرسمية المعتمدة لجميع حالات انقطاع الإنترنت أو فشل الاتصال بالخادم
  static const String offlineMessage =
      'أنت غير متصل بالإنترنت، يرجى التحقق من اتصالك والمحاولة مرة أخرى';

  /// الرسالة الرسمية المعتمدة لأي خطأ برمجي غير متوقع لمنع تسريب أسرار النظام
  static const String genericErrorMessage =
      'حدث خطأ في معالجة الطلب، يرجى المحاولة لاحقاً';

  /// تنقية أي استثناء (Exception / Error / String) وتحويله إلى نص عربي آمن تماماً
  static String sanitize(dynamic error) {
    if (error == null) return genericErrorMessage;

    final raw = error.toString().trim();
    if (raw.isEmpty) return genericErrorMessage;

    final lower = raw.toLowerCase();

    // 1. كشف انقطاع الإنترنت ومشاكل الاتصال بالشبكة (أعلى أولوية)
    if (_isNetworkOrOffline(lower)) {
      return offlineMessage;
    }

    // 2. كشف أخطاء قواعد البيانات أو الاستثناءات التقنية الداخلية
    if (_isTechnicalOrInternal(lower)) {
      return genericErrorMessage;
    }

    // 3. كشف أي تسريب لعناوين النطاقات الحساسة أو روابط البنية التحتية
    if (_containsSensitiveLeak(lower)) {
      // أي خطأ متبقٍ يتضمن رابط خادم دون أن يكون خطأ داخلياً فهو ناتج عن تعذر الاتصال
      return offlineMessage;
    }

    // 4. استخراج النص وإزالة بادئات Exception المعتادة
    var clean = raw;
    if (clean.startsWith('Exception: ')) {
      clean = clean.substring('Exception: '.length).trim();
    } else if (clean.startsWith('Exception:')) {
      clean = clean.substring('Exception:'.length).trim();
    }

    // فحص إضافي بعد التنظيف
    final cleanLower = clean.toLowerCase();
    if (_isNetworkOrOffline(cleanLower)) {
      return offlineMessage;
    }
    if (_isTechnicalOrInternal(cleanLower)) {
      return genericErrorMessage;
    }
    if (_containsSensitiveLeak(cleanLower)) {
      return offlineMessage;
    }

    // 5. إذا كانت الرسالة باللغة العربية ونظيفة من أي أسرار، يتم إظهارها بأمان
    if (_isSafeArabicMessage(clean)) {
      return clean;
    }

    // كإجراء أمان افتراضي لأي نص أجنبي أو غير معروف
    return genericErrorMessage;
  }

  static bool _isNetworkOrOffline(String lower) {
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('httpexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('tlsexception') ||
        lower.contains('certificate_verify_failed') ||
        lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('connection aborted') ||
        lower.contains('network is unreachable') ||
        lower.contains('networkerror') ||
        lower.contains('network_error') ||
        lower.contains('network unreachable') ||
        lower.contains('no internet') ||
        lower.contains('not connected') ||
        lower.contains('offline') ||
        lower.contains('os error') ||
        lower.contains('errno') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('software caused connection abort') ||
        lower.contains('broken pipe') ||
        lower.contains('host lookup') ||
        lower.contains('no address associated');
  }

  static bool _containsSensitiveLeak(String lower) {
    return lower.contains('supabase.co') ||
        lower.contains('supabase') ||
        lower.contains('sahalnahaa') ||
        lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('.cloud') ||
        lower.contains('rest/v1') ||
        lower.contains('rpc_');
  }

  static bool _isTechnicalOrInternal(String lower) {
    return lower.contains('postgrest') ||
        lower.contains('pgrst') ||
        lower.contains('nosuchmethoderror') ||
        lower.contains('typeerror') ||
        lower.contains('formatexception') ||
        lower.contains('lateinitializationerror') ||
        lower.contains('rangeerror') ||
        lower.contains('stateerror') ||
        lower.contains('null check operator') ||
        lower.contains('stack trace') ||
        lower.contains('stacktrace') ||
        lower.contains('syntax error') ||
        lower.contains('relation "') ||
        lower.contains('column "') ||
        lower.contains('function "') ||
        lower.contains('violates foreign key') ||
        lower.contains('violates unique') ||
        lower.contains('violates check') ||
        lower.contains('sqlstate') ||
        lower.contains('42501') ||
        lower.contains('22p02') ||
        lower.contains('23505') ||
        lower.contains('database error') ||
        lower.contains('internal server error');
  }

  static bool _isSafeArabicMessage(String msg) {
    // التأكد من خلو الرسالة من أي رابط أو مسار برمجي أو نطاق
    if (msg.contains('://') ||
        msg.contains('.co') ||
        msg.contains('.com') ||
        msg.contains('.net') ||
        msg.contains('.org') ||
        msg.contains('.cloud') ||
        msg.contains('{') ||
        msg.contains('}') ||
        msg.contains('<') ||
        msg.contains('>')) {
      return false;
    }
    // يجب أن تحتوي الرسالة على حروف عربية
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(msg);
  }
}
