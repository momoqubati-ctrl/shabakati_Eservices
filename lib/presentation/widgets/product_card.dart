import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'الذكاء الاصطناعي':
        return Icons.auto_awesome_rounded;
      case 'التعليم واللغات':
        return Icons.school_rounded;
      case 'حماية وVPN':
        return Icons.security_rounded;
      case 'بث وترفيه':
        return Icons.play_circle_fill_rounded;
      case 'تراخيص وبرامج':
        return Icons.vpn_key_rounded;
      default:
        return Icons.all_inclusive_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAvail = product.isAvailable;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isAvail ? colorScheme.outlineVariant.withAlpha(120) : Colors.red.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس البطاقة: أيقونة وتصنيف
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(150),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(product.category),
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvail ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAvail ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    isAvail ? 'متوفر' : 'نفذت الكمية',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isAvail ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // اسم الخدمة
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),

            // تصنيف الخدمة الفرعي
            Text(
              product.category,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),

            const Spacer(),

            // السعر وزر الإضافة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'السعر',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                    Text(
                      product.sellerPrice.displayPrice,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: isAvail ? onAddToCart : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_shopping_cart_rounded, size: 16),
                      SizedBox(width: 4),
                      Text('إضافة', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
