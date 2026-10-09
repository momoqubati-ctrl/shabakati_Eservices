import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/auth_biometric_service.dart';
import '../../core/services/otp_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/utils/error_sanitizer.dart';
import '../../data/models/user_account_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final IAuthRepository authRepository;
  final AuthBiometricService biometricService;
  final OtpService otpService;
  final SecureStorageService secureStorageService;

  UserAccountModel? currentUser;
  String? _lastPin4Digits;
  bool _hasPendingBiometricPrompt = false;

  AuthCubit({
    required this.authRepository,
    required this.biometricService,
    required this.otpService,
    SecureStorageService? secureStorageService,
  })  : secureStorageService = secureStorageService ?? SecureStorageService(),
        super(AuthInitial());

  /// هل المستخدم مسجل دخوله حالياً بحساب نشط وموثق؟
  bool get isAuthenticated => currentUser != null && state is AuthSuccess;

  /// استهلاك طلب عرض نافذة تفعيل البصمة لأول مرة لمنع تكرارها أو ضياعها عند انتقال الشاشات
  bool consumeFirstLoginBiometricPrompt() {
    if (!_hasPendingBiometricPrompt) return false;
    _hasPendingBiometricPrompt = false;
    return true;
  }

  /// استعادة جلسة المستخدم المحفوظة عند فتح التطبيق
  Future<void> restoreSavedSession() async {
    try {
      final savedUser = await secureStorageService.getActiveUser();
      if (savedUser == null) {
        emit(AuthInitial());
        return;
      }

      final isSessionValid = await secureStorageService.isSessionValid();
      final hasBiometric = await biometricService.isBiometricEnabled();

      if (isSessionValid) {
        currentUser = savedUser;
        // تجديد نشاط الجلسة (Sliding session)
        await secureStorageService.extendSession();
        emit(AuthSuccess(user: savedUser, isFirstLogin: false));
      } else {
        // انتهت صلاحية الجلسة، يتطلب تأكيد الهوية بالبصمة أو كلمة السر
        currentUser = savedUser;
        emit(AuthSessionExpired(
          user: savedUser,
          hasBiometric: hasBiometric,
          message: 'انتهت صلاحية الجلسة السابقة، يرجى تأكيد الهوية للمتابعة',
        ));
      }
    } catch (e) {
      debugPrint('Error restoring saved session: $e');
      emit(AuthInitial());
    }
  }

  String _hashPinSalted(String accountNumber, String pin) {
    final cleanAcc = accountNumber.trim();
    final cleanPin = pin.trim();
    final bytes = utf8.encode('$cleanAcc:$cleanPin:shabakti_sec_v1');
    return sha256.convert(bytes).toString();
  }

  /// فحص هل البصمة مفعلة مسبقاً لهذا الجهاز
  Future<bool> isBiometricEnabled() async {
    return await biometricService.isBiometricEnabled();
  }

  /// جلب رقم الحساب المحفوظ للبصمة
  Future<String?> getSavedAccount() async {
    return await biometricService.getSavedAccount();
  }

  /// تسجيل الدخول بالرقم وكلمة المرور (4 أرقام)
  Future<void> loginWithCredentials({
    required String accountNumber,
    required String pin4Digits,
  }) async {
    emit(const AuthLoading(loadingMessage: 'جاري التحقق من بيانات الحساب...'));
    try {
      final user = await authRepository.loginUser(
        accountNumber: accountNumber,
        pin4Digits: pin4Digits,
      );

      currentUser = user;
      _lastPin4Digits = pin4Digits.trim();
      await secureStorageService.saveActiveUser(user);

      // فحص هل هذه أول مرة يدخل فيها بدون تفعيل البصمة
      final hasBiometric = await biometricService.isBiometricEnabled();
      final canBiometric = await biometricService.isBiometricAvailable();

      if (hasBiometric) {
        final savedAcc = await biometricService.getSavedAccount();
        if (savedAcc == user.accountNumber) {
          await biometricService.setBiometricEnabled(
            enabled: true,
            accountNumber: user.accountNumber,
            passwordHash: _hashPinSalted(user.accountNumber, pin4Digits),
            userName: user.fullName,
            region: user.region,
          );
        }
      }

      final shouldPromptBiometric = !hasBiometric && canBiometric;
      _hasPendingBiometricPrompt = shouldPromptBiometric;

      emit(AuthSuccess(
        user: user,
        isFirstLogin: shouldPromptBiometric,
      ));
    } catch (e) {
      emit(AuthError(ErrorSanitizer.sanitize(e)));
    }
  }

  /// تسجيل الدخول الفوري بالبصمة
  Future<void> loginWithBiometrics() async {
    final hasBiometric = await biometricService.isBiometricEnabled();
    if (!hasBiometric) {
      emit(const AuthError('البصمة غير مفعلة لهذا الحساب'));
      return;
    }

    final authenticated = await biometricService.authenticateWithBiometrics(
      reason: 'المصادقة السريعة للدخول إلى حسابك',
    );

    if (!authenticated) {
      // ألغى المستخدم أو فشلت البصمة
      return;
    }

    emit(const AuthLoading(loadingMessage: 'جاري الدخول الآمن بالبصمة...'));
    try {
      final savedAccount = await biometricService.getSavedAccount();
      final savedHash = await biometricService.getSavedPasswordHash();

      if (savedAccount == null || savedHash == null) {
        emit(const AuthError('بيانات البصمة غير مكتملة، يرجى الدخول بكلمة المرور'));
        return;
      }

      final user = await authRepository.loginWithStoredHash(
        accountNumber: savedAccount,
        passwordHash: savedHash,
      );

      currentUser = user;
      await secureStorageService.saveActiveUser(user);
      emit(AuthSuccess(user: user, isFirstLogin: false));
    } catch (e) {
      emit(AuthError(ErrorSanitizer.sanitize(e)));
    }
  }

  /// تمديد الجلسة وتوثيق الدخول بالبصمة
  Future<bool> extendSessionWithBiometrics() async {
    final hasBiometric = await biometricService.isBiometricEnabled();
    if (!hasBiometric) {
      emit(const AuthError('البصمة غير مفعلة لهذا الحساب'));
      return false;
    }

    final authenticated = await biometricService.authenticateWithBiometrics(
      reason: 'المصادقة بالبصمة لتمديد صلاحية الجلسة والدخول',
    );

    if (!authenticated) {
      return false;
    }

    emit(const AuthLoading(loadingMessage: 'جاري تمديد الجلسة والدخول الآمن...'));
    try {
      final savedAccount = await biometricService.getSavedAccount();
      final savedHash = await biometricService.getSavedPasswordHash();

      if (savedAccount == null || savedHash == null) {
        emit(const AuthError('بيانات البصمة غير مكتملة، يرجى الدخول بكلمة المرور'));
        return false;
      }

      final user = await authRepository.loginWithStoredHash(
        accountNumber: savedAccount,
        passwordHash: savedHash,
      );

      currentUser = user;
      await secureStorageService.saveActiveUser(user);
      await secureStorageService.extendSession();
      emit(AuthSuccess(user: user, isFirstLogin: false));
      return true;
    } catch (e) {
      emit(AuthError(ErrorSanitizer.sanitize(e)));
      return false;
    }
  }

  /// تمديد صلاحية الجلسة الحالية
  Future<void> extendSession() async {
    await secureStorageService.extendSession();
    if (currentUser != null && state is! AuthSuccess) {
      emit(AuthSuccess(user: currentUser!, isFirstLogin: false));
    }
  }

  /// طلب مسح البصمة الفعلي من الهاتف ثم حفظ وتفعيل الدخول بالبصمة
  Future<bool> authenticateAndEnableBiometrics({
    required UserAccountModel user,
    String? pin4Digits,
  }) async {
    final effectivePin = (pin4Digits != null && pin4Digits.trim().isNotEmpty)
        ? pin4Digits.trim()
        : _lastPin4Digits;
    if (effectivePin == null || effectivePin.isEmpty) {
      return false;
    }

    final authenticated = await biometricService.authenticateWithBiometrics(
      reason: 'امسح بصمتك لتفعيل الدخول السريع إلى حسابك',
    );
    if (!authenticated) {
      return false;
    }

    await enableBiometrics(user: user, pin4Digits: effectivePin);
    return true;
  }

  /// حفظ وتفعيل خيار البصمة
  Future<void> enableBiometrics({
    required UserAccountModel user,
    required String pin4Digits,
  }) async {
    final hash = _hashPinSalted(user.accountNumber, pin4Digits);
    await biometricService.setBiometricEnabled(
      enabled: true,
      accountNumber: user.accountNumber,
      passwordHash: hash,
      userName: user.fullName,
      region: user.region,
    );
    try {
      await authRepository.updateBiometricStatus(
        accountNumber: user.accountNumber,
        enabled: true,
        sessionToken: user.sessionToken,
      );
    } catch (e) {
      debugPrint('Notice: updateBiometricStatus server sync skipped: $e');
    }
    currentUser = user.copyWith(biometricEnabled: true);
    await secureStorageService.saveActiveUser(currentUser!);
    emit(AuthSuccess(user: currentUser!, isFirstLogin: false));
  }

  /// إلغاء تفعيل خيار البصمة ومسح بياناتها محلياً وفي السحابة
  Future<void> disableBiometrics() async {
    await biometricService.setBiometricEnabled(enabled: false);
    if (currentUser != null) {
      try {
        await authRepository.updateBiometricStatus(
          accountNumber: currentUser!.accountNumber,
          enabled: false,
          sessionToken: currentUser!.sessionToken,
        );
      } catch (e) {
        debugPrint('Notice: updateBiometricStatus server sync skipped: $e');
      }
      currentUser = currentUser!.copyWith(biometricEnabled: false);
      await secureStorageService.saveActiveUser(currentUser!);
      emit(AuthSuccess(user: currentUser!, isFirstLogin: false));
    }
  }

  /// التبديل لحساب آخر عند انتهاء الجلسة أو طلب المستخدم
  Future<void> switchUser() async {
    await secureStorageService.clearActiveUser();
    currentUser = null;
    _lastPin4Digits = null;
    _hasPendingBiometricPrompt = false;
    emit(AuthInitial());
  }

  /// تسجيل حساب جديد والتحقق
  Future<void> registerUser({
    required String dialCode,
    required String phoneNational,
    required String fullName,
    required String region,
    required String pin4Digits,
  }) async {
    emit(const AuthLoading(loadingMessage: 'جاري إنشاء الحساب وإرسال رمز التحقق...'));
    try {
      final user = await authRepository.registerUser(
        dialCode: dialCode,
        phoneNational: phoneNational,
        fullName: fullName,
        region: region,
        pin4Digits: pin4Digits,
      );

      currentUser = user;
      _lastPin4Digits = pin4Digits.trim();

      // إرسال رمز OTP عبر الواتساب
      final sent = await otpService.sendOtp(
        phoneWithCode: user.accountNumber,
        channel: 'whatsapp',
      );

      if (!sent) {
        debugPrint('Notice: OTP stored in Supabase, gateway dispatch returned false');
      }

      emit(AuthOtpRequired(
        user: user,
        phoneWithCode: user.accountNumber,
        channel: 'whatsapp',
      ));
    } catch (e) {
      emit(AuthError(ErrorSanitizer.sanitize(e)));
    }
  }

  /// إعادة إرسال رمز OTP (واتساب أو SMS)
  Future<bool> resendOtp({
    required String phoneWithCode,
    String channel = 'whatsapp',
  }) async {
    return await otpService.sendOtp(
      phoneWithCode: phoneWithCode,
      channel: channel,
    );
  }

  /// التحقق من رمز OTP
  Future<bool> verifyOtp({
    required String phoneWithCode,
    required String enteredOtp,
    required UserAccountModel user,
  }) async {
    emit(const AuthLoading(loadingMessage: 'جاري التحقق من رمز التأكيد...'));
    try {
      final isValid = await otpService.verifyOtp(
        phoneWithCode: phoneWithCode,
        enteredOtp: enteredOtp,
      );

      if (isValid) {
        final verifiedUser = user.copyWith(isVerified: true);
        currentUser = verifiedUser;
        await secureStorageService.saveActiveUser(verifiedUser);
        final hasBiometric = await biometricService.isBiometricEnabled();
        final canBiometric = await biometricService.isBiometricAvailable();
        final shouldPromptBiometric = !hasBiometric && canBiometric;
        _hasPendingBiometricPrompt = shouldPromptBiometric;
        emit(AuthSuccess(user: verifiedUser, isFirstLogin: shouldPromptBiometric));
        return true;
      } else {
        emit(const AuthError('رمز التحقق غير صحيح أو انتهت صلاحيته'));
        return false;
      }
    } catch (e) {
      emit(AuthError(ErrorSanitizer.sanitize(e)));
      return false;
    }
  }

  /// تغيير كلمة المرور للمستخدم المسجل حالياً
  Future<void> changePassword({
    required String oldPin4Digits,
    required String newPin4Digits,
  }) async {
    final user = currentUser ?? await secureStorageService.getActiveUser();
    if (user == null) {
      throw Exception('يرجى تسجيل الدخول أولاً لتغيير كلمة المرور.');
    }

    await authRepository.changePassword(
      accountNumber: user.accountNumber,
      oldPin4Digits: oldPin4Digits,
      newPin4Digits: newPin4Digits,
    );

    // تحديث الهاش المحفوظ للبصمة إذا كانت مفعلة لنفس الحساب
    final hasBiometric = await biometricService.isBiometricEnabled();
    if (hasBiometric) {
      final savedAcc = await biometricService.getSavedAccount();
      if (savedAcc == user.accountNumber) {
        await biometricService.setBiometricEnabled(
          enabled: true,
          accountNumber: user.accountNumber,
          passwordHash: _hashPinSalted(user.accountNumber, newPin4Digits),
          userName: user.fullName,
          region: user.region,
        );
      }
    }
  }

  /// التحقق من وجود رقم الحساب وإرسال رمز OTP لاستعادة كلمة المرور
  Future<String> sendPasswordResetOtp({
    required String accountNumber,
    String channel = 'whatsapp',
  }) async {
    final resolvedAccount = await authRepository.checkAccountExists(
      accountNumber: accountNumber,
    );

    await otpService.sendOtp(
      phoneWithCode: resolvedAccount,
      channel: channel,
    );

    return resolvedAccount;
  }

  /// التحقق من رمز OTP الخاص باستعادة كلمة المرور
  Future<bool> verifyPasswordResetOtp({
    required String accountNumber,
    required String enteredOtp,
  }) async {
    return await otpService.verifyOtp(
      phoneWithCode: accountNumber,
      enteredOtp: enteredOtp,
    );
  }

  /// تعيين كلمة مرور جديدة بعد التحقق من رمز OTP بنجاح
  Future<void> resetPasswordWithVerifiedOtp({
    required String accountNumber,
    required String newPin4Digits,
  }) async {
    final cleanPhone = otpService.sanitizePhoneNumber(accountNumber);
    await authRepository.resetPassword(
      accountNumber: accountNumber,
      cleanPhone: cleanPhone,
      newPin4Digits: newPin4Digits,
    );

    // إذا كانت البصمة مفعلة محلياً لنفس الحساب، نحدث الهاش المخزن ليتطابق مع كلمة المرور الجديدة
    final hasBiometric = await biometricService.isBiometricEnabled();
    if (hasBiometric) {
      final savedAcc = await biometricService.getSavedAccount();
      if (savedAcc == accountNumber) {
        await biometricService.setBiometricEnabled(
          enabled: true,
          accountNumber: accountNumber,
          passwordHash: _hashPinSalted(accountNumber, newPin4Digits),
        );
      }
    }
  }

  /// تسجيل الخروج العادي
  Future<void> logout() async {
    await secureStorageService.clearActiveUser();
    currentUser = null;
    _lastPin4Digits = null;
    _hasPendingBiometricPrompt = false;
    emit(AuthInitial());
  }

  /// تسجيل الخروج النهائي ومسح كافة بيانات التطبيق والتخزين المشفر بالكامل
  Future<void> finalLogout() async {
    try {
      await biometricService.clearAuthData();
    } catch (_) {}
    try {
      await secureStorageService.wipeAllData();
    } catch (_) {}
    currentUser = null;
    _lastPin4Digits = null;
    _hasPendingBiometricPrompt = false;
    emit(AuthInitial());
  }
}
