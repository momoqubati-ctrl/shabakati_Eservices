import '../../data/models/user_account_model.dart';

abstract class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {
  final String? loadingMessage;
  const AuthLoading({this.loadingMessage});
}

class AuthSuccess extends AuthState {
  final UserAccountModel user;
  final bool isFirstLogin;
  const AuthSuccess({required this.user, this.isFirstLogin = false});
}

class AuthOtpRequired extends AuthState {
  final UserAccountModel user;
  final String phoneWithCode;
  final String channel; // 'whatsapp' or 'sms'
  const AuthOtpRequired({
    required this.user,
    required this.phoneWithCode,
    this.channel = 'whatsapp',
  });
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
