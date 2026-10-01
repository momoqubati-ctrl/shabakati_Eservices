import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/auth_biometric_service.dart';
import '../../core/services/otp_service.dart';
import '../../data/models/user_account_model.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final IAuthRepository authRepository;
  final AuthBiometricService biometricService;
  final OtpService otpService;

  UserAccountModel? currentUser;

  AuthCubit({
    required this.authRepository,
    required this.biometricService,
    required this.otpService,
  }) : super(AuthInitial());

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
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

      // فحص هل هذه أول مرة يدخل فيها بدون تفعيل البصمة
      final hasBiometric = await biometricService.isBiometricEnabled();
      final canBiometric = await biometricService.isBiometricAvailable();

      emit(AuthSuccess(
        user: user,
        isFirstLogin: !hasBiometric && canBiometric,
      ));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
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
      emit(AuthSuccess(user: user, isFirstLogin: false));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  /// حفظ وتفعيل خيار البصمة
  Future<void> enableBiometrics({
    required UserAccountModel user,
    required String pin4Digits,
  }) async {
    final hash = _hashPin(pin4Digits);
    await biometricService.setBiometricEnabled(
      enabled: true,
      accountNumber: user.accountNumber,
      passwordHash: hash,
      userName: user.fullName,
      region: user.region,
    );
    await authRepository.updateBiometricStatus(
      accountNumber: user.accountNumber,
      enabled: true,
    );
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
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
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
        currentUser = user;
        final canBiometric = await biometricService.isBiometricAvailable();
        emit(AuthSuccess(user: user, isFirstLogin: canBiometric));
        return true;
      } else {
        emit(const AuthError('رمز التحقق غير صحيح أو انتهت صلاحيته'));
        emit(AuthOtpRequired(user: user, phoneWithCode: phoneWithCode));
        return false;
      }
    } catch (e) {
      emit(AuthError('فشل التحقق من الرمز: ${e.toString().replaceAll('Exception: ', '')}'));
      emit(AuthOtpRequired(user: user, phoneWithCode: phoneWithCode));
      return false;
    }
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    currentUser = null;
    emit(AuthInitial());
  }
}
