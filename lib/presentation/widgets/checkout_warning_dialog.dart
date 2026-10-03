import 'package:flutter/material.dart';
import '../../data/models/cart_item_model.dart';

class CheckoutWarningDialog extends StatefulWidget {
  final double totalAmount;
  final String currency;
  final String? displayYer;
  final int itemsCount;
  final List<CartItemModel> items;
  final String? initialTelegramUser;
  final String? initialPhone;
  final String? warningMessage;
  final Function(String telegramUser, String phone) onPayWithBasGate;

  const CheckoutWarningDialog({
    super.key,
    required this.totalAmount,
    required this.currency,
    this.displayYer,
    required this.itemsCount,
    this.items = const [],
    this.initialTelegramUser,
    this.initialPhone,
    this.warningMessage,
    required this.onPayWithBasGate,
  });

  @override
  State<CheckoutWarningDialog> createState() => _CheckoutWarningDialogState();
}

class _CheckoutWarningDialogState extends State<CheckoutWarningDialog> {
  late final TextEditingController _phoneController;
  late bool _acceptedTerms;

  @override
  void initState() {
    super.initState();
    // تفريغ حقل رقم الهاتف افتراضياً بناء على رغبة المستخدم
    _phoneController = TextEditingController(text: '');
    // إذا لم تكن هناك رسالة تنبيه مفعلة، تعتبر الشروط مقبولة تلقائياً
    _acceptedTerms = widget.warningMessage == null || widget.warningMessage!.isEmpty;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _handleConfirmPayment(BuildContext context) {
    if (!_acceptedTerms) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رقم الهاتف / الواتساب للمتابعة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.pop(context);
    widget.onPayWithBasGate(
      widget.initialTelegramUser ?? '',
      phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool hasWarning = widget.warningMessage != null && widget.warningMessage!.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. رأس الديالوج العصري
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 18, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withAlpha(140),
                        colorScheme.surface,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(60),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تأكيد الشراء واختيار طريقة الدفع',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'مراجعة تفاصيل السلة وإتمام السداد الآمن',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 22),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. بطاقة ملخص العناصر والكميات والإجمالي
                      Container(
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ترويسة جدول العناصر
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withAlpha(75),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.receipt_long_rounded, size: 16, color: colorScheme.primary),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'تفاصيل العناصر المختارة',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withAlpha(25),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'إجمالي الكمية: ${widget.itemsCount}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // قائمة العناصر والكميات
                            if (widget.items.isNotEmpty)
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 165),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  itemCount: widget.items.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 14,
                                    color: colorScheme.outlineVariant.withAlpha(70),
                                  ),
                                  itemBuilder: (ctx, idx) {
                                    final item = widget.items[idx];
                                    final itemTotalYer = _formatNumber(item.totalAmountYer().round());
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer.withAlpha(120),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '×${item.quantity}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.product.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                'الكمية: ${item.quantity}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$itemTotalYer ر.ي',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                            Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(100)),

                            // صف الإجمالي النهائي
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withAlpha(12),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(17)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'الإجمالي النهائي المطلوب:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        widget.displayYer ?? '\$${widget.totalAmount.toStringAsFixed(2)} ${widget.currency}',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      if (widget.displayYer != null)
                                        Text(
                                          'ما يعادل \$${widget.totalAmount.toStringAsFixed(2)} ${widget.currency}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. ⚠️ صندوق التنبيه الهام (يظهر ديناميكياً فقط إذا كان مفعلاً لمنتجات السلة في لوحة التحكم)
                      if (hasWarning) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 1.1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.access_time_filled_rounded, color: Color(0xFFB45309), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'تنبيه هام حول مدة التنفيذ:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.5,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.warningMessage!,
                                      style: const TextStyle(fontSize: 11.5, height: 1.45, color: Color(0xFF78350F)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 4. حقل رقم الهاتف للتواصل وإشعارات الطلب
                      const Text(
                        'رقم الهاتف / الواتساب للتواصل وإشعارات الطلب',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'أدخل رقم هاتفك للتواصل واستلام الإشعارات',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.phone_android_rounded, size: 20),
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(140)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 5. بطاقة طريقة الدفع المختارة (المحافظ الإلكترونية)
                      const Text(
                        'طريقة الدفع المختارة',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withAlpha(14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.primary.withAlpha(140), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'الدفع عبر المحافظ الإلكترونية',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'دفع مباشر وفوري عبر بوابة المحافظ المعتمدة',
                                        style: TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 22),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final wallet in ['ون كاش', 'جوالي', 'فلوسك', 'كاش', 'بيس', 'سبأ كاش'])
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colorScheme.outlineVariant.withAlpha(120)),
                                    ),
                                    child: Text(
                                      wallet,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 6. تأكيد فهم شرط التنبيه (يظهر فقط إذا كان التنبيه مفعل ديناميكياً)
                      if (hasWarning) ...[
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _acceptedTerms,
                          onChanged: (v) => setState(() => _acceptedTerms = v ?? true),
                          title: const Text(
                            'أوافق على شرط ومدة تنفيذ الطلب الموضحة أعلاه.',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],

                      const SizedBox(height: 18),

                      // 7. أزرار التأكيد والإلغاء
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: !_acceptedTerms ? null : () => _handleConfirmPayment(context),
                          icon: const Icon(Icons.lock_outline_rounded, size: 19),
                          label: const Text(
                            'تأكيد الشراء والمتابعة للدفع',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F3E76),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('إلغاء وتعديل السلة', style: TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }
}
