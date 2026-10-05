import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/services/whatsapp_launcher.dart';
import '../../data/models/user_account_model.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import '../../logic/cart/cart_cubit.dart';
import '../../logic/orders/orders_cubit.dart';
import 'auth/login_page.dart';
import 'onboarding_splash_page.dart';
import 'privacy_policy_page.dart';

class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({super.key});

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  bool _isBiometricEnabled = false;
  Duration? _remainingSessionTime;
  bool _isExtendingSession = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _loadSessionInfo();
  }

  Future<void> _checkBiometrics() async {
    final isEnabled = await context.read<AuthCubit>().isBiometricEnabled();
    if (mounted) {
      setState(() => _isBiometricEnabled = isEnabled);
    }
  }

  Future<void> _loadSessionInfo() async {
    final storage = context.read<SecureStorageService>();
    final remaining = await storage.getRemainingSessionTime();
    if (mounted) {
      setState(() {
        _remainingSessionTime = remaining;
      });
    }
  }

  String _formatRemainingTime(Duration? remaining) {
    if (remaining == null || remaining == Duration.zero) {
      return 'الجلسة نشطة ومؤمنة';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    if (hours > 0) {
      return 'صالحة لمدة $hours ساعة و $minutes دقيقة';
    } else {
      return 'صالحة لمدة $minutes دقيقة';
    }
  }

  Future<void> _handleExtendSession(AuthCubit cubit) async {
    setState(() => _isExtendingSession = true);
    try {
      final success = await cubit.extendSessionWithBiometrics();
      if (success && mounted) {
        await _loadSessionInfo();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تمديد صلاحية الجلسة بنجاح لمدة 4 ساعات إضافية!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtendingSession = false);
      }
    }
  }

  Future<String?> _showPinConfirmationDialog(BuildContext context) async {
    final pinController = TextEditingController();
    bool obscure = true;

    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.fingerprint_rounded, color: Theme.of(ctx).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('تفعيل الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أدخل كلمة سر حسابك (4 أرقام) للتأكيد وربط البصمة بأمان بجهازك:',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: obscure,
                    maxLength: 4,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    final pin = pinController.text.trim();
                    if (pin.length == 4) {
                      Navigator.pop(ctx, pin);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('يجب إدخال 4 أرقام لكلمة السر')),
                      );
                    }
                  },
                  child: const Text('متابعة لمسح البصمة'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleBiometricToggle(bool val, AuthCubit cubit, UserAccountModel user) async {
    if (val) {
      // 1. فحص دعم الجهاز
      final canCheck = await cubit.biometricService.isBiometricAvailable();
      if (!canCheck) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('جهازك لا يدعم المصادقة الحيوية أو لم يتم إعداد بصمة في إعدادات الهاتف'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 2. طلب إدخال رمز PIN للتأكيد
      if (!mounted) return;
      final pin = await _showPinConfirmationDialog(context);
      if (pin == null || pin.isEmpty) return;

      // 3. التحقق من صحة الـ PIN
      try {
        await cubit.authRepository.loginUser(
          accountNumber: user.accountNumber,
          pin4Digits: pin,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('كلمة المرور المدخلة غير صحيحة، تعذر تفعيل البصمة'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 4. طلب مسح البصمة الفعلي
      final authenticated = await cubit.biometricService.authenticateWithBiometrics(
        reason: 'المصادقة بالبصمة لتفعيل الدخول السريع',
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء عملية مسح البصمة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 5. حفظ وتفعيل البصمة محلياً وفي Supabase
      await cubit.enableBiometrics(user: user, pin4Digits: pin);
      if (mounted) {
        setState(() => _isBiometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل تسجيل الدخول بالبصمة بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // إلغاء تفعيل البصمة
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('إلغاء تفعيل البصمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: const Text(
            'هل أنت متأكد من رغبتك في إلغاء تسجيل الدخول بالبصمة؟ سيتوجب عليك إدخال كلمة السر عند الدخول.',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('تراجع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await cubit.disableBiometrics();
        if (mounted) {
          setState(() => _isBiometricEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إلغاء تفعيل البصمة بنجاح'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    }
  }

  Future<void> _showChangePasswordDialog(BuildContext context, AuthCubit cubit) async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMessage;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'تغيير كلمة المرور',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'يرجى إدخال كلمة المرور القديمة ثم إدخال كلمة المرور الجديدة المكونة من 4 أرقام وتأكيدها:',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    if (errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 1. كلمة المرور القديمة
                    const Text(
                      'كلمة المرور القديمة (4 أرقام)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: oldPinController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.number,
                      obscureText: obscureOld,
                      maxLength: 4,
                      autofocus: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                        ),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. كلمة المرور الجديدة
                    const Text(
                      'كلمة المرور الجديدة (4 أرقام)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: newPinController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.number,
                      obscureText: obscureNew,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. تأكيد كلمة المرور الجديدة
                    const Text(
                      'تأكيد كلمة المرور الجديدة (4 أرقام)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmPinController,
                      enabled: !isSubmitting,
                      keyboardType: TextInputType.number,
                      obscureText: obscureConfirm,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('حفظ كلمة المرور'),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final oldPin = oldPinController.text.trim();
                          final newPin = newPinController.text.trim();
                          final confirmPin = confirmPinController.text.trim();

                          if (oldPin.length != 4) {
                            setDialogState(() => errorMessage = 'يرجى إدخال كلمة المرور القديمة (4 أرقام)');
                            return;
                          }
                          if (newPin.length != 4) {
                            setDialogState(() => errorMessage = 'يرجى إدخال كلمة المرور الجديدة (4 أرقام)');
                            return;
                          }
                          if (confirmPin.length != 4 || newPin != confirmPin) {
                            setDialogState(() => errorMessage = 'كلمة المرور الجديدة وتأكيدها غير متطابقين');
                            return;
                          }
                          if (oldPin == newPin) {
                            setDialogState(() => errorMessage = 'كلمة المرور الجديدة يجب أن تختلف عن القديمة');
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            await cubit.changePassword(
                              oldPin4Digits: oldPin,
                              newPin4Digits: newPin,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                errorMessage = e.toString().replaceAll('Exception: ', '');
                              });
                            }
                          }
                        },
                ),
              ],
            ),
          );
        },
      ),
    );

    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmFinalLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              ),
              const SizedBox(width: 12),
              const Text('تسجيل الخروج النهائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من تسجيل الخروج النهائي ومسح كافة بيانات التطبيق من هذا الجهاز؟\n\n'
            '• سيتم مسح بيانات الجلسة الحالية بالكامل.\n'
            '• سيتم تفريغ السلة ومسح سجل الطلبات المعروضة محلياً.\n'
            '• لن تظهر بيانات أو طلبات هذا الحساب لأي مستخدم آخر على هذا الهاتف.\n'
            '• سيتعين عليك إدخال كلمة السر مجدداً عند الرغبة في الدخول.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              label: const Text('تأكيد ومسح البيانات'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final cubit = context.read<AuthCubit>();
      final ordersCubit = context.read<OrdersCubit>();
      final cartCubit = context.read<CartCubit>();

      await cubit.finalLogout();
      await ordersCubit.clearOrders();
      cartCubit.clearCart();

      if (mounted) {
        setState(() {
          _isBiometricEnabled = false;
          _remainingSessionTime = null;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الخروج النهائي ومسح كافة بيانات التطبيق بأمان'),
            backgroundColor: Colors.teal,
          ),
        );
      }
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
          title: const Text('حسابي وبيانات الدخول', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.power_settings_new_rounded, color: Colors.red),
              tooltip: 'تسجيل الخروج النهائي ومسح البيانات',
              onPressed: () => _confirmFinalLogout(context),
            ),
          ],
        ),
        body: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccess) {
              _checkBiometrics();
              _loadSessionInfo();
            }
          },
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();
            final user = cubit.currentUser;

            if (user == null) {
              return LoginPage(
                onLoginSuccess: () {
                  setState(() {});
                  _checkBiometrics();
                  _loadSessionInfo();
                },
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // بطاقة بيانات المستخدم الرئيسية
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'ش',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          user.accountNumber,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: user.region == 'A' ? Colors.blue.shade50 : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: user.region == 'A' ? Colors.blue.shade200 : Colors.teal.shade200,
                          ),
                        ),
                        child: Text(
                          'المنطقة: ${user.regionName} (النطاق ${user.region})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: user.region == 'A' ? Colors.blue.shade800 : Colors.teal.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // بطاقة حالة الجلسة وتمديدها بالبصمة
                const Text('حالة الجلسة والأمان', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield_outlined, color: Colors.green, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('الجلسة نشطة ومؤمنة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  _formatRemainingTime(_remainingSessionTime),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_isBiometricEnabled) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: _isExtendingSession
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.fingerprint_rounded, size: 20),
                            label: const Text('تمديد الجلسة بالبصمة (+4 ساعات)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isExtendingSession ? null : () => _handleExtendSession(cubit),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // قسم إعدادات الأمان والبصمة
                const Text(
                  'الأمان والمصادقة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.fingerprint_rounded, color: colorScheme.primary, size: 22),
                        ),
                        title: const Text('تسجيل الدخول بالبصمة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('تفعيل المصادقة الحيوية للدخول السريع وتمديد الجلسة', style: TextStyle(fontSize: 11)),
                        value: _isBiometricEnabled,
                        onChanged: (val) => _handleBiometricToggle(val, cubit, user),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.lock_reset_rounded, color: colorScheme.primary, size: 22),
                        ),
                        title: const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('تحديث كلمة السر الخاصة بحسابك (4 أرقام)', style: TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => _showChangePasswordDialog(context, cubit),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // قسم المساعدة والدعم والخصوصية
                const Text('المساعدة والخصوصية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 22),
                        ),
                        title: const Text('دليل ومميزات بوابة شبكتي (السبلاش)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('الاشتراكات، الدفع المباشر، والتسليم الفوري', style: TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OnboardingSplashPage(isReviewMode: true)),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.privacy_tip_outlined, color: colorScheme.primary, size: 22),
                        ),
                        title: const Text('سياسة الخصوصية وشروط الاستخدام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('حماية البيانات، الصلاحيات، وحقوق المستخدم', style: TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366).withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.support_agent_rounded, color: Color(0xFF25D366), size: 22),
                        ),
                        title: const Text('الدعم الفني عبر واتساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: const Text('خدمة العملاء والدردشة المباشرة (967737241475+)', style: TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => WhatsAppLauncher.openSupportChat(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // زر تسجيل خروج عادي (في الأعلى)
                OutlinedButton.icon(
                  icon: Icon(Icons.logout_rounded, color: Colors.grey.shade700, size: 18),
                  label: Text(
                    'تسجيل خروج عادي',
                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await cubit.logout();
                    if (context.mounted) {
                      context.read<OrdersCubit>().clearOrders();
                      context.read<CartCubit>().clearCart();
                    }
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),

                // زر تسجيل الخروج النهائي ومسح كافة بيانات التطبيق (في الأسفل)
                FilledButton.icon(
                  icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'تسجيل الخروج النهائي ومسح بيانات التطبيق',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _confirmFinalLogout(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
