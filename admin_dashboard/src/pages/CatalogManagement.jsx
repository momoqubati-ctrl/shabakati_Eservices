import React, { useState, useEffect } from 'react';
import { 
  Layers, 
  RefreshCw, 
  DollarSign, 
  Coins, 
  Save, 
  Check, 
  AlertCircle,
  Package,
  TrendingUp,
  Image as ImageIcon,
  AlertTriangle
} from 'lucide-react';
import { DigitalVaultService } from '../services/digitalVaultService';
import { supabase } from '../config/supabase';

const ICON_BASE_URL = 'https://enutfwspwrzpvhmtgftl.supabase.co/storage/v1/object/public/service-icons/';

export const PRESET_ICONS = [
  { name: 'Gemini Pro', icon: `${ICON_BASE_URL}gemini.png` },
  { name: 'ChatGPT / OpenAI', icon: `${ICON_BASE_URL}chatgpt.png` },
  { name: 'Duolingo', icon: `${ICON_BASE_URL}duolingo.png` },
  { name: 'Canva Pro', icon: `${ICON_BASE_URL}canva_v2.png` },
  { name: 'Adobe Express', icon: `${ICON_BASE_URL}adobe_express_v2.png` },
  { name: 'LinkedIn Premium', icon: `${ICON_BASE_URL}linkedin.png` },
  { name: 'Coursera Plus', icon: `${ICON_BASE_URL}coursera.png` },
  { name: 'Microsoft 365', icon: `${ICON_BASE_URL}office365.png` },
  { name: 'CapCut Pro', icon: `${ICON_BASE_URL}capcut_v2.png` },
  { name: 'Netflix', icon: `${ICON_BASE_URL}netflix.png` },
  { name: 'Notion AI', icon: `${ICON_BASE_URL}notion.png` },
  { name: 'NordVPN', icon: `${ICON_BASE_URL}nordvpn.png` }
];

export const getDefaultIcon = (sku = '', name = '') => {
  const lower = `${sku.toLowerCase()} ${name.toLowerCase()}`;
  if (lower.includes('gemini')) return `${ICON_BASE_URL}gemini.png`;
  if (lower.includes('duolingo')) return `${ICON_BASE_URL}duolingo.png`;
  if (lower.includes('chatgpt') || lower.includes('gpt') || lower.includes('openai')) return `${ICON_BASE_URL}chatgpt.png`;
  if (lower.includes('canva')) return `${ICON_BASE_URL}canva_v2.png`;
  if (lower.includes('adobe')) return `${ICON_BASE_URL}adobe_express_v2.png`;
  if (lower.includes('linkedin')) return `${ICON_BASE_URL}linkedin.png`;
  if (lower.includes('coursera')) return `${ICON_BASE_URL}coursera.png`;
  if (lower.includes('office') || lower.includes('365') || lower.includes('microsoft')) return `${ICON_BASE_URL}office365.png`;
  if (lower.includes('capcut')) return `${ICON_BASE_URL}capcut_v2.png`;
  if (lower.includes('netflix')) return `${ICON_BASE_URL}netflix.png`;
  if (lower.includes('notion')) return `${ICON_BASE_URL}notion.png`;
  if (lower.includes('nordvpn') || lower.includes('vpn')) return `${ICON_BASE_URL}nordvpn.png`;
  return `${ICON_BASE_URL}gemini.png`;
};

export const CatalogManagement = ({ initialProducts = [], onSync }) => {
  const [products, setProducts] = useState(initialProducts);
  const [isSyncing, setIsSyncing] = useState(false);
  const [exchangeRate, setExchangeRate] = useState(535); // سعر الصرف الافتراضي
  const [isSavingRate, setIsSavingRate] = useState(false);
  const [rateSavedMessage, setRateSavedMessage] = useState(false);

  // إعدادات المنتجات المخصصة (سعر البيع بالريال والكمية)
  const [customPricing, setCustomPricing] = useState({});
  const [savingProductId, setSavingProductId] = useState(null);

  // جلب سعر الصرف وإعدادات المنتجات من Supabase
  const loadSettings = async () => {
    try {
      // 1. جلب سعر الصرف
      const { data: settings } = await supabase
        .from('app_settings')
        .select('*')
        .eq('id', 'general_settings')
        .single();

      if (settings?.usd_to_yer_rate) {
        setExchangeRate(Number(settings.usd_to_yer_rate));
      }

      // 2. جلب أسعار البيع والكميات والأيقونات ورسائل التنبيه المخصصة لكل منتج
      const { data: productSettings } = await supabase
        .from('product_settings')
        .select('*');

      if (productSettings) {
        const pricingMap = {};
        productSettings.forEach((ps) => {
          pricingMap[ps.product_id] = {
            customPriceYer: ps.custom_price_yer || '',
            stockQuantity: ps.stock_quantity !== null && ps.stock_quantity !== undefined ? ps.stock_quantity : '',
            isActive: ps.is_active ?? true,
            iconUrl: ps.icon_url || '',
            hasWarningNotice: ps.has_warning_notice ?? false,
            warningNoticeMessage: ps.warning_notice_message || '',
          };
        });
        setCustomPricing(pricingMap);
      }

      // 3. جلب المنتجات المخزنة من Supabase فوراً إذا كانت القائمة فارغة
      const { data: cachedProds } = await supabase
        .from('cached_products')
        .select('*')
        .order('id', { ascending: true });

      if (Array.isArray(cachedProds) && cachedProds.length > 0) {
        const formatted = cachedProds.map((p) => ({
          id: p.id,
          sku: p.sku,
          name: p.name,
          availability: (p.availability || 'available').replace(/"/g, ''),
          pricing_quantity: 1,
          seller_price: {
            amount_cents: p.price_cents || 0,
            currency: p.currency || 'USD',
          },
          seller_base_price: {
            amount_cents: p.price_cents || 0,
            currency: p.currency || 'USD',
          },
          line_total: {
            amount_cents: p.price_cents || 0,
            currency: p.currency || 'USD',
          },
        }));
        setProducts((prev) => (prev && prev.length > 0 ? prev : formatted));
        if (onSync) onSync(formatted);
      }
    } catch (e) {
      console.warn('Error loading pricing settings:', e);
    }
  };

  useEffect(() => {
    loadSettings();
  }, []);

  useEffect(() => {
    setProducts(initialProducts);
  }, [initialProducts]);

  // حفظ سعر الصرف الجديد
  const handleSaveExchangeRate = async () => {
    setIsSavingRate(true);
    try {
      const { error } = await supabase
        .from('app_settings')
        .upsert({
          id: 'general_settings',
          usd_to_yer_rate: exchangeRate,
          updated_at: new Date().toISOString()
        });

      if (error) throw error;
      setRateSavedMessage(true);
      setTimeout(() => setRateSavedMessage(false), 3000);
    } catch (e) {
      alert('فشل حفظ سعر الصرف: ' + e.message);
    } finally {
      setIsSavingRate(false);
    }
  };

  // مزامنة الكتالوج من المزود أو قاعدة البيانات
  const handleManualSync = async () => {
    setIsSyncing(true);
    try {
      let loaded = false;
      try {
        const data = await DigitalVaultService.getCatalogProducts();
        if (data?.success && Array.isArray(data?.data) && data.data.length > 0) {
          setProducts(data.data);
          if (onSync) onSync(data.data);
          loaded = true;
        }
      } catch (_) {}

      if (!loaded) {
        // Fallback لقاعدة البيانات
        const { data: cachedProds } = await supabase
          .from('cached_products')
          .select('*')
          .order('id', { ascending: true });

        if (Array.isArray(cachedProds) && cachedProds.length > 0) {
          const formatted = cachedProds.map((p) => ({
            id: p.id,
            sku: p.sku,
            name: p.name,
            availability: (p.availability || 'available').replace(/"/g, ''),
            pricing_quantity: 1,
            seller_price: {
              amount_cents: p.price_cents || 0,
              currency: p.currency || 'USD',
            },
            seller_base_price: {
              amount_cents: p.price_cents || 0,
              currency: p.currency || 'USD',
            },
            line_total: {
              amount_cents: p.price_cents || 0,
              currency: p.currency || 'USD',
            },
          }));
          setProducts(formatted);
          if (onSync) onSync(formatted);
        } else {
          alert('تعذر جلب الخدمات من المزود أو من قاعدة البيانات');
        }
      }
    } catch (e) {
      alert('فشل جلب الكتالوج: ' + e.message);
    } finally {
      setIsSyncing(false);
    }
  };

  // حفظ سعر البيع بالريال والكمية المتاحة والأيقونة لخدمة معينة
  const handleSaveProductPricing = async (product) => {
    const custom = customPricing[product.id] || {};
    const costUsd = (product.seller_price?.amount_cents || 0) / 100;
    const costYer = costUsd * exchangeRate;
    const defaultPriceYer = Math.ceil((costYer + 1000) / 1000) * 1000;
    
    // هل أدخل المستخدم سعراً مخصصاً؟
    const rawVal = custom.customPriceYer;
    const hasCustomVal = rawVal !== undefined && rawVal !== null && rawVal !== '' && !isNaN(Number(rawVal)) && Number(rawVal) > 0;
    
    // هل أدخل المستخدم كمية يدوية محددة؟
    const rawStock = custom.stockQuantity;
    const hasCustomStock = rawStock !== undefined && rawStock !== null && rawStock !== '' && !isNaN(Number(rawStock));
    const stockToSave = hasCustomStock ? Number(rawStock) : null;

    // إذا كان مخصصاً نحفظ الرقم، وإلا null لكي يبقى محتسباً آلياً في التطبيق
    const priceYerToSave = hasCustomVal ? Number(rawVal) : null;
    const effectiveIconUrl = custom.iconUrl || getDefaultIcon(product.sku, product.name);
    const hasWarning = custom.hasWarningNotice ?? false;
    const warningMsg = hasWarning ? (custom.warningNoticeMessage || '') : null;

    setSavingProductId(product.id);
    try {
      const { error } = await supabase
        .from('product_settings')
        .upsert({
          product_id: product.id,
          sku: product.sku,
          custom_price_yer: priceYerToSave,
          custom_price_usd: priceYerToSave ? (priceYerToSave / exchangeRate).toFixed(2) : null,
          stock_quantity: stockToSave,
          icon_url: effectiveIconUrl,
          is_active: custom.isActive ?? true,
          has_warning_notice: hasWarning,
          warning_notice_message: warningMsg,
          updated_at: new Date().toISOString()
        });

      if (error) throw error;

      // تحديث الحالة محلياً
      setCustomPricing(prev => ({
        ...prev,
        [product.id]: {
          ...prev[product.id],
          customPriceYer: priceYerToSave !== null ? priceYerToSave : '',
          stockQuantity: stockToSave !== null ? stockToSave : '',
          iconUrl: effectiveIconUrl,
          hasWarningNotice: hasWarning,
          warningNoticeMessage: hasWarning ? (custom.warningNoticeMessage || '') : '',
          saved: true
        }
      }));

      setTimeout(() => {
        setCustomPricing(prev => ({
          ...prev,
          [product.id]: { ...prev[product.id], saved: false }
        }));
      }, 2000);
    } catch (e) {
      alert('فشل حفظ إعدادات المنتج: ' + e.message);
    } finally {
      setSavingProductId(null);
    }
  };

  return (
    <div className="space-y-6">
      {/* بطاقة سعر الصرف والمصارفة (USD to YER) */}
      <div className="bg-gradient-to-r from-blue-900/40 via-slate-900 to-slate-900 border border-blue-800/40 p-6 rounded-3xl shadow-lg flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="p-3 bg-blue-600 rounded-2xl text-white shadow-lg shadow-blue-500/30">
            <Coins className="w-8 h-8" />
          </div>
          <div>
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <span>سعر المصارفة للجمهور (الدولار مقابل الريال اليمني)</span>
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              يتم تحويل وتحديث أسعار كافة الاشتراكات تلقائياً في تطبيق الموبايل بناءً على هذا السعر
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3 w-full md:w-auto">
          <div className="flex items-center gap-2 bg-slate-800/90 border border-slate-700 px-4 py-2 rounded-2xl">
            <span className="text-xs font-bold text-slate-400">1 USD =</span>
            <input
              type="number"
              value={exchangeRate}
              onChange={(e) => setExchangeRate(Number(e.target.value))}
              className="w-28 text-center text-lg font-black text-amber-400 bg-transparent border-b border-amber-400/50 focus:outline-none"
            />
            <span className="text-xs font-bold text-slate-300">ر.ي</span>
          </div>

          <button
            onClick={handleSaveExchangeRate}
            disabled={isSavingRate}
            className="flex items-center gap-2 px-5 py-3 bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs rounded-xl shadow-lg shadow-blue-600/25 transition-all"
          >
            {rateSavedMessage ? <Check className="w-4 h-4 text-emerald-300" /> : <Save className="w-4 h-4" />}
            <span>{rateSavedMessage ? 'تم الحفظ!' : (isSavingRate ? 'جاري الحفظ...' : 'تحديث سعر الصرف')}</span>
          </button>
        </div>
      </div>

      {/* رأس صفحة الكتالوج */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h3 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <Layers className="w-5 h-5 text-blue-600" />
            <span>كتالوج الخدمات وتحديد أسعار البيع والكميات المتاحة</span>
          </h3>
          <p className="text-xs text-slate-500 mt-0.5">
            التحكم الكامل بسعر البيع للجمهور بالريال اليمني (ر.ي) ومتابعة كميات المزود
          </p>
        </div>

        <button
          onClick={handleManualSync}
          disabled={isSyncing}
          className="flex items-center gap-2 px-4 py-2 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 text-slate-700 dark:text-slate-200 font-bold text-xs rounded-xl transition-all"
        >
          <RefreshCw className={`w-4 h-4 ${isSyncing ? 'animate-spin' : ''}`} />
          <span>مزامنة الكتالوج من المزود</span>
        </button>
      </div>

      {/* شبكة عرض وتعديل المنتجات */}
      {products.length === 0 ? (
        <div className="bg-white dark:bg-slate-800 p-12 rounded-3xl border border-slate-200 dark:border-slate-700/80 text-center space-y-4 shadow-sm">
          <div className="w-16 h-16 mx-auto bg-blue-50 dark:bg-blue-900/30 rounded-2xl flex items-center justify-center text-blue-600">
            <RefreshCw className={`w-8 h-8 ${isSyncing ? 'animate-spin' : ''}`} />
          </div>
          <h4 className="text-base font-bold text-slate-800 dark:text-slate-100">
            {isSyncing ? 'جاري جلب الكتالوج من قاعدة البيانات...' : 'لم يتم تحميل أي خدمات في الكتالوج حالياً'}
          </h4>
          <p className="text-xs text-slate-500 max-w-md mx-auto">
            اضغط على الزر أدناه لتحميل قائمة الخدمات فوراً وتحديث الأسعار.
          </p>
          <button
            onClick={handleManualSync}
            disabled={isSyncing}
            className="px-6 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs rounded-xl shadow-lg shadow-blue-500/20 transition-all inline-flex items-center gap-2"
          >
            <RefreshCw className={`w-4 h-4 ${isSyncing ? 'animate-spin' : ''}`} />
            <span>تحميل الكتالوج الآن</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {products.map((product) => {
          const costUsd = (product.seller_price?.amount_cents || 0) / 100;
          const costYer = Math.round(costUsd * exchangeRate);
          const isAvail = product.availability === 'available';

          const custom = customPricing[product.id] || {};
          const defaultSellingPriceYer = Math.ceil((costYer + 1000) / 1000) * 1000;
          
          const rawPrice = custom.customPriceYer;
          const hasCustomPrice = rawPrice !== undefined && 
                                 rawPrice !== null && 
                                 rawPrice !== '' && 
                                 !isNaN(Number(rawPrice)) && 
                                 Number(rawPrice) > 0;

          // السماح للمستخدم بتعديل ومسح الحقل بحرية دون إجباره على السعر الافتراضي أثناء الكتابة
          const displayInputValue = rawPrice !== undefined 
            ? rawPrice 
            : defaultSellingPriceYer;

          const effectivePriceForProfit = hasCustomPrice 
            ? Number(rawPrice) 
            : defaultSellingPriceYer;

          const currentIconUrl = custom.iconUrl || getDefaultIcon(product.sku, product.name);

          const rawStock = custom.stockQuantity;
          const hasCustomStock = rawStock !== undefined && rawStock !== null && rawStock !== '' && !isNaN(Number(rawStock));
          const stockQty = hasCustomStock ? Number(rawStock) : null;
          const isSaved = custom.saved;

          return (
            <div 
              key={product.id}
              className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex flex-col justify-between space-y-4"
            >
              <div>
                {/* رأس بطاقة المنتج */}
                <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-700">
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
                    ID #{product.id}
                  </span>
                  <div className="flex items-center gap-2">
                    {/* الكمية وحالة التوفر */}
                    <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold flex items-center gap-1 ${
                      !isAvail 
                        ? 'bg-red-100 dark:bg-red-950 text-red-700 dark:text-red-300 border border-red-200 dark:border-red-900/60' 
                        : (hasCustomStock 
                            ? 'bg-blue-100 dark:bg-blue-950 text-blue-700 dark:text-blue-300 border border-blue-200 dark:border-blue-900/60' 
                            : 'bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-900/60')
                    }`}>
                      <Package className="w-3 h-3" />
                      <span>
                        {!isAvail 
                          ? 'نفذت الكمية حاول لاحقاً' 
                          : (hasCustomStock ? `الكمية: ${stockQty} قطعة` : 'متوفر')}
                      </span>
                    </span>
                  </div>
                </div>

                {/* عرض الأيقونة واسم الخدمة */}
                <div className="flex items-start gap-3 mt-3">
                  <div className="w-12 h-12 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 p-1.5 shadow-sm flex items-center justify-center shrink-0">
                    <img 
                      src={currentIconUrl} 
                      alt={product.name} 
                      className="w-full h-full object-contain"
                      onError={(e) => {
                        e.target.onerror = null;
                        e.target.src = getDefaultIcon(product.sku, product.name);
                      }}
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="font-bold text-slate-900 dark:text-white text-sm line-clamp-2 leading-tight">
                      {product.name}
                    </h4>
                    <span className="text-xs text-slate-400 font-mono block mt-1">
                      SKU: {product.sku}
                    </span>
                  </div>
                </div>

                {/* قسم اختيار أو تغيير الأيقونة */}
                <div className="mt-3 p-2.5 bg-slate-50/80 dark:bg-slate-900/40 rounded-xl border border-slate-200/80 dark:border-slate-700/60">
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1">
                      <ImageIcon className="w-3.5 h-3.5 text-blue-500" />
                      <span>أيقونة الخدمة:</span>
                    </label>
                    <span className="text-[10px] text-slate-400">انقر لاختيار أيقونة</span>
                  </div>
                  {/* شريط الأيقونات السريعة */}
                  <div className="flex items-center gap-1.5 overflow-x-auto pb-1 scrollbar-thin">
                    {PRESET_ICONS.map((pIcon) => (
                      <button
                        key={pIcon.name}
                        type="button"
                        onClick={() => {
                          setCustomPricing(prev => ({
                            ...prev,
                            [product.id]: {
                              ...prev[product.id],
                              iconUrl: pIcon.icon
                            }
                          }));
                        }}
                        title={pIcon.name}
                        className={`w-7 h-7 rounded-lg p-1 shrink-0 border transition-all ${
                          currentIconUrl === pIcon.icon 
                            ? 'border-blue-600 bg-blue-50 dark:bg-blue-900/50 ring-2 ring-blue-500/20' 
                            : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 hover:border-blue-400'
                        }`}
                      >
                        <img src={pIcon.icon} alt={pIcon.name} className="w-full h-full object-contain" />
                      </button>
                    ))}
                  </div>
                  {/* حقل رابط مخصص */}
                  <input
                    type="url"
                    placeholder="أو الصق رابط صورة مخصص (URL)"
                    value={custom.iconUrl || ''}
                    onChange={(e) => {
                      const val = e.target.value;
                      setCustomPricing(prev => ({
                        ...prev,
                        [product.id]: {
                          ...prev[product.id],
                          iconUrl: val
                        }
                      }));
                    }}
                    className="w-full mt-1.5 px-2 py-1 text-[10px] rounded-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 focus:outline-none focus:border-blue-500 font-mono text-slate-600 dark:text-slate-300"
                  />
                </div>

                {/* سعر التكلفة من المزود */}
                <div className="mt-3 p-3 bg-slate-50 dark:bg-slate-900/60 rounded-xl border border-slate-200 dark:border-slate-700/60 text-xs flex justify-between items-center">
                  <span className="text-slate-500">سعر التكلفة من المزود:</span>
                  <div className="text-left">
                    <span className="font-bold text-slate-800 dark:text-slate-200">${costUsd.toFixed(2)} USD</span>
                    <span className="text-slate-400 block text-[10px]">({costYer.toLocaleString()} ر.ي)</span>
                  </div>
                </div>

                {/* قسم رسالة التنبيه للطلب (24 ساعة أو معالجة خاصة) */}
                <div className="mt-3 p-3 bg-amber-50/70 dark:bg-amber-950/20 rounded-xl border border-amber-200/80 dark:border-amber-900/40">
                  <div className="flex items-center justify-between">
                    <label className="flex items-center gap-2 cursor-pointer select-none">
                      <input
                        type="checkbox"
                        checked={custom.hasWarningNotice ?? false}
                        onChange={(e) => {
                          const checked = e.target.checked;
                          setCustomPricing(prev => ({
                            ...prev,
                            [product.id]: {
                              ...prev[product.id],
                              hasWarningNotice: checked,
                              warningNoticeMessage: checked 
                                ? (prev[product.id]?.warningNoticeMessage || 'بعض الاشتراكات والخدمات الرقمية تتطلب معالجة وتفعيلاً قد يستغرق مدة تصل إلى 24 ساعة كحد أقصى بعد إتمام عملية الدفع. في حال كان المفتاح متاحاً فورياً سيتم تسليمه لك في الحال مباشرة داخل التطبيق.') 
                                : ''
                            }
                          }));
                        }}
                        className="w-4 h-4 text-amber-600 rounded border-amber-300 focus:ring-amber-500 cursor-pointer"
                      />
                      <span className="text-xs font-bold text-amber-900 dark:text-amber-300 flex items-center gap-1.5">
                        <AlertTriangle className="w-3.5 h-3.5 text-amber-600" />
                        <span>تفعيل رسالة تنبيه للطلب (24 ساعة)</span>
                      </span>
                    </label>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                      custom.hasWarningNotice 
                        ? 'bg-amber-200 text-amber-900 dark:bg-amber-900/60 dark:text-amber-200' 
                        : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
                    }`}>
                      {custom.hasWarningNotice ? 'مفعل بالتطبيق' : 'غير مفعل'}
                    </span>
                  </div>

                  {custom.hasWarningNotice && (
                    <div className="mt-2.5 space-y-1">
                      <label className="block text-[11px] font-semibold text-amber-800 dark:text-amber-300">
                        نص رسالة التنبيه المعروضة في التطبيق:
                      </label>
                      <textarea
                        rows={3}
                        value={custom.warningNoticeMessage || ''}
                        onChange={(e) => {
                          const val = e.target.value;
                          setCustomPricing(prev => ({
                            ...prev,
                            [product.id]: {
                              ...prev[product.id],
                              warningNoticeMessage: val
                            }
                          }));
                        }}
                        placeholder="أدخل رسالة التنبيه التي ستظهر في نافذة الدفع للعميل..."
                        className="w-full p-2 text-xs rounded-lg bg-white dark:bg-slate-900 border border-amber-300 dark:border-amber-800/60 focus:outline-none focus:ring-1 focus:ring-amber-500 text-slate-800 dark:text-slate-200"
                      />
                      <p className="text-[10px] text-amber-700/80 dark:text-amber-400">
                        ستظهر هذه الرسالة ومربع الموافقة في التطبيق فقط إذا كان هذا المنتج في السلة.
                      </p>
                    </div>
                  )}
                </div>
              </div>

              {/* قسم تحديد سعر البيع للجمهور بالريال اليمني */}
              <div className="space-y-3 pt-3 border-t border-slate-100 dark:border-slate-700">
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                      سعر البيع للجمهور (بالريال اليمني):
                    </label>
                    {hasCustomPrice ? (
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-700 dark:bg-amber-950/60 dark:text-amber-300 border border-amber-200 dark:border-amber-800/50">
                        سعر يدوي مخصص
                      </span>
                    ) : (
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-700 dark:bg-emerald-950/60 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800/50">
                        احتساب آلي (+1000 وتقريب)
                      </span>
                    )}
                  </div>
                  <div className="relative">
                    <input
                      type="number"
                      value={displayInputValue}
                      onChange={(e) => {
                        const val = e.target.value;
                        setCustomPricing(prev => ({
                          ...prev,
                          [product.id]: {
                            ...prev[product.id],
                            customPriceYer: val
                          }
                        }));
                      }}
                      placeholder={`آلي: ${defaultSellingPriceYer}`}
                      className="w-full pl-12 pr-4 py-2.5 text-sm font-black text-blue-600 dark:text-blue-400 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 focus:outline-none focus:border-blue-500"
                    />
                    <span className="absolute left-3.5 top-2.5 text-xs font-bold text-slate-400">ر.ي</span>
                  </div>
                  <div className="flex items-center justify-between mt-1.5 text-[11px]">
                    <span className="text-emerald-600 font-semibold">
                      الربح: {(effectivePriceForProfit - costYer).toLocaleString()} ر.ي
                    </span>
                    {hasCustomPrice && (
                      <button
                        type="button"
                        onClick={() => {
                          setCustomPricing(prev => ({
                            ...prev,
                            [product.id]: {
                              ...prev[product.id],
                              customPriceYer: ''
                            }
                          }));
                        }}
                        className="text-[10px] text-blue-600 hover:text-blue-700 dark:text-blue-400 underline font-semibold flex items-center gap-1"
                      >
                        <RefreshCw className="w-2.5 h-2.5" />
                        <span>استعادة السعر الآلي ({defaultSellingPriceYer.toLocaleString()} ر.ي)</span>
                      </button>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <div className="flex-1">
                    <label className="block text-[10px] text-slate-400 mb-0.5">
                      الكمية المتاحة (فارغ = متوفر):
                    </label>
                    <input
                      type="number"
                      value={custom.stockQuantity !== undefined ? custom.stockQuantity : ''}
                      onChange={(e) => {
                        const val = e.target.value;
                        setCustomPricing(prev => ({
                          ...prev,
                          [product.id]: {
                            ...prev[product.id],
                            stockQuantity: val
                          }
                        }));
                      }}
                      placeholder="متوفر (غير محدد)"
                      className="w-full px-2.5 py-1.5 text-xs font-bold rounded-lg bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 focus:outline-none placeholder:text-slate-400 placeholder:font-normal"
                    />
                  </div>

                  <button
                    onClick={() => handleSaveProductPricing(product)}
                    disabled={savingProductId === product.id}
                    className={`mt-4 px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
                      isSaved 
                        ? 'bg-emerald-600 text-white' 
                        : 'bg-blue-600 hover:bg-blue-700 text-white shadow-sm'
                    }`}
                  >
                    {isSaved ? <Check className="w-3.5 h-3.5" /> : <Save className="w-3.5 h-3.5" />}
                    <span>{isSaved ? 'تم الحفظ' : (savingProductId === product.id ? 'حفظ...' : 'حفظ السعر')}</span>
                  </button>
                </div>
              </div>
            </div>
          );
        })}
        </div>
      )}
    </div>
  );
};
