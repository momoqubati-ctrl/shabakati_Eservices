import 'package:flutter_test/flutter_test.dart';
import 'package:shabakti_eservices/core/utils/error_sanitizer.dart';

void main() {
  group('ErrorSanitizer Tests', () {
    test('Offline / SocketException with Supabase URL leaks', () {
      const offlineWithUrl =
          "ClientException with SocketException: Failed host lookup: 'enutfwspwrzpvhmtgftl.supabase.co' (OS Error: No address associated with hostname, errno = 7), uri=https://enutfwspwrzpvhmtgftl.supabase.co/rest/v1/rpc/rpc_login_user";

      final sanitized = ErrorSanitizer.sanitize(offlineWithUrl);
      expect(sanitized, 'أنت غير متصل بالإنترنت، يرجى التحقق من اتصالك والمحاولة مرة أخرى');
      expect(sanitized.contains('supabase'), isFalse);
      expect(sanitized.contains('enutfwspwrzpvhmtgftl'), isFalse);
    });

    test('Generic SocketException', () {
      const err = 'SocketException: OS Error: Connection timed out, errno = 110';
      final sanitized = ErrorSanitizer.sanitize(err);
      expect(sanitized, 'أنت غير متصل بالإنترنت، يرجى التحقق من اتصالك والمحاولة مرة أخرى');
    });

    test('TimeoutException', () {
      const err = 'TimeoutException after 0:00:30.000000: Future not completed';
      final sanitized = ErrorSanitizer.sanitize(err);
      expect(sanitized, 'أنت غير متصل بالإنترنت، يرجى التحقق من اتصالك والمحاولة مرة أخرى');
    });

    test('Internal Database or Postgres leaks are blocked', () {
      const err = 'PostgrestException(message: relation "users" does not exist, code: 42P01, details: null, hint: null)';
      final sanitized = ErrorSanitizer.sanitize(err);
      expect(sanitized, 'حدث خطأ في معالجة الطلب، يرجى المحاولة لاحقاً');
      expect(sanitized.contains('PostgrestException'), isFalse);
      expect(sanitized.contains('42P01'), isFalse);
    });

    test('Legitimate Arabic user-facing errors are preserved cleanly', () {
      expect(
        ErrorSanitizer.sanitize('Exception: رقم الحساب غير مسجل في النظام. يرجى إنشاء حساب جديد أولاً.'),
        'رقم الحساب غير مسجل في النظام. يرجى إنشاء حساب جديد أولاً.',
      );

      expect(
        ErrorSanitizer.sanitize('Exception: كلمة المرور غير صحيحة، يرجى التأكد وإعادة المحاولة.'),
        'كلمة المرور غير صحيحة، يرجى التأكد وإعادة المحاولة.',
      );

      expect(
        ErrorSanitizer.sanitize('Exception: تم قفل الحساب مؤقتاً لمدة 15 دقيقة بسبب تجاوز عدد المحاولات الخاطئة المسموحة.'),
        'تم قفل الحساب مؤقتاً لمدة 15 دقيقة بسبب تجاوز عدد المحاولات الخاطئة المسموحة.',
      );

      expect(
        ErrorSanitizer.sanitize('يرجى إدخال رقم الحساب / الهاتف'),
        'يرجى إدخال رقم الحساب / الهاتف',
      );
    });

    test('Null or empty returns generic safe error', () {
      expect(ErrorSanitizer.sanitize(null), 'حدث خطأ في معالجة الطلب، يرجى المحاولة لاحقاً');
      expect(ErrorSanitizer.sanitize(''), 'حدث خطأ في معالجة الطلب، يرجى المحاولة لاحقاً');
    });
  });
}
