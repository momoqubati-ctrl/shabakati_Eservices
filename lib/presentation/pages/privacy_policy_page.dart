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
                              'شبكتي للخدمات الإلكترونية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'وثيقة الخصوصية وضوابط استخدام الخدمة',
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
                          'خصوصية بياناتك أمانة نلتزم بحمايتها',
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
              icon: Icons.menu_book_rounded,
              title: 'أولاً: تمهيد',
              content:
                  'أهلاً بك في تطبيق "شبكتي". تحكم هذه الوثيقة العلاقة القانونية بين التطبيق ومستخدميه، وتوضح بأسلوب مباشر وشفاف طبيعة المعلومات التي نحتاج إليها لتشغيل حسابك وتنفيذ طلباتك، وكيف نحافظ على سريتها.\n'
                  'بدخولك إلى التطبيق أو إنشائك لحساب فيه، فإنك تقرّ باطلاعك على هذه البنود وموافقتك على العمل بموجبها.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.folder_shared_outlined,
              title: 'ثانياً: المعلومات التي نطلبها ولماذا نحتاج إليها؟',
              content:
                  'نحن لا نطلب إلا البيانات الأساسية التي لا يمكن تقديم الخدمة بدونها، وهي:\n'
                  '1. بيانات التسجيل: وتشمل الاسم ورقم الهاتف لتعريف حسابك، وتوثيقه عبر رمز التحقق، وتمكينك من استعادة حسابك عند الحاجة، بالإضافة إلى تحديد نطاق الخدمة لعرض الباقات المتاحة في منطقتك.\n'
                  '2. سجل العمليات والطلبات: عند شرائك لأي بطاقة أو اشتراك رقمي، يحتفظ النظام بتفاصيل العملية (نوع الخدمة، قيمتها، تاريخ الشراء، الكود المسلّم، ورقم مرجع السداد واسم المحفظة) لضمان حقك المالي والرجوع إليها في أي وقت من قائمة "طلباتي" أو عند مراجعة خدمة العملاء.\n'
                  '3. بيانات الحماية: يتم حفظ رمز الدخول الخاص بك بطريقة مشفرة لا يمكن لأي طرف — بما في ذلك موظفو الدعم الفني — الاطلاع عليها، كما يُستخدم معرّف تقني للجهاز لتأمين جلستك ومنع الدخول غير المصرح به.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'ثالثاً: الدفع الإلكتروني والمحافظ المالية',
              content:
                  'تُنفذ جميع عمليات السداد داخل التطبيق عبر بوابات الدفع والمحافظ الإلكترونية المحلية المعتمدة.\n'
                  'لا يطّلع تطبيق "شبكتي" إطلاقاً على الأرقام السرية لمحفظتك المالية ولا يحتفظ ببياناتها، إذ تتم عملية الخصم والتحقق مباشرة داخل البيئة المؤمّنة لمزود خدمة الدفع، ويقتصر ما يصل إلى نظامنا على إشعار نجاح العملية ورقم السند المرجعي لإتمام تسليم طلبك.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.fingerprint_rounded,
              title: 'رابعاً: صلاحيات الهاتف والدخول بالبصمة',
              content:
                  'لا يطلب التطبيق أي صلاحيات للوصول إلى صورك أو ملفاتك أو قائمة جهات الاتصال أو موقعك الجغرافي.\n'
                  'وفي حال تفعيلك لميزة الدخول بالبصمة أو التعرف على الوجه، فإن عملية التحقق تتم كلياً داخل نظام تشغيل هاتفك، ولا يقوم التطبيق بقراءة بصمتك أو نقلها أو تخزينها على أي خادم خارجي.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.lock_outline_rounded,
              title: 'خامساً: سرية البيانات وعدم مشاركتها',
              content:
                  'تُعامل بيانات جميع المشتركين بوصفها معلومات سرية؛ فلا يتم بيعها أو تأجيرها أو إتاحتها لأي جهة إعلانية أو تجارية.\n'
                  'ولا يتم تبادل أي معلومة خارج نطاق التطبيق إلا بالقدر اللازم تقنياً لتنفيذ الخدمة التي طلبتها بنفسك (مثل إرسال رمز التفعيل إلى رقم هاتفك، أو تأكيد حالة السداد مع بوابة الدفع).',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.verified_outlined,
              title: 'سادساً: ضوابط تسليم الاشتراكات والأكواد الرقمية',
              content:
                  'نظراً للطبيعة الفورية للبطاقات والأكواد الرقمية، يُعدّ الكود مسلّماً بمجرد ظهوره في صفحة "طلباتي" داخل حسابك، وتنتقل مسؤولية المحافظة على سريته وعدم مشاركته مع الغير إلى المشترك فور استلامه.\n'
                  'وفي حال تعذر التسليم الآلي لأي سبب تقني، يبقى الطلب محفوظاً في سجل حسابك لحين معالجته من قِبل فريق العمليات أو إعادة قيمته وفق الإجراءات المتبعة.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.manage_accounts_outlined,
              title: 'سابعاً: إدارة الحساب وحق الحذف النهائي',
              content:
                  'يملك المشترك كامل الحق في إدارة حسابه وبياناته في أي وقت:\n'
                  '• يمكنك تغيير رمز الدخول أو إيقاف ميزة البصمة مباشرة من إعدادات الحساب.\n'
                  '• يمكنك مسح جميع البيانات المحفوظة على هاتفك فوراً عبر خيار "تسجيل الخروج النهائي ومسح بيانات التطبيق".\n'
                  '• في حال رغبتك في إغلاق حسابك وشطب بياناتك نهائياً من سجلاتنا النشطة، يمكنك تقديم طلب مباشر لفريق خدمة العملاء عبر الوسيلة الموضحة أدناه، ليتم التحقق من هويتك وتنفيذ الحذف خلال مدة لا تتجاوز سبعة أيام عمل.',
            ),

            _buildPolicySection(
              context: context,
              icon: Icons.person_outline_rounded,
              title: 'ثامناً: الأهلية للاستخدام',
              content:
                  'خُصصت خدمات هذا التطبيق للأفراد المؤهلين للتعامل عبر المحافظ المالية الإلكترونية المعتمدة، ولا نوجّه خدماتنا أو نجمع بيانات بشكل مقصود لمن هم دون السن القانوني للتعامل المالي.',
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
                          'خدمة العملاء واستفسارات الخصوصية',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لأي استفسار يتعلق بهذه الوثيقة، أو لطلب إغلاق الحساب وحذف البيانات المرتبطة به، يمكنك مراسلة فريق خدمة العملاء مباشرة:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 20),
                      label: const Text(
                        'مراسلة خدمة العملاء عبر واتساب',
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
                'جميع الحقوق محفوظة © شبكتي للخدمات الإلكترونية',
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
