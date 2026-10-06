# تقرير فحص أمني قبل الإطلاق

**التاريخ:** 2026-10-07  
**النطاق:** تطبيق Flutter، واجهات Vercel Serverless داخل `api/`، لوحة الإدارة React، وإعدادات Supabase الموجودة في المستودع.

## القرار الحالي

**الحالة:** مشروط قبل الإطلاق.

تم إغلاق خللين مؤثرين في الكود الحالي. الفحوصات المحلية الأساسية اجتازت الاختبارات، لكن قرار `READY_FOR_PRODUCTION` النهائي يجب أن يصدر بعد نشر التعديلات وتشغيل الفحص الأمني الحي على بيئة الإنتاج.

## ما تم إصلاحه

### 1. إزالة مفتاح خدمة احتياطي من الكود

كان `api/_lib/serverSecrets.js` يحتوي منطقاً يشتق مفتاح خدمة و`handshake` احتياطيين عند غياب متغيرات البيئة. هذا قد يجعل الخادم يعتمد على مادة سرية موجودة داخل الكود بدلاً من الاعتماد فقط على Vercel Environment Variables.

**الإصلاح:** أصبح `getServerSecrets()` يعتمد فقط على:

- `SUPABASE_SERVICE_ROLE_KEY` أو `SUPABASE_SERVICE_KEY`
- `SERVER_HANDSHAKE_KEY`

وعند غيابها يرجع `{}` ولا يحاول تكوين أسرار من الكود.

### 2. إغلاق BOLA/IDOR في مسار طلبات المستخدم

كان مسار `GET /api/orders?action=user_orders` يتحقق من `user_id` و`account_number` فقط عبر `service_role`. هذه القيم ليست كافية كإثبات جلسة، وقد تسمح بجلب طلبات مستخدم آخر إذا عُرفت البيانات.

**الإصلاح:** أصبح المسار يتطلب `session_token` ويطابقه مع سجل `app_users` قبل إرجاع الطلبات. كما تم تحديث تطبيق Flutter لإرسال `session_token` عند استخدام fallback عبر بوابة Vercel.

## نتائج التحقق

- `node --test api\_lib\*.test.js`: نجح محلياً، `7/7`.
- `npm.cmd run lint` داخل `admin_dashboard`: نجح مع تحذيرات موجودة مسبقاً، أغلبها `unused vars` وReact hook warnings.
- فحص الأسرار الثابت بعد التعديل: لا يظهر منطق `deriveBootstrap` أو `handshake` احتياطي داخل `api/`.
- `flutter analyze`: حسب نتيجة التشغيل التي تم تزويدي بها، نجح بـ `No issues found! (ran in 91.8s)`. في جلسة الأدوات الحالية لدي تعطل الأمر بالمهلة، لذلك أعتمد هذه النقطة كتحقق منفصل من طرفك لا كتشغيل ناجح داخل جلستي.

## نقاط يجب تنفيذها قبل الإطلاق

1. نشر التعديلات على Vercel والتأكد أن متغيرات البيئة الإنتاجية مضبوطة:
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SERVER_HANDSHAKE_KEY`
   - `DIGITAL_VAULT_KEY_ID`
   - `DIGITAL_VAULT_API_SECRET`
   - `BASGATE_LIVE_CLIENT_SECRET`
   - `BASGATE_LIVE_MKEY`
   - `WHATSAPP_TOKEN`

2. تشغيل فحوصات `security_audit/run_all_audits.py` على بيئة الإنتاج بعد النشر.

3. اختبار مسارات الدفع فعلياً بعد النشر:
   - BasGate initiate
   - BasGate verify
   - BasGate webhook
   - OTP / password reset
   - `GET /api/orders?action=user_orders`

4. اعتبار التقارير السابقة بتاريخ 2026-10-04 غير كافية وحدها، لأن الكود الحالي كان يحتوي تغييرات لاحقة تم إصلاحها في هذا الفحص.

## الخلاصة

الكود أصبح أفضل أمنياً بعد إغلاق المسارين أعلاه، لكن الإطلاق المباشر يجب أن ينتظر تحقق الإنتاج الحي، خصوصاً لمسارات الدفع وOTP وصلاحيات Supabase RLS و`service_role`.
