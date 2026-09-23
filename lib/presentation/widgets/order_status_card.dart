import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/services/telegram_launcher.dart';
import '../../data/models/order_model.dart';

class OrderStatusCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onRefresh;

  const OrderStatusCard({
    super.key,
    required this.order,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReady = order.isReady;
    final isProcessing = order.isProcessing;

    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final formattedDate = dateFormat.format(order.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isReady
              ? Colors.green.withAlpha(100)
              : (isProcessing ? Colors.amber.withAlpha(100) : Colors.red.withAlpha(100)),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ترويسة البطاقة: رقم الطلب وحالة الإنجاز
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب #${order.externalOrderId.replaceAll('ord_', '')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReady
                        ? Colors.green.shade50
                        : (isProcessing ? Colors.amber.shade50 : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isReady
                          ? Colors.green.shade200
                          : (isProcessing ? Colors.amber.shade200 : Colors.red.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReady
                            ? Icons.check_circle_rounded
                            : (isProcessing ? Icons.hourglass_top_rounded : Icons.cancel_rounded),
                        size: 14,
                        color: isReady
                            ? Colors.green.shade800
                            : (isProcessing ? Colors.amber.shade900 : Colors.red.shade800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isReady
                            ? 'تم التسليم بنجاح'
                            : (isProcessing ? 'قيد التنفيذ (خلال 24 ساعة)' : 'فشل الطلب'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isReady
                              ? Colors.green.shade800
                              : (isProcessing ? Colors.amber.shade900 : Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // السعر الإجمالي
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المبلغ المدفوع:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  order.displayTotal,
                  style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // حالة المفتاح المسلم أو تنبيه الانتظار
            if (order.deliveredKey != null) ...[
              const Text('بيانات المفتاح / الكود الرقمي:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(120),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        order.deliveredKey!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'نسخ المفتاح',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: order.deliveredKey!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم نسخ المفتاح إلى الحافظة بنجاح'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ] else if (isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'جاري معالجة وتفعيل الاشتراك من قبل المزود. سيظهر المفتاح هنا فور اكتماله (خلال 24 ساعة كحد أقصى).',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.3),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF78350F)),
                      tooltip: 'تحديث الحالة',
                      onPressed: onRefresh,
                    )
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // زر المتابعة عبر بوت تيليجرام
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.support_agent_rounded, size: 18),
                label: const Text('متابعة مع الدعم الفني عبر تيليجرام', style: TextStyle(fontSize: 12)),
                onPressed: () => TelegramLauncher.openBotChat(startParam: order.externalOrderId),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
