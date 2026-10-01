import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/telegram_launcher.dart';
import '../../logic/auth/auth_cubit.dart';
import '../../logic/auth/auth_state.dart';
import 'auth/login_page.dart';

class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({super.key});

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final isEnabled = await context.read<AuthCubit>().isBiometricEnabled();
    if (mounted) {
      setState(() => _isBiometricEnabled = isEnabled);
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
        ),
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final cubit = context.read<AuthCubit>();
            final user = cubit.currentUser;

            if (user == null) {
              return LoginPage(
                onLoginSuccess: () {
                  setState(() {});
                  _checkBiometrics();
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
                        subtitle: const Text('تفعيل المصادقة الحيوية للدخول السريع', style: TextStyle(fontSize: 11)),
                        value: _isBiometricEnabled,
                        onChanged: (val) async {
                          if (val) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('يتم تفعيل البصمة تلقائياً عند تسجيل الدخول برقمك السري')),
                            );
                          } else {
                            await cubit.biometricService.setBiometricEnabled(enabled: false);
                            setState(() => _isBiometricEnabled = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // قسم المساعدة والدعم
                const Text('المساعدة والدعم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF229ED9)),
                    title: const Text('الدعم الفني عبر تيليجرام (@sahm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: const Text('خدمة العملاء على مدار الساعة', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => TelegramLauncher.openBotChat(),
                  ),
                ),
                const SizedBox(height: 32),

                // زر تسجيل الخروج
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await cubit.logout();
                    setState(() {});
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
