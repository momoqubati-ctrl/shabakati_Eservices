import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/secure_storage_service.dart';

/// شاشة البداية والتعريف التفاعلية الفاخرة (Onboarding & Splash Showcase)
/// مطابقة للتصميم المعتمد باللون الأزرق الملكي الملكي (Royal Blue) والـ 3D Artworks:
/// الشريحة 1: اشتراك في البرامج والتطبيقات بكل سهولة (ChatGPT, M365, Adobe, Canva, Netflix, YouTube)
/// الشريحة 2: الدفع المباشر عبر المحافظ الإلكترونية (فلوسك، جيب، ون كاش، كاش، بيس)
/// الشريحة 3: وتسليم فوري لرابط الاشتراك والتفعيل (تفعيل فوري ورابط مباشر)
class OnboardingSplashPage extends StatefulWidget {
  final bool isReviewMode;
  final VoidCallback? onComplete;

  const OnboardingSplashPage({
    super.key,
    this.isReviewMode = false,
    this.onComplete,
  });

  @override
  State<OnboardingSplashPage> createState() => _OnboardingSplashPageState();
}

class _OnboardingSplashPageState extends State<OnboardingSplashPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onPrevious() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    try {
      final storage = context.read<SecureStorageService>();
      await storage.setOnboardingSeen();
    } catch (_) {}

    if (!mounted) return;

    if (widget.isReviewMode) {
      Navigator.of(context).pop();
    } else if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF00227B),
          body: Stack(
            children: [
              // 1. خلفية زرقاء ملكية فاخرة مع تدرجات وأشعة ضوئية هادئة
              const Positioned.fill(
                child: _RoyalBlueCosmicBackground(),
              ),

              // 2. المحتوى الرئيسي
              SafeArea(
                child: Column(
                  children: [
                    // الهيدر العلوي: لوجو بوابة شبكتي في المنتصف مع زر التخطي في الطرف
                    _buildTopHeader(),

                    // الشرائح الثلاث المتحركة
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        children: [
                          _buildSlide(
                            titleLine1: 'اشترك في البرامج',
                            titleLine2: 'والتطبيقات بكل سهولة',
                            subtitle:
                                'نوفر لك اشتراكات مميزة لأشهر تطبيقات الذكاء الاصطناعي والبرامج العالمية',
                            heroAsset: 'assets/icon/splash_hero_1.png',
                            feature1: const _FeatureItem(
                              icon: Icons.verified_rounded,
                              label: 'تطبيقات أصلية',
                            ),
                            feature2: const _FeatureItem(
                              icon: Icons.headset_mic_rounded,
                              label: 'دعم فني متميز',
                            ),
                            feature3: const _FeatureItem(
                              icon: Icons.shield_rounded,
                              label: 'آمن وسريع',
                            ),
                          ),
                          _buildSlide(
                            titleLine1: 'الدفع المباشر عبر',
                            titleLine2: 'المحافظ الإلكترونية',
                            subtitle:
                                'ادفع بسهولة وأمان من خلال أشهر المحافظ الإلكترونية في اليمن',
                            heroAsset: 'assets/icon/splash_hero_2.png',
                            feature1: const _FeatureItem(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'جميع المحافظ اليمنية',
                            ),
                            feature2: const _FeatureItem(
                              icon: Icons.bolt_rounded,
                              label: 'تسريع فوري',
                            ),
                            feature3: const _FeatureItem(
                              icon: Icons.security_rounded,
                              label: 'دفع آمن',
                            ),
                          ),
                          _buildSlide(
                            titleLine1: 'وتسليم فوري',
                            titleLine2: 'لرابط الاشتراك والتفعيل',
                            subtitle:
                                'بعد إتمام الدفع بنجاح سيصلك رابط الاشتراك فوراً مع كود التفعيل',
                            heroAsset: 'assets/icon/splash_hero_3.png',
                            feature1: const _FeatureItem(
                              icon: Icons.task_alt_rounded,
                              label: 'بدون تعقيدات',
                            ),
                            feature2: const _FeatureItem(
                              icon: Icons.link_rounded,
                              label: 'رابط مباشر',
                            ),
                            feature3: const _FeatureItem(
                              icon: Icons.timer_outlined,
                              label: 'تفعيل فوري',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // عناصر التحكم السفلية: النقاط والأزرار
                    _buildBottomControls(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الهيدر العلوي: لوجو التطبيق في المنتصف وزر التخطي
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // اللوجو المركزي لبوابة شبكتي
          Center(
            child: SizedBox(
              height: 68,
              child: Image.asset(
                'assets/icon/splash_top_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_tethering, color: Colors.cyanAccent, size: 28),
                    const SizedBox(height: 4),
                    const Text(
                      'بوابة شبكتي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '— للخدمات الرقمية —',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // زر التخطي (أو إغلاق) في جهة اليسار (في واجهة RTL)
          Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _finishOnboarding,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        widget.isReviewMode ? 'إغلاق' : 'تخطي',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء الشريحة المتكاملة بحسب التصميم الأصلي
  Widget _buildSlide({
    required String titleLine1,
    required String titleLine2,
    required String subtitle,
    required String heroAsset,
    required _FeatureItem feature1,
    required _FeatureItem feature2,
    required _FeatureItem feature3,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. قسم النصوص العلوية مع الفاصل السماوي
                Column(
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      titleLine1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      titleLine2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF29E7FF),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // الفاصل السماوي الأنيق (─── ••• ───)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF29E7FF).withValues(alpha: 0.0),
                                const Color(0xFF29E7FF),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(3, (i) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Color(0xFF29E7FF),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 42,
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF29E7FF),
                                const Color(0xFF29E7FF).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // الوصف الفرعي
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. الصورة الفنية ثلاثية الأبعاد المركزية (Hero Artwork)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.44,
                    ),
                    child: Center(
                      child: Image.asset(
                        heroAsset,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),

                // 3. شريط المزايا الثلاثي السفلي مع الفواصل العمودية
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF001B6B).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF29E7FF).withValues(alpha: 0.22),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0030A8).withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildFeatureColumn(feature1)),
                      _buildVerticalDivider(),
                      Expanded(child: _buildFeatureColumn(feature2)),
                      _buildVerticalDivider(),
                      Expanded(child: _buildFeatureColumn(feature3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// عنصر الميزة الواحدة داخل الشريط السفلي
  Widget _buildFeatureColumn(_FeatureItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.icon,
          size: 20,
          color: const Color(0xFF29E7FF),
        ),
        const SizedBox(height: 5),
        Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// فاصل عمودي ناعم بين المزايا
  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  /// الفوتر السفلي: مؤشرات الانتقال والأزرار التفاعلية
  Widget _buildBottomControls() {
    final isLastPage = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // شريط النقاط المؤشرة
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              final isCurrent = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 7,
                width: isCurrent ? 26 : 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isCurrent
                      ? const Color(0xFF29E7FF)
                      : Colors.white.withValues(alpha: 0.25),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF29E7FF).withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // صف الأزرار (السابق + التالي / ابدأ الآن)
          Row(
            children: [
              // زر السابق (يظهر بدءاً من الشريحة الثانية)
              if (_currentPage > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _onPrevious,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded, // يعبر عن العودة في RTL
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // زر التالي أو ابدأ الآن
              Expanded(
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0072FF), Color(0xFF00D2FF)],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0099FF).withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onNext,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isLastPage ? 'ابدأ الآن واستكشف الخدمات' : 'التالي',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastPage
                                  ? Icons.rocket_launch_rounded
                                  : Icons.arrow_back_rounded, // يعبر عن المضي قدماً في RTL
                              color: Colors.white,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// نموذج كائن الميزة الواحدة في الفوتر
class _FeatureItem {
  final IconData icon;
  final String label;

  const _FeatureItem({
    required this.icon,
    required this.label,
  });
}

/// خلفية أزرق ملكي مع تموجات ضوئية أنيقة مطابقة للتصميم
class _RoyalBlueCosmicBackground extends StatelessWidget {
  const _RoyalBlueCosmicBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0050D6), // أزرق علوي ساطع
            Color(0xFF002B94), // أزرق ملكي مركزي
            Color(0xFF001552), // أزرق ملكي داكن
          ],
        ),
      ),
      child: Stack(
        children: [
          // هالة إشعاعية زرقاء ناعمة في المنتصف خلف مجسم الهاتف
          Positioned(
            top: 220,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF007BFF).withValues(alpha: 0.28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
                  child: const SizedBox(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
