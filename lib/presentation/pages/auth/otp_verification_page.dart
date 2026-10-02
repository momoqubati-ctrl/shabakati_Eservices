import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_account_model.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/auth/auth_state.dart';

class OtpVerificationPage extends StatefulWidget {
  final UserAccountModel user;
  final String phoneWithCode;
  final String initialChannel;

  const OtpVerificationPage({
    super.key,
    required this.user,
    required this.phoneWithCode,
    this.initialChannel = 'whatsapp',
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isSending = false;
  bool _hasError = false;
  String _activeChannel = 'whatsapp';

  @override
  void initState() {
    super.initState();
    _activeChannel = widget.initialChannel;
    _startCountdown();

    for (int i = 0; i < 4; i++) {
      _focusNodes[i].addListener(() {
        if (mounted) setState(() {});
      });
    }

    // التركيز التلقائي على الخلية الأولى (اليسار) عند فتح الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() {
          _canResend = true;
          _timer?.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode => _otpControllers.map((c) => c.text).join();

  int get _firstEmptyIndex {
    for (int i = 0; i < 4; i++) {
      if (_otpControllers[i].text.isEmpty) return i;
    }
    return 3;
  }

  void _submitOtp() {
    final code = _enteredCode;
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رمز التحقق كاملاً المكون من 4 أرقام')),
      );
      return;
    }

    context.read<AuthCubit>().verifyOtp(
      phoneWithCode: widget.phoneWithCode,
      enteredOtp: code,
      user: widget.user,
    );
  }

  Future<void> _resendVia(String channel) async {
    setState(() {
      _isSending = true;
      _activeChannel = channel;
      _hasError = false;
    });

    await context.read<AuthCubit>().resendOtp(
      phoneWithCode: widget.phoneWithCode,
      channel: channel,
    );

    setState(() => _isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            channel == 'whatsapp'
                ? 'تم إرسال رمز التحقق الجديد عبر واتساب'
                : 'تم إرسال رمز التحقق الجديد عبر رسالة نصية SMS',
          ),
          backgroundColor: channel == 'whatsapp' ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      );
      _startCountdown();
      for (var c in _otpControllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تأكيد رقم الهاتف', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccess) {
              Navigator.pop(context, true);
            } else if (state is AuthError) {
              setState(() {
                _hasError = true;
              });
              // تفريغ الحقول وإعادة التركيز للخلية الأولى (اليسار)
              for (var c in _otpControllers) {
                c.clear();
              }
              _focusNodes[0].requestFocus();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(child: Text(state.message)),
                    ],
                  ),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading || _isSending;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // أيقونة بارزة ومميزة
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha(120),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(30),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _activeChannel == 'whatsapp' ? Icons.chat_rounded : Icons.sms_rounded,
                        size: 44,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'رمز التحقق السريع (OTP)',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                      children: [
                        TextSpan(
                          text: _activeChannel == 'whatsapp'
                              ? 'تم إرسال رمز مكون من 4 أرقام عبر تطبيق واتساب إلى رقمك:\n'
                              : 'تم إرسال رمز التحقق عبر رسالة SMS إلى رقمك:\n',
                        ),
                        TextSpan(
                          text: widget.phoneWithCode,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // إشارة واضحة للمستخدم بأن الإدخال يبدأ من اليسار إلى اليمين
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.primary.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_forward_rounded, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'يبدأ إدخال الأرقام من اليسار إلى اليمين (الخلية الملونة)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // مربعات إدخال الـ OTP الأربعة - موجهة إجبارياً من اليسار إلى اليمين (LTR)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFocused = _focusNodes[index].hasFocus;
                        final isFilled = _otpControllers[index].text.isNotEmpty;
                        final hasAnyFocus = _focusNodes.any((f) => f.hasFocus);
                        // إذا لم يكن أي حقل مركز عليه، تكون الخلية الأولى الفارغة هي المستهدفة
                        final isTarget = isFocused || (!hasAnyFocus && _firstEmptyIndex == index);

                        Color cellBgColor;
                        Color cellBorderColor;
                        double cellBorderWidth;

                        if (_hasError) {
                          cellBgColor = Colors.red.withAlpha(20);
                          cellBorderColor = Colors.red.shade600;
                          cellBorderWidth = isFocused ? 2.5 : 1.5;
                        } else if (isTarget) {
                          // تمييز الخلية المستهدفة أو التي يتم ملؤها بلون مختلف تماماً وواضح
                          cellBgColor = colorScheme.primary.withAlpha(35);
                          cellBorderColor = colorScheme.primary;
                          cellBorderWidth = 2.4;
                        } else if (isFilled) {
                          cellBgColor = theme.cardColor;
                          cellBorderColor = colorScheme.primary.withAlpha(140);
                          cellBorderWidth = 1.6;
                        } else {
                          cellBgColor = theme.cardColor;
                          cellBorderColor = colorScheme.outlineVariant.withAlpha(100);
                          cellBorderWidth = 1.2;
                        }

                        return Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                              if (_otpControllers[index].text.isEmpty && index > 0) {
                                _otpControllers[index - 1].clear();
                                _focusNodes[index - 1].requestFocus();
                                setState(() {});
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 7),
                                width: 62,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: cellBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cellBorderColor,
                                    width: cellBorderWidth,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isTarget
                                          ? (_hasError ? Colors.red.withAlpha(40) : colorScheme.primary.withAlpha(45))
                                          : Colors.black.withAlpha(8),
                                      blurRadius: isTarget ? 10 : 4,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: TextField(
                                    controller: _otpControllers[index],
                                    focusNode: _focusNodes[index],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    maxLength: 1,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _hasError ? Colors.red.shade700 : colorScheme.primary,
                                    ),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (val) {
                                      if (_hasError) {
                                        setState(() => _hasError = false);
                                      }

                                      // دعم اللصق المباشر لكامل الكود المكون من 4 أرقام
                                      if (val.length > 1) {
                                        final digits = val.replaceAll(RegExp(r'\D'), '');
                                        for (int i = 0; i < 4 && i < digits.length; i++) {
                                          _otpControllers[i].text = digits[i];
                                        }
                                        if (digits.length >= 4) {
                                          _focusNodes[3].unfocus();
                                          _submitOtp();
                                        } else {
                                          _focusNodes[digits.length].requestFocus();
                                        }
                                        setState(() {});
                                        return;
                                      }

                                      if (val.isNotEmpty) {
                                        if (index < 3) {
                                          _focusNodes[index + 1].requestFocus();
                                        } else {
                                          _focusNodes[index].unfocus();
                                          _submitOtp();
                                        }
                                      } else {
                                        if (index > 0) {
                                          _focusNodes[index - 1].requestFocus();
                                        }
                                      }
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // مؤشر نقطي يوضح الخلية النشطة حالياً
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: isTarget ? 20 : 6,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isTarget
                                      ? (_hasError ? Colors.red : colorScheme.primary)
                                      : (isFilled ? colorScheme.primary.withAlpha(100) : Colors.transparent),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // زر تأكيد الرمز
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: isLoading ? null : _submitOtp,
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
                              'تأكيد ومتابعة الحساب',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // العداد التنازلي وزر إعادة الإرسال
                  if (!_canResend) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'إعادة إرسال الرمز بعد: $_secondsRemaining ثانية',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'إعادة إرسال الرمز عبر واتساب',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: isLoading ? null : () => _resendVia('whatsapp'),
                    ),
                  ],

                  const SizedBox(height: 12),
                  const Divider(indent: 40, endIndent: 40),
                  const SizedBox(height: 10),

                  // زر خيار SMS البديل
                  OutlinedButton.icon(
                    icon: const Icon(Icons.message_outlined, size: 18),
                    label: const Text(
                      'لم تستلم الرمز؟ الإرسال عبر SMS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isLoading ? null : () => _resendVia('sms'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
