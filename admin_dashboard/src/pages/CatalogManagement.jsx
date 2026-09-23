import React, { useState } from 'react';
import { 
  Layers, 
  RefreshCw, 
  ExternalLink, 
  CheckCircle2, 
  AlertCircle,
  Tag
} from 'lucide-react';
import { DigitalVaultService } from '../services/digitalVaultService';

export const CatalogManagement = ({ initialProducts = [], onSync }) => {
  const [products, setProducts] = useState(initialProducts);
  const [isSyncing, setIsSyncing] = useState(false);

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

  return (
    <div className="space-y-6">
      {/* رأس الصفحة مع زر المزامنة */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h3 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <Layers className="w-5 h-5 text-blue-600" />
            <span>كتالوج الخدمات والاشتراكات الرقمية</span>
          </h3>
          <p className="text-xs text-slate-500 mt-0.5">
            المنتجات والأسعار المربوطة مباشرة مع Digital Vault Seller API v1
          </p>
        </div>

        <button
          onClick={handleManualSync}
          disabled={isSyncing}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-bold text-xs rounded-xl shadow-md shadow-blue-600/20 transition-all"
        >
          <RefreshCw className={`w-4 h-4 ${isSyncing ? 'animate-spin' : ''}`} />
          <span>مزامنة الكتالوج من المزود</span>
        </button>
      </div>

      {/* بطاقات أو جدول المنتجات */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
        {products.map((product) => {
          const isAvail = product.availability === 'available';
          const priceCents = product.seller_price?.amount_cents || 0;
          const basePriceCents = product.seller_base_price?.amount_cents || 0;
          return (
            <div 
              key={product.id}
              className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex flex-col justify-between"
            >
              <div>
                <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-700">
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
                    ID #{product.id}
                  </span>
                  <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                    isAvail ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'
                  }`}>
                    {isAvail ? 'متوفر للبيع' : 'غير متاح'}
                  </span>
                </div>

                <h4 className="font-bold text-slate-900 dark:text-white text-sm mt-3 line-clamp-2">
                  {product.name}
                </h4>
                <span className="text-xs text-slate-400 font-mono block mt-1">
                  SKU: {product.sku}
                </span>
              </div>

              <div className="mt-5 pt-3 border-t border-slate-100 dark:border-slate-700 flex items-center justify-between">
                <div>
                  <span className="text-[10px] text-slate-400 block">سعر الشراء / التكلفة:</span>
                  <span className="text-xs font-semibold text-slate-500 line-through">
                    ${(basePriceCents / 100).toFixed(2)} USD
                  </span>
                </div>
                <div className="text-left">
                  <span className="text-[10px] text-slate-400 block">سعر البائع:</span>
                  <span className="text-base font-black text-blue-600 dark:text-blue-400">
                    ${(priceCents / 100).toFixed(2)} USD
                  </span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
