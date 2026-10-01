import 'package:flutter/material.dart';

class CheckoutWarningDialog extends StatefulWidget {
  final double totalAmount;
  final String currency;
  final String? displayYer;
  final int itemsCount;
  final String? initialTelegramUser;
  final String? initialPhone;
  final Function(String telegramUser, String phone, String paymentMethod) onConfirm;
  final Function(String telegramUser, String phone)? onPayWithBasGate;

  const CheckoutWarningDialog({
    super.key,
    required this.totalAmount,
    required this.currency,
    this.displayYer,
    required this.itemsCount,
    this.initialTelegramUser,
    this.initialPhone,
    required this.onConfirm,
    this.onPayWithBasGate,
  });

  @override
  State<CheckoutWarningDialog> createState() => _CheckoutWarningDialogState();
}

class _CheckoutWarningDialogState extends State<CheckoutWarningDialog> {
  late final TextEditingController _phoneController;
  String _selectedPaymentMethod = 'بطاقة بنكية / ميزة / فيزا';
  bool _acceptedTerms = true;
  bool _showOtherPaymentMethods = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // العنوان
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.payment_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'تأكيد الطلب وبوابة الدفع',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ⚠️ صندوق التنبيه الهام لمدة الـ 24 ساعة
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), // Amber 100
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.access_time_filled_rounded, color: Color(0xFFB45309), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'تنبيه هام حول مدة التنفيذ:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF92400E),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'بعض الاشتراكات والخدمات الرقمية تتطلب معالجة وتفعيلاً قد يستغرق مدة تصل إلى 24 ساعة كحد أقصى بعد إتمام عملية الدفع. في حال كان المفتاح متاحاً فورياً سيتم تسليمه لك في الحال مباشرة داخل التطبيق.',
                            style: TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ملخص المجموع بالريال اليمني والدولار المقابل
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(90),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('إجمالي الطلب (${widget.itemsCount} عناصر):', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.displayYer ?? '\$${widget.totalAmount.toStringAsFixed(2)} ${widget.currency}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: colorScheme.primary,
                          ),
                        ),
                        if (widget.displayYer != null)
                          Text(
                            '(\$${widget.totalAmount.toStringAsFixed(2)} ${widget.currency})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // حقل رقم الهاتف أو الواتساب
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف / الواتساب للتواصل والدفع',
                  hintText: '777000000',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // تأكيد فهم شرط الـ 24 ساعة
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? true),
                title: const Text(
                  'أوافق على أن تنفيذ الطلب قد يستغرق حتى 24 ساعة للمنتجات التي تتطلب تفعيلاً يدوياً.',
                  style: TextStyle(fontSize: 11.5, height: 1.3),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),

              // زر الدفع المباشر عبر المحافظ الإلكترونية (BasGate)
              if (widget.onPayWithBasGate != null) ...[
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F3E76), Color(0xFF1E60B8)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E60B8).withAlpha(70),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: !_acceptedTerms
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onPayWithBasGate!(
                                widget.initialTelegramUser ?? '',
                                _phoneController.text.trim(),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'الدفع المباشر بالمحافظ الإلكترونية',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'كاش، ون كاش، فلوسك، جوالي، بيس، وغيرها...',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(220),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // خيار طرق الدفع التقليدية الأخرى
              InkWell(
                onTap: () => setState(() => _showOtherPaymentMethods = !_showOtherPaymentMethods),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showOtherPaymentMethods ? 'إخفاء طرق الدفع الأخرى' : 'طرق دفع أخرى (بطاقة بنكية / حوالة)',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _showOtherPaymentMethods ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showOtherPaymentMethods) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'بطاقة بنكية / ميزة / فيزا', child: Text('💳 بطاقة بنكية (Visa / MasterCard)')),
                    DropdownMenuItem(value: 'Apple Pay / Google Pay', child: Text('📱 Apple Pay / Google Pay')),
                    DropdownMenuItem(value: 'تحويل بنكي مباشر', child: Text('🏦 تحويل بنكي / صرافة')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPaymentMethod = val);
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: !_acceptedTerms
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onConfirm(
                            widget.initialTelegramUser ?? '',
                            _phoneController.text.trim(),
                            _selectedPaymentMethod,
                          );
                        },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('متابعة بالطريقة المحددة'),
                ),
              ],

              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
