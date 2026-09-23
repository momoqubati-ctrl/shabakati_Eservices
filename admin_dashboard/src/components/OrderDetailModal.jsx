import React, { useState } from 'react';
import { 
  X, 
  Send, 
  Key, 
  CheckCircle2, 
  Clock, 
  AlertCircle, 
  Copy, 
  Check, 
  RefreshCw,
  ExternalLink
} from 'lucide-react';
import { supabase } from '../config/supabase';
import { DigitalVaultService } from '../services/digitalVaultService';

export const OrderDetailModal = ({ order, onClose, onOrderUpdated }) => {
  const [manualKey, setManualKey] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [copied, setCopied] = useState(false);
  const [syncMessage, setSyncMessage] = useState(null);

  if (!order) return null;

  const isReady = order.fulfillment_status === 'ready' || order.status === 'completed';
  const existingKey = order.delivered_assets?.[0]?.value || order.delivered_assets?.key || '';

  const handleCopy = (text) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // تسليم الكود وتحديث الطلب يدوياً في Supabase Realtime
  const handleDeliverManualKey = async () => {
    if (!manualKey.trim()) return;
    setIsSubmitting(true);
    try {
      const { error } = await supabase
        .from('orders')
        .update({
          fulfillment_status: 'ready',
          status: 'completed',
          delivered_assets: [{ type: 'key', value: manualKey.trim() }],
          updated_at: new Date().toISOString()
        })
        .eq('id', order.id);

      if (error) throw error;
      setSyncMessage('تم تسليم المفتاح بنجاح وسيتلقاه العميل فوراً عبر Realtime!');
      if (onOrderUpdated) onOrderUpdated();
    } catch (err) {
      alert('فشل تحديث الطلب: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  // فحص حالة الطلب لدى Digital Vault ومحاولة استهلاك المفتاح تلقائياً
  const handleSyncWithDigitalVault = async () => {
    if (!order.seller_order_id) {
      alert('هذا الطلب غير مرتبط برقم طلب لدى Digital Vault');
      return;
    }
    setIsSubmitting(true);
    setSyncMessage(null);
    try {
      const orderData = await DigitalVaultService.getSellerOrder(order.seller_order_id);
      if (orderData?.success && orderData?.data?.fulfillment_status === 'ready') {
        // استخراج كود التسليم
        const tokenRes = await DigitalVaultService.requestDeliveryAccess(order.seller_order_id);
        if (tokenRes?.success && tokenRes?.data?.access_token) {
          const consumeRes = await DigitalVaultService.consumeDeliveryAccess(tokenRes.data.access_token);
          const asset = consumeRes?.data?.assets?.[0];
          if (asset?.value) {
            await supabase
              .from('orders')
              .update({
                fulfillment_status: 'ready',
                status: 'completed',
                delivered_assets: [{ type: 'key', value: asset.value }],
                updated_at: new Date().toISOString()
              })
              .eq('id', order.id);
            setSyncMessage(`تم سحب المفتاح التلقائي من المزود بنجاح: ${asset.value}`);
            if (onOrderUpdated) onOrderUpdated();
            return;
          }
        }
      }
      setSyncMessage('الطلب ما زال قيد المعالجة والتجهيز لدى مزود Digital Vault (خلال 24 ساعة).');
    } catch (err) {
      setSyncMessage('تعذر الاستعلام من المزود: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl w-full max-w-xl max-h-[90vh] overflow-y-auto shadow-2xl p-6 space-y-6">
        {/* رأس النافذة */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-200 dark:border-slate-800">
          <div>
            <h3 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <span>تفاصيل الطلب #{order.external_order_id?.replace('ord_', '')}</span>
            </h3>
            <span className="text-xs text-slate-500">
              تاريخ الإنشاء: {new Date(order.created_at).toLocaleString('ar-SA')}
            </span>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-slate-200 hover:bg-slate-800 rounded-full transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* حالة الطلب */}
        <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs text-slate-500">حالة التنفيذ والتسليم:</span>
            <span className={`px-3 py-1 rounded-full text-xs font-bold inline-flex items-center gap-1.5 ${
              isReady 
                ? 'bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-400' 
                : 'bg-amber-100 dark:bg-amber-950 text-amber-700 dark:text-amber-400'
            }`}>
              {isReady ? <CheckCircle2 className="w-3.5 h-3.5" /> : <Clock className="w-3.5 h-3.5" />}
              {isReady ? 'مكتمل (تم التسليم)' : 'قيد المعالجة (خلال 24 ساعة)'}
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs pt-2 border-t border-slate-200 dark:border-slate-700">
            <div>
              <span className="text-slate-500 block">المبلغ الإجمالي:</span>
              <span className="font-bold text-slate-900 dark:text-white text-sm">
                ${((order.total_cents || 0) / 100).toFixed(2)} USD
              </span>
            </div>
            <div>
              <span className="text-slate-500 block">رقم طلب المزود:</span>
              <span className="font-mono text-slate-900 dark:text-white font-bold">
                {order.seller_order_id ? `#${order.seller_order_id}` : 'غير متوفر'}
              </span>
            </div>
          </div>
        </div>

        {/* بيانات العميل والتواصل */}
        <div className="space-y-2 text-xs">
          <h4 className="font-bold text-slate-800 dark:text-slate-200">بيانات العميل:</h4>
          <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-700/50 space-y-2">
            <div className="flex justify-between items-center">
              <span className="text-slate-500">حساب تيليجرام:</span>
              {order.telegram_user ? (
                <a
                  href={`https://t.me/${order.telegram_user.replace('@', '')}`}
                  target="_blank"
                  rel="noreferrer"
                  className="font-bold text-blue-600 dark:text-blue-400 hover:underline flex items-center gap-1"
                >
                  <Send className="w-3 h-3" /> @{order.telegram_user.replace('@', '')}
                </a>
              ) : (
                <span className="text-slate-400">غير مسجل</span>
              )}
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">رقم الهاتف / الواتساب:</span>
              <span className="font-semibold text-slate-800 dark:text-slate-200">
                {order.contact_phone || 'غير مسجل'}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">معرّف الجهاز (Device ID):</span>
              <span className="font-mono text-slate-400 text-[10px]">
                {order.device_id || 'غير متوفر'}
              </span>
            </div>
          </div>
        </div>

        {/* المفتاح المسلم أو إدخال كود جديد */}
        <div className="space-y-3">
          <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
            <Key className="w-4 h-4 text-amber-500" />
            <span>بيانات المفتاح الرقمي / كود التفعيل:</span>
          </h4>

          {existingKey ? (
            <div className="p-3.5 bg-slate-950 rounded-xl border border-slate-800 flex items-center justify-between">
              <span className="font-mono text-xs text-emerald-400 font-bold break-all">
                {existingKey}
              </span>
              <button
                onClick={() => handleCopy(existingKey)}
                className="p-2 text-slate-400 hover:text-white rounded-lg transition-colors"
                title="نسخ"
              >
                {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
              </button>
            </div>
          ) : (
            <div className="space-y-3">
              <textarea
                value={manualKey}
                onChange={(e) => setManualKey(e.target.value)}
                placeholder="أدخل كود التفعيل أو مفتاح الترخيص أو بيانات الحساب المسلم هنا..."
                rows={3}
                className="w-full text-xs p-3 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white focus:outline-none focus:border-blue-500"
              />
              <button
                onClick={handleDeliverManualKey}
                disabled={isSubmitting || !manualKey.trim()}
                className="w-full py-2.5 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-blue-600/20"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>تسليم المفتاح وإشعار العميل عبر Realtime</span>
              </button>
            </div>
          )}

          {/* فحص المزود التلقائي */}
          {order.seller_order_id && !existingKey && (
            <button
              onClick={handleSyncWithDigitalVault}
              disabled={isSubmitting}
              className="w-full py-2 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-750 text-slate-700 dark:text-slate-300 font-bold rounded-xl text-xs flex items-center justify-center gap-2 border border-slate-200 dark:border-slate-700"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isSubmitting ? 'animate-spin' : ''}`} />
              <span>فحص جاهزية التسليم الآلي لدى Digital Vault</span>
            </button>
          )}

          {syncMessage && (
            <div className="p-3 bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-800 rounded-xl text-xs text-blue-700 dark:text-blue-300">
              {syncMessage}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
