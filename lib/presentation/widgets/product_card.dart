import 'package:flutter/material.dart';
import '../../data/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;
  final double exchangeRate;

  const ProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
    this.exchangeRate = 535.0,
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
    final stockQty = product.stockQuantity;

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
            // رأس البطاقة: أيقونة وتصنيف وحالة الكمية
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(90),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: (product.iconUrl != null && product.iconUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product.iconUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              _getCategoryIcon(product.category),
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAvail ? Icons.inventory_2_rounded : Icons.cancel_outlined,
                        size: 11,
                        color: isAvail ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isAvail ? 'متوفر: $stockQty' : 'نفذت الكمية',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isAvail ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
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

            // السعر بالريال اليمني + المعادل بالدولار وزر الإضافة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.displayPriceYer(exchangeRate: exchangeRate),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      product.displaySecondaryUsd,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
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
                      Text('شراء', style: TextStyle(fontSize: 12)),
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
