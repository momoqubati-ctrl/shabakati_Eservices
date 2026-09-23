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
  TrendingUp
} from 'lucide-react';
import { DigitalVaultService } from '../services/digitalVaultService';
import { supabase } from '../config/supabase';

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

      // 2. جلب أسعار البيع المخصصة لكل منتج
      const { data: productSettings } = await supabase
        .from('product_settings')
        .select('*');

      if (productSettings) {
        const pricingMap = {};
        productSettings.forEach((ps) => {
          pricingMap[ps.product_id] = {
            customPriceYer: ps.custom_price_yer || '',
            stockQuantity: ps.stock_quantity ?? 99,
            isActive: ps.is_active ?? true,
          };
        });
        setCustomPricing(pricingMap);
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

  // مزامنة الكتالوج من المزود
  const handleManualSync = async () => {
    setIsSyncing(true);
    try {
      const data = await DigitalVaultService.getCatalogProducts();
      if (data?.success && data?.data) {
        setProducts(data.data);
        if (onSync) onSync(data.data);
      }
    } catch (e) {
      alert('فشل جلب الكتالوج من المزود: ' + e.message);
    } finally {
      setIsSyncing(false);
    }
  };

  // حفظ سعر البيع بالريال والكمية المتاحة لخدمة معينة
  const handleSaveProductPricing = async (product) => {
    const custom = customPricing[product.id] || {};
    const priceYer = custom.customPriceYer 
      ? Number(custom.customPriceYer) 
      : Math.round(((product.seller_price?.amount_cents || 0) / 100) * exchangeRate * 1.15); // تلقائي مع هامش 15%

    setSavingProductId(product.id);
    try {
      const { error } = await supabase
        .from('product_settings')
        .upsert({
          product_id: product.id,
          sku: product.sku,
          custom_price_yer: priceYer,
          custom_price_usd: (priceYer / exchangeRate).toFixed(2),
          stock_quantity: custom.stockQuantity ?? 99,
          is_active: custom.isActive ?? true,
          updated_at: new Date().toISOString()
        });

      if (error) throw error;

      // تحديث الحالة محلياً
      setCustomPricing(prev => ({
        ...prev,
        [product.id]: {
          ...prev[product.id],
          customPriceYer: priceYer,
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
      alert('فشل حفظ سعر المنتج: ' + e.message);
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
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {products.map((product) => {
          const costUsd = (product.seller_price?.amount_cents || 0) / 100;
          const costYer = Math.round(costUsd * exchangeRate);
          const isAvail = product.availability === 'available';

          const custom = customPricing[product.id] || {};
          const currentSellingPriceYer = custom.customPriceYer !== undefined && custom.customPriceYer !== ''
            ? custom.customPriceYer 
            : Math.round(costYer * 1.15); // الافتراضي مع ربح 15%

          const stockQty = custom.stockQuantity ?? 99;
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
                    {/* الكمية المتاحة من المزود */}
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-blue-100 dark:bg-blue-950 text-blue-700 dark:text-blue-300 flex items-center gap-1">
                      <Package className="w-3 h-3" />
                      <span>الكمية: {isAvail ? `${stockQty} متوفر` : 'نفذت'}</span>
                    </span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                      isAvail ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'
                    }`}>
                      {isAvail ? 'جاهز للتسليم' : 'غير متوفر'}
                    </span>
                  </div>
                </div>

                <h4 className="font-bold text-slate-900 dark:text-white text-sm mt-3 line-clamp-2">
                  {product.name}
                </h4>
                <span className="text-xs text-slate-400 font-mono block mt-1">
                  SKU: {product.sku}
                </span>

                {/* سعر التكلفة من المزود */}
                <div className="mt-3 p-3 bg-slate-50 dark:bg-slate-900/60 rounded-xl border border-slate-200 dark:border-slate-700/60 text-xs flex justify-between items-center">
                  <span className="text-slate-500">سعر التكلفة من المزود:</span>
                  <div className="text-left">
                    <span className="font-bold text-slate-800 dark:text-slate-200">${costUsd.toFixed(2)} USD</span>
                    <span className="text-slate-400 block text-[10px]">({costYer.toLocaleString()} ر.ي)</span>
                  </div>
                </div>
              </div>

              {/* قسم تحديد سعر البيع للجمهور بالريال اليمني */}
              <div className="space-y-3 pt-3 border-t border-slate-100 dark:border-slate-700">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1 flex items-center justify-between">
                    <span>سعر البيع للجمهور (بالريال اليمني):</span>
                    <span className="text-[10px] text-emerald-600 font-semibold">
                      الربح: {(currentSellingPriceYer - costYer).toLocaleString()} ر.ي
                    </span>
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      value={currentSellingPriceYer}
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
                      className="w-full pl-12 pr-4 py-2.5 text-sm font-black text-blue-600 dark:text-blue-400 rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 focus:outline-none focus:border-blue-500"
                    />
                    <span className="absolute left-3.5 top-2.5 text-xs font-bold text-slate-400">ر.ي</span>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <div className="flex-1">
                    <label className="block text-[10px] text-slate-400 mb-0.5">الكمية المتاحة:</label>
                    <input
                      type="number"
                      value={stockQty}
                      onChange={(e) => {
                        const val = Number(e.target.value);
                        setCustomPricing(prev => ({
                          ...prev,
                          [product.id]: {
                            ...prev[product.id],
                            stockQuantity: val
                          }
                        }));
                      }}
                      className="w-full px-2.5 py-1.5 text-xs font-bold rounded-lg bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-700 focus:outline-none"
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
    </div>
  );
};
