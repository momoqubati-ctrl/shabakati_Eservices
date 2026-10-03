import 'package:flutter/material.dart';
import '../../core/services/whatsapp_launcher.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'سياسة الخصوصية وشروط الاستخدام',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ترويسة السياسة
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withAlpha(210),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(40),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.privacy_tip_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بوابة شبكتي للخدمات الرقمية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'التزام كامل بحماية بياناتك وخصوصيتك وفق معايير الأمان العالمية',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'معتمدة ومتوافقة مع متطلبات متاجر التطبيقات الرسمية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _buildPolicySection(
              context: context,
              icon: Icons.info_outline_rounded,
              title: '1. مقدمة عامة',
              content:
                  'توضح سياسة الخصوصية هذه كيفية قيام تطبيق "بوابة شبكتي للخدمات الرقمية" بجمع، استخدام، ومعالجة وحماية البيانات الشخصية لمستخدمي التطبيق عند التسجيل أو شراء البطاقات والاشتراكات الرقمية.\n'
                  'إن استخدامك للتطبيق أو تسجيلك لحساب جديد يعني موافقتك الواضحة على البنود الواردة في هذه السياسة.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.folder_shared_outlined,
              title: '2. البيانات التي نقوم بجمعها',
              content:
                  'نقتصر على جمع الحد الأدنى من البيانات الضرورية لتقديم الخدمة بأمان وموثوقية، وتشمل:\n'
                  '• بيانات الحساب والهوية: الاسم الكامل، رقم الهاتف (رقم الحساب)، والمنطقة الجغرافية المختارة (النطاق A أو B) لتخصيص الخدمات والباقات المتوفرة في منطقتك.\n'
                  '• بيانات المصادقة والأمان: كلمة المرور المكونة من 4 أرقام (يتم تشفيرها خادمياً بخوارزمية التشفير الأحادي bcrypt ولا تُحفظ كنص صريح أبداً)، ورموز التحقق المؤقتة (OTP).\n'
                  '• بيانات الطلبات والمدفوعات: سجل المشتريات، الأكواد الرقمية المستلمة، حالة الطلب، طريقة الدفع، اسم المحفظة الإلكترونية، ورقم مرجع عملية الدفع.\n'
                  '• المعرّفات التقنية: معرّف تقني محلي للجهاز (Device ID) يُستخدم حصرياً لأغراض الأمان، حماية الجلسة، وربط حالة الطلبات.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.fingerprint_rounded,
              title: '3. صلاحيات الجهاز والمصادقة الحيوية (البصمة)',
              content:
                  'يحترم التطبيق خصوصية جهازك ولا يطلب الوصول إلى جهات الاتصال أو الكاميرا أو الموقع الجغرافي الدقيق (GPS) أو الملفات الشخصية:\n'
                  '• الاتصال بالإنترنت: لعرض كتالوج المنتجات الفوري، تنفيذ الطلبات، والتحقق من عمليات الدفع.\n'
                  '• المصادقة الحيوية (البصمة / الوجه): ميزة اختيارية تتيح لك تسجيل الدخول السريع أو تمديد صلاحية الجلسة. تتم عملية التحقق من البصمة محلياً بالكامل عبر النظام الأمني لهاتفك، ولا يطلع التطبيق على بياناتك الحيوية ولا يتم إرسالها أو تخزينها في خوادمنا مطلقاً.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.settings_suggest_outlined,
              title: '4. كيف نستخدم بياناتك؟',
              content:
                  'تُستخدم البيانات التي يتم جمعها للأغراض التشغيلية التالية فقط:\n'
                  '• إنشاء حسابك وتوثيق ملكية رقم الهاتف عبر رسائل التحقق (SMS أو WhatsApp).\n'
                  '• معالجة طلبات شراء البطاقات والاشتراكات الرقمية وتسليم الأكواد الفورية لحسابك.\n'
                  '• التحقق الخادمي من عمليات الدفع الإلكتروني ومطابقة المبالغ لمنع الاحتيال أو الازدواجية.\n'
                  '• تقديم الدعم الفني وخدمة العملاء ومتابعة الطلبات المعلقة.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              title: '5. أمان المدفوعات والأطراف الثالثة',
              content:
                  '• نحن لا نبيع ولا نؤجر ولا نشارك بياناتك الشخصية مع أي جهات تسويقية أو إعلانية تحت أي ظرف.\n'
                  '• تتم عمليات الدفع عبر المحافظ الإلكترونية من خلال بوابة الدفع المعتمدة والمشفرة (BasGate)؛ لا يقوم تطبيقنا بجمع أو تخزين كلمات المرور الخاصة بمحفظتك الإلكترونية.\n'
                  '• تتم مشاركة رقم الهاتف فقط مع بوابة إرسال رسائل التحقق (OTP) عند تسجيل الحساب أو استعادة كلمة المرور.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.shield_outlined,
              title: '6. أمن المعلومات والتخزين المشفر',
              content:
                  '• تشفير النقل والتخزين: جميع الاتصالات بين التطبيق والخوادم مشفرة بالكامل عبر بروتوكول (HTTPS / TLS).\n'
                  '• التخزين المحلي الآمن: يتم حفظ بيانات الجلسة والأكواد الرقمية المستلمة على جهازك داخل مساحة تخزين مشفرة ومحمية بنظام التشغيل (Encrypted Secure Storage).\n'
                  '• الحماية من الاختراق: يطبق النظام آلية قفل مؤقت للحساب ورموز التحقق عند تكرار المحاولات الخاطئة لحماية حسابك من هجمات التخمين.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.manage_accounts_outlined,
              title: '7. حقوق المستخدم وحذف الحساب والبيانات',
              content:
                  'نمنحك التحكم الكامل في بياناتك وحسابك:\n'
                  '• تعديل البيانات: يمكنك تغيير كلمة المرور وإدارة خيارات الدخول بالبصمة في أي وقت من صفحة "حسابي وبيانات الدخول".\n'
                  '• مسح البيانات المحلية: يمكنك عبر زر "تسجيل الخروج النهائي ومسح بيانات التطبيق" في إعدادات الحساب حذف كافة البيانات والأكواد والجلسة المحفوظة على جهازك فوراً.\n'
                  '• حذف الحساب نهائياً: يحق لك في أي وقت طلب الحذف النهائي لحسابك وبياناتك الشخصية من خوادمنا بالتواصل مع الدعم الفني عبر الزر أدناه، وسيتم تنفيذ طلب الحذف خلال مدة أقصاها 7 أيام عمل.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.child_care_rounded,
              title: '8. خصوصية القُصّر والأطفال',
              content:
                  'خدمات التطبيق موجهة للأفراد المؤهلين لإجراء المعاملات المالية الإلكترونية عبر المحافظ المعتمدة، ولا نجمع عن قصد أي بيانات شخصية من الأطفال دون سن 13 عاماً.',
            ),

            const SizedBox(height: 8),

            // بطاقة التواصل وطلب حذف الحساب أو الاستفسار
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.primary.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent_rounded, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'التواصل بخصوص الخصوصية أو طلب حذف الحساب',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'إذا كان لديك أي استفسار حول سياسة الخصوصية، أو كنت ترغب في تقديم طلب رسمي لحذف حسابك وبياناتك الشخصية، يسعدنا تواصلك المباشر مع فريق الدعم الفني:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 20),
                      label: const Text(
                        'التواصل مع الدعم الفني عبر واتساب',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: colorScheme.primary.withAlpha(120)),
                      ),
                      onPressed: () => WhatsAppLauncher.openSupportChat(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                'آخر تحديث لسياسة الخصوصية: أكتوبر 2026',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.65,
              color: theme.textTheme.bodyMedium?.color?.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }
}
