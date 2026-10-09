import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/country_codes.dart';
import '../../../core/utils/error_sanitizer.dart';
import '../../../logic/auth/auth_cubit.dart';
import '../../../logic/auth/auth_state.dart';
import '../../widgets/phone_input_field.dart';
import '../privacy_policy_page.dart';
import 'otp_verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  CountryCodeModel _selectedCountry = CountryCodes.defaultCountry;
  String _selectedRegion = 'A'; // A: صنعاء, B: عدن
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _agreedToPrivacyPolicy = false;
  bool _isNavigatingToOtp = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    var phone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (name.isEmpty) {
      _showError('يرجى كتابة الاسم الكامل');
      return;
    }
    if (phone.isEmpty) {
      _showError('يرجى إدخال رقم الهاتف');
      return;
    }
    if (pin.length != 4) {
      _showError('يجب أن تتكون كلمة السر من 4 أرقام');
      return;
    }
    if (pin != confirmPin) {
      _showError('كلمة السر وتأكيدها غير متطابقين');
      return;
    }
    if (!_agreedToPrivacyPolicy) {
      _showError('يرجى الموافقة على سياسة الخصوصية وشروط الاستخدام للمتابعة');
      return;
    }

    context.read<AuthCubit>().registerUser(
      dialCode: _selectedCountry.dialCode,
      phoneNational: phone,
      fullName: name,
      region: _selectedRegion,
      pin4Digits: pin,
    );
  }

  void _showError(String message) {
    final safeMessage = ErrorSanitizer.sanitize(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(safeMessage), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسجيل حساب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) async {
            if (state is AuthOtpRequired && !_isNavigatingToOtp) {
              _isNavigatingToOtp = true;
              final verified = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => OtpVerificationPage(
                    user: state.user,
                    phoneWithCode: state.phoneWithCode,
                    initialChannel: state.channel,
                  ),
                ),
              );
              _isNavigatingToOtp = false;

              if (verified == true && context.mounted) {
                Navigator.pop(context, true); // إغلاق شاشة التسجيل بنجاح
              }
            } else if (state is AuthError) {
              _showError(state.message);
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // عنوان الشاشة
                    Text(
                      'أهلاً بك معنا!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أنشئ حسابك للوصول المباشر لكافة الخدمات والتسليم الفوري',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),

                    // حقل الاسم
                    const Text('الاسم الكامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: 'مثال: محمد علي أحمد',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
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
                    const SizedBox(height: 18),

                    // حقل رقم الحساب / الهاتف المنقسم
                    PhoneInputField(
                      controller: _phoneController,
                      enabled: !isLoading,
                      initialCountry: _selectedCountry,
                      onCountryChanged: (c) => setState(() => _selectedCountry = c),
                    ),
                    const SizedBox(height: 18),

                    // حقل المنطقة (صنعاء A، عدن B)
                    const Text('المنطقة / المحافظة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isLoading ? null : () => setState(() => _selectedRegion = 'A'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _selectedRegion == 'A'
                                    ? colorScheme.primary.withAlpha(20)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedRegion == 'A'
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant.withAlpha(120),
                                  width: _selectedRegion == 'A' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedRegion == 'A'
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: _selectedRegion == 'A' ? colorScheme.primary : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'صنعاء',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _selectedRegion == 'A' ? colorScheme.primary : null,
                                          ),
                                        ),
                                        Text(
                                          'النطاق (A)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: isLoading ? null : () => setState(() => _selectedRegion = 'B'),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _selectedRegion == 'B'
                                    ? colorScheme.primary.withAlpha(20)
                                    : theme.cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _selectedRegion == 'B'
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant.withAlpha(120),
                                  width: _selectedRegion == 'B' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedRegion == 'B'
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: _selectedRegion == 'B' ? colorScheme.primary : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'عدن',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _selectedRegion == 'B' ? colorScheme.primary : null,
                                          ),
                                        ),
                                        Text(
                                          'النطاق (B)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // حقل كلمة السر (4 أرقام)
                    const Text('كلمة السر (4 أرقام فقط)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                    const SizedBox(height: 18),

                    // حقل تأكيد كلمة السر (4 أرقام)
                    const Text('تأكيد كلمة السر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPinController,
                      enabled: !isLoading,
                      keyboardType: TextInputType.number,
                      obscureText: _obscureConfirmPin,
                      maxLength: 4,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '••••',
                        counterText: '',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPin ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
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
                    const SizedBox(height: 18),

                    // خيار الموافقة على سياسة الخصوصية وشروط الاستخدام
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _agreedToPrivacyPolicy
                            ? colorScheme.primary.withAlpha(15)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _agreedToPrivacyPolicy
                              ? colorScheme.primary.withAlpha(120)
                              : colorScheme.outlineVariant.withAlpha(120),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToPrivacyPolicy,
                              onChanged: isLoading
                                  ? null
                                  : (val) => setState(() => _agreedToPrivacyPolicy = val ?? false),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: isLoading
                                      ? null
                                      : () => setState(() => _agreedToPrivacyPolicy = !_agreedToPrivacyPolicy),
                                  child: const Text(
                                    'قرأت وأوافق على ',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      'سياسة الخصوصية وشروط الاستخدام',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'قراءة سياسة الخصوصية',
                            icon: Icon(Icons.privacy_tip_outlined, size: 20, color: colorScheme.primary),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // زر تسجيل الحساب
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: isLoading ? null : _onRegister,
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
                                'تسجيل الحساب وإرسال الرمز',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // زر الانتقال لتسجيل الدخول
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            children: [
                              const TextSpan(text: 'لديك حساب بالفعل؟ '),
                              TextSpan(
                                text: 'تسجيل الدخول',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
