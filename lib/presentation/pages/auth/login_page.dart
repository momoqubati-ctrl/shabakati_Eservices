import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/country_codes.dart';
import '../../../data/models/user_account_model.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/auth/auth_state.dart';
import '../../widgets/phone_input_field.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  CountryCodeModel _selectedCountry = CountryCodes.defaultCountry;
  bool _obscurePin = true;
  bool _hasBiometricEnabled = false;
  bool _hasAutoPromptedBiometric = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    if (authState is AuthSessionExpired) {
      _fillUserData(authState.user);
      _hasBiometricEnabled = authState.hasBiometric;
      if (authState.hasBiometric && !_hasAutoPromptedBiometric) {
        _hasAutoPromptedBiometric = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _onBiometricLogin();
          }
        });
      }
    } else {
      _checkBiometrics();
    }
  }

  void _fillUserData(UserAccountModel user) {
    for (var c in CountryCodes.all) {
      if (user.accountNumber.startsWith(c.dialCode)) {
        if (mounted) {
          setState(() {
            _selectedCountry = c;
            _phoneController.text = user.accountNumber.substring(c.dialCode.length);
          });
        }
        return;
      }
    }
    if (mounted) {
      setState(() {
        _phoneController.text = user.phoneNational;
      });
    }
  }

  Future<void> _checkBiometrics() async {
    final cubit = context.read<AuthCubit>();
    final isEnabled = await cubit.isBiometricEnabled();
    if (mounted) {
      setState(() => _hasBiometricEnabled = isEnabled);
      if (isEnabled) {
        final savedAccount = await cubit.getSavedAccount();
        if (savedAccount != null && savedAccount.isNotEmpty) {
          // محاولة استخراج رقم الهاتف والبادئة تلقائياً
          for (var c in CountryCodes.all) {
            if (savedAccount.startsWith(c.dialCode)) {
              setState(() {
                _selectedCountry = c;
                _phoneController.text = savedAccount.substring(c.dialCode.length);
              });
              break;
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onLogin() {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty) {
      _showError('يرجى إدخال رقم الحساب / الهاتف');
      return;
    }
    if (pin.length != 4) {
      _showError('يجب أن تتكون كلمة السر من 4 أرقام');
      return;
    }

    final fullAccountNumber = '${_selectedCountry.dialCode}$phone';
    context.read<AuthCubit>().loginWithCredentials(
      accountNumber: fullAccountNumber,
      pin4Digits: pin,
    );
  }

  void _onBiometricLogin() {
    context.read<AuthCubit>().extendSessionWithBiometrics();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _showEnableBiometricsDialog(UserAccountModel user, String pin) async {
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.fingerprint_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('تفعيل الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'هل تريد تفعيل البصمة لتسهيل عملية الدخول في المرات القادمة بدون الحاجة لإدخال كلمة السر؟',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ليس الآن', style: TextStyle(color: Colors.grey.shade600)),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('حفظ وتفعيل'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (enable == true && mounted) {
      await context.read<AuthCubit>().enableBiometrics(user: user, pin4Digits: pin);
      if (!mounted) return;
      setState(() => _hasBiometricEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل الدخول بالبصمة بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: Navigator.canPop(context)
            ? AppBar(
                title: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        body: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthSuccess) {
              if (state.isFirstLogin && _pinController.text.isNotEmpty) {
                await _showEnableBiometricsDialog(state.user, _pinController.text.trim());
              }
              if (!context.mounted) return;
              if (widget.onLoginSuccess != null) {
                widget.onLoginSuccess!();
              }
              if (Navigator.canPop(context)) {
                Navigator.pop(context, true);
              }
            } else if (state is AuthSessionExpired) {
              _fillUserData(state.user);
              setState(() => _hasBiometricEnabled = state.hasBiometric);
              if (state.hasBiometric && !_hasAutoPromptedBiometric) {
                _hasAutoPromptedBiometric = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _onBiometricLogin();
                  }
                });
              }
            } else if (state is AuthError) {
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // شعار التطبيق
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colorScheme.primary.withAlpha(50)),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 44,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'بوابة شبكتي للخدمات الرقمية',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state is AuthSessionExpired
                            ? 'يرجى تأكيد الهوية لتمديد صلاحية جلستك'
                            : 'سجّل دخولك لمتابعة اشتراكاتك ورصيدك الفوري',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),

                      if (state is AuthSessionExpired) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.lock_clock_rounded, color: Colors.amber.shade900, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'مرحباً بك، ${state.user.fullName}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      state.message ?? 'انتهت صلاحية الجلسة، يرجى تأكيد الدخول للمتابعة',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state.hasBiometric) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton.tonalIcon(
                              icon: const Icon(Icons.fingerprint_rounded, size: 24),
                              label: const Text(
                                'تمديد الجلسة والمتابعة بالبصمة',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: isLoading ? null : _onBiometricLogin,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: Divider(color: colorScheme.outlineVariant.withAlpha(120))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text('أو تسجيل الدخول بكلمة السر', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ),
                              Expanded(child: Divider(color: colorScheme.outlineVariant.withAlpha(120))),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // حقل رقم الهاتف (رقم الحساب) المنقسم مع قائمة البحث
                      PhoneInputField(
                        controller: _phoneController,
                        enabled: !isLoading,
                        initialCountry: _selectedCountry,
                        labelText: 'رقم الحساب (رقم الهاتف)',
                        onCountryChanged: (c) => setState(() => _selectedCountry = c),
                      ),
                      const SizedBox(height: 18),

                      // حقل كلمة السر (4 أرقام)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'كلمة السر (4 أرقام)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _pinController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.number,
                            obscureText: _obscurePin,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              hintText: '••••',
                              counterText: '',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                              ),
                              filled: true,
                              fillColor: theme.cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // زر تسجيل الدخول
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: isLoading ? null : _onLogin,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : const Text(
                                        'تسجيل الدخول',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ),
                          // زر البصمة إن كانت مفعلة
                          if (_hasBiometricEnabled) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: isLoading ? null : _onBiometricLogin,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colorScheme.primary.withAlpha(100)),
                                ),
                                child: Icon(
                                  Icons.fingerprint_rounded,
                                  size: 28,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (state is AuthSessionExpired) ...[
                        const SizedBox(height: 16),
                        TextButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          label: const Text(
                            'تسجيل الدخول بحساب آخر',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  _phoneController.clear();
                                  _pinController.clear();
                                  await context.read<AuthCubit>().switchUser();
                                  setState(() {
                                    _hasBiometricEnabled = false;
                                  });
                                },
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        // زر تسجيل حساب جديد
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final registered = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                                  );
                                  if (registered == true) {
                                    _checkBiometrics();
                                  }
                                },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              children: [
                                const TextSpan(text: 'لا يوجد لديك حساب؟ '),
                                TextSpan(
                                  text: 'تسجيل حساب جديد',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
