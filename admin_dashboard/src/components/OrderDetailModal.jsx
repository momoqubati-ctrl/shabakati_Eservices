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
  ExternalLink,
  PlayCircle,
  Ban,
  ChevronDown,
  ChevronUp,
  FileText,
  Search,
  DollarSign
} from 'lucide-react';
import { supabase } from '../config/supabase';
import { DigitalVaultService } from '../services/digitalVaultService';

export const OrderDetailModal = ({ order, onClose, onOrderUpdated }) => {
  const [currentOrder, setCurrentOrder] = useState(order);
  const [manualKey, setManualKey] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isCheckingStatus, setIsCheckingStatus] = useState(false);
  const [isExecuting, setIsExecuting] = useState(false);
  const [isCancelling, setIsCancelling] = useState(false);
  const [copied, setCopied] = useState(false);
  const [syncMessage, setSyncMessage] = useState(null);

  // استجابة فحص المزود
  const [providerResponse, setProviderResponse] = useState(null);
  const [showRawJson, setShowRawJson] = useState(false);

  // M1: عناصر الطلب (المنتجات المشتراة)
  const [orderItems, setOrderItems] = useState([]);
  const [isLoadingItems, setIsLoadingItems] = useState(true);

  // إمكانية تعديل أو استبدال المفتاح
  const [showEditKey, setShowEditKey] = useState(false);

  // واجهة إلغاء وتفشيل الطلب
  const [showCancelForm, setShowCancelForm] = useState(false);
  const [cancelNote, setCancelNote] = useState(
    () => `تم إلغاء الطلب بناءً على رغبة العميل وتم عكس المبلغ ($${(((order?.total_cents || 0) / 100).toFixed(2))} USD) إلى محفظة العميل الإلكترونية بنجاح.`
  );

  // M1: جلب عناصر الطلب عند فتح النافذة
  React.useEffect(() => {
    const fetchItems = async () => {
      if (!order?.id) { setIsLoadingItems(false); return; }
      try {
        const { data, error } = await supabase
          .from('order_items')
          .select('*')
          .eq('order_id', order.id);
        if (!error && data) setOrderItems(data);
      } catch (_) {}
      setIsLoadingItems(false);
    };
    fetchItems();
  }, [order?.id]);

  React.useEffect(() => {
    if (order) setCurrentOrder(order);
  }, [order]);

  if (!currentOrder) return null;

  // استخراج كافة المفاتيح الرقمية أياً كان شكل التخزين
  const allKeys = Array.isArray(currentOrder.delivered_assets)
    ? currentOrder.delivered_assets.map(a => a?.value || a?.key || (typeof a === 'string' ? a : '')).filter(Boolean)
    : (typeof currentOrder.delivered_assets === 'string' && currentOrder.delivered_assets ? [currentOrder.delivered_assets] : []);
  const existingKey = allKeys.length > 0 ? allKeys[0] : (currentOrder.delivered_assets?.[0]?.value || currentOrder.delivered_assets?.key || '');
  const isReady = currentOrder.fulfillment_status === 'ready' || currentOrder.status === 'completed' || allKeys.length > 0;
  const isFailed = currentOrder.fulfillment_status === 'failed' || currentOrder.status === 'cancelled';

  const handleCopy = (text) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // سحب واستخراج المفتاح الرقمي آلياً من المزود وتعبئته مباشرة في الحقل
  const handleAutoFetchKeyFromProvider = async () => {
    const activeSellerOrderId = currentOrder.seller_order_id;
    if (!activeSellerOrderId) {
      alert('لا يوجد رقم طلب مسجل لدى المزود لهذا الطلب');
      return;
    }
    setIsCheckingStatus(true);
    setSyncMessage('⏳ جاري استخراج وسحب المفتاح الرقمي من المزود آلياً...');
    try {
      let deliveredAssets = null;

      // محاولة 1: عبر خادم الباك إند /api/orders?action=consume_key
      try {
        const apiRes = await fetch(`/api/orders?action=consume_key&seller_order_id=${activeSellerOrderId}`);
        if (apiRes.ok) {
          const apiData = await apiRes.json();
          const rawAssets = apiData?.data?.assets;
          if (Array.isArray(rawAssets) && rawAssets.length > 0) {
            deliveredAssets = rawAssets.map(a => ({
              type: a.type || 'key',
              value: a.value || '',
              ...(a.url ? { url: a.url } : {})
            })).filter(a => a.value);
          }
        }
      } catch (_) {}

      // محاولة 2: عبر الاتصال المباشر بمزود Digital Vault
      if (!deliveredAssets || deliveredAssets.length === 0) {
        const tokenRes = await DigitalVaultService.requestDeliveryAccess(activeSellerOrderId);
        if (tokenRes?.success && tokenRes?.data?.access_token) {
          const consumeRes = await DigitalVaultService.consumeDeliveryAccess(tokenRes.data.access_token);
          const rawAssets = consumeRes?.data?.assets;
          if (Array.isArray(rawAssets) && rawAssets.length > 0) {
            deliveredAssets = rawAssets.map(a => ({
              type: a.type || 'key',
              value: a.value || '',
              ...(a.url ? { url: a.url } : {})
            })).filter(a => a.value);
          }
        }
      }

      if (deliveredAssets && deliveredAssets.length > 0) {
        const keyText = deliveredAssets.map(a => a.value).join('\n');
        setManualKey(keyText); // تعبئة حقل المفتاح آلياً وفوراً

        const updatePayload = {
          fulfillment_status: 'ready',
          status: 'completed',
          delivered_assets: deliveredAssets,
          updated_at: new Date().toISOString()
        };

        try {
          let updateQuery = supabase.from('orders').update(updatePayload);
          if (currentOrder.id) {
            updateQuery = updateQuery.eq('id', currentOrder.id);
          } else if (currentOrder.external_order_id) {
            updateQuery = updateQuery.eq('external_order_id', currentOrder.external_order_id);
          }
          await updateQuery;
        } catch (_) {}

        try {
          await fetch('/api/orders', {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              id: currentOrder.id,
              external_order_id: currentOrder.external_order_id,
              ...updatePayload
            })
          });
        } catch (_) {}

        const updated = {
          ...currentOrder,
          ...updatePayload
        };

        setCurrentOrder(updated);
        setSyncMessage(`✅ تم سحب المفتاح الرقمي بنجاح وتعبئته وتحديث حالة الطلب: ${keyText}`);
        if (onOrderUpdated) onOrderUpdated(updated);
      } else {
        setSyncMessage('⚠️ تم الاتصال بالمزود ولكن لم يتم العثور على مفاتيح جاهزة بعد.');
      }
    } catch (err) {
      setSyncMessage('❌ تعذر سحب المفتاح من المزود: ' + err.message);
    } finally {
      setIsCheckingStatus(false);
    }
  };

  // تسليم الكود وتحديث الطلب يدوياً في Supabase Realtime
  const handleDeliverManualKey = async () => {
    if (!manualKey.trim()) return;
    setIsSubmitting(true);
    try {
      const keys = manualKey
        .split('\n')
        .map(k => k.trim())
        .filter(Boolean);
      const deliveredAssets = keys.map(k => ({ type: 'key', value: k }));

      const updatePayload = {
        fulfillment_status: 'ready',
        status: 'completed',
        delivered_assets: deliveredAssets,
        updated_at: new Date().toISOString()
      };

      try {
        let updateQuery = supabase.from('orders').update(updatePayload);
        if (currentOrder.id) {
          updateQuery = updateQuery.eq('id', currentOrder.id);
        } else if (currentOrder.external_order_id) {
          updateQuery = updateQuery.eq('external_order_id', currentOrder.external_order_id);
        }
        await updateQuery;
      } catch (_) {}

      try {
        await fetch('/api/orders', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: currentOrder.id,
            external_order_id: currentOrder.external_order_id,
            ...updatePayload
          })
        });
      } catch (_) {}

      const updated = {
        ...currentOrder,
        ...updatePayload
      };

      setCurrentOrder(updated);
      setManualKey('');
      setShowEditKey(false);
      setSyncMessage('✅ تم تسليم المفتاح بنجاح وتحديث حالة الطلب إلى (مكتمل) وإشعار العميل فوراً في تطبيقه عبر Realtime!');
      if (onOrderUpdated) onOrderUpdated(updated);
    } catch (err) {
      alert('فشل تحديث الطلب: ' + err.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  // 1. زر فحص حالة العملية لدى المزود والتحديث الآلي الذكي إذا كانت جاهزة
  const handleCheckProviderStatus = async () => {
    setIsCheckingStatus(true);
    setSyncMessage(null);
    setProviderResponse(null);
    try {
      let activeSellerOrderId = currentOrder.seller_order_id;
      let orderData = null;

      if (activeSellerOrderId) {
        orderData = await DigitalVaultService.getSellerOrder(activeSellerOrderId);
      } else {
        // إذا لم يكن رقم المزود مسجلاً، نبحث برقم external_order_id في قائمة طلبات المزود
        const listRes = await DigitalVaultService.getOrders(50);
        let matched = null;
        if (listRes?.success && Array.isArray(listRes?.data)) {
          matched = listRes.data.find(
            o => o.external_order_id === currentOrder.external_order_id
          );
        }

        if (matched) {
          activeSellerOrderId = matched.id;
          orderData = {
            success: true,
            httpStatus: 200,
            data: matched,
            rawText: JSON.stringify(matched, null, 2)
          };
        } else {
          setProviderResponse({
            type: 'not_found_at_provider',
            success: false,
            notCreated: true,
            httpStatus: 404,
            message: 'الطلب غير منشأ لدى مزود الخدمة حتى الآن. العملية حالياً غير منفذة لدى المزود.',
            rawText: JSON.stringify({
              status: 'NOT_FOUND_OR_NOT_CREATED',
              external_order_id: currentOrder.external_order_id,
              fulfillment_status: currentOrder.fulfillment_status,
              order_status: currentOrder.status,
              message: 'الطلب غير مسجل لدى المزود حتى اللحظة، ويمكن تنفيذه عبر زر "تنفيذ العملية لدى المزود" أدناه.'
            }, null, 2)
          });
          return;
        }
      }

      setProviderResponse({
        type: 'order_status',
        sellerOrderId: activeSellerOrderId,
        ...orderData
      });

      // التحقق الذكي والتلقائي: إذا كانت العملية منفذة لدى المزود (ready أو completed)
      const pFulfillment = orderData?.data?.fulfillment_status;
      const pStatus = orderData?.data?.status;
      const isProviderReady = pFulfillment === 'ready' || pStatus === 'completed';

      if (isProviderReady && activeSellerOrderId) {
        let deliveredAssets = currentOrder.delivered_assets;
        let hasKeys = Array.isArray(deliveredAssets) && deliveredAssets.some(a => a?.value || a?.key);

        // إذا لم يكن المفتاح مسحوباً ومحفوظاً لدينا بعد، نقوم بطلب وسحب المفتاح الرقمي من المزود فوراً
        if (!hasKeys) {
          // محاولة 1: عبر الباك إند API
          try {
            const apiRes = await fetch(`/api/orders?action=consume_key&seller_order_id=${activeSellerOrderId}`);
            if (apiRes.ok) {
              const apiData = await apiRes.json();
              const rawAssets = apiData?.data?.assets;
              if (Array.isArray(rawAssets) && rawAssets.length > 0) {
                deliveredAssets = rawAssets.map(a => ({
                  type: a.type || 'key',
                  value: a.value || '',
                  ...(a.url ? { url: a.url } : {})
                })).filter(a => a.value);
                hasKeys = deliveredAssets.length > 0;
              }
            }
          } catch (_) {}

          // محاولة 2: الاتصال المباشر
          if (!hasKeys) {
            try {
              const tokenRes = await DigitalVaultService.requestDeliveryAccess(activeSellerOrderId);
              if (tokenRes?.success && tokenRes?.data?.access_token) {
                const consumeRes = await DigitalVaultService.consumeDeliveryAccess(tokenRes.data.access_token);
                const rawAssets = consumeRes?.data?.assets;
                if (Array.isArray(rawAssets) && rawAssets.length > 0) {
                  deliveredAssets = rawAssets.map(a => ({
                    type: a.type || 'key',
                    value: a.value || '',
                    ...(a.url ? { url: a.url } : {})
                  })).filter(a => a.value);
                  hasKeys = deliveredAssets.length > 0;
                }
              }
            } catch (consumeErr) {
              console.warn('Auto consume delivery on check error:', consumeErr);
            }
          }
        }

        // تحديث قاعدة بيانات Supabase وتغيير حالة الطلب إلى مكتمل وحفظ الأكواد المسحوبة
        const updatePayload = {
          seller_order_id: activeSellerOrderId,
          fulfillment_status: 'ready',
          status: 'completed',
          updated_at: new Date().toISOString()
        };
        if (hasKeys && deliveredAssets) {
          updatePayload.delivered_assets = deliveredAssets;
          const keyText = deliveredAssets.map(a => a.value).join('\n');
          setManualKey(keyText); // تعبئة حقل المفتاح آلياً وفوراً
        }

        try {
          let updateQuery = supabase.from('orders').update(updatePayload);
          if (currentOrder.id) {
            updateQuery = updateQuery.eq('id', currentOrder.id);
          } else if (currentOrder.external_order_id) {
            updateQuery = updateQuery.eq('external_order_id', currentOrder.external_order_id);
          }
          await updateQuery;
        } catch (_) {}

        try {
          await fetch('/api/orders', {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              id: currentOrder.id,
              external_order_id: currentOrder.external_order_id,
              ...updatePayload
            })
          });
        } catch (_) {}

        const updated = {
          ...currentOrder,
          seller_order_id: activeSellerOrderId,
          fulfillment_status: 'ready',
          status: 'completed',
          ...(hasKeys ? { delivered_assets: deliveredAssets } : {})
        };

        setCurrentOrder(updated);

        if (hasKeys) {
          const keysSummary = deliveredAssets.map(a => a.value).join(', ');
          setSyncMessage(`✅ العملية منفذة لدى المزود! تم استخراج وسحب المفتاح الرقمي وتعبئته آلياً وتحديث الطلب بنجاح: ${keysSummary}`);
        } else {
          setSyncMessage(`✅ تم تأكيد تنفيذ العملية لدى المزود، وتم تحديث حالة الطلب إلى (مكتمل). يمكنك الضغط على "سحب وتعبئة المفتاح آلياً" أو إدخاله يدوياً.`);
        }

        if (onOrderUpdated) onOrderUpdated(updated);
      }
    } catch (err) {
      setProviderResponse({
        type: 'error',
        success: false,
        error: err.message || 'تعذر الاستعلام من المزود',
        rawText: String(err)
      });
    } finally {
      setIsCheckingStatus(false);
    }
  };

  // 2. زر تنفيذ العملية لدى المزود (شراء وتفعيل وتسليم المفتاح للعميل)
  const handleExecuteOrder = async () => {
    setIsExecuting(true);
    setSyncMessage(null);
    try {
      let activeSellerOrderId = currentOrder.seller_order_id || providerResponse?.sellerOrderId;

      // أ) إذا لم يكن الطلب منشأ لدى المزود أصلاً، نقوم بإنشائه الآن
      if (!activeSellerOrderId) {
        const { data: items, error: itemsErr } = await supabase
          .from('order_items')
          .select('*')
          .eq('order_id', currentOrder.id);

        if (itemsErr || !items || items.length === 0) {
          throw new Error('لم يتم العثور على عناصر هذا الطلب في قاعدة البيانات لإرسالها لمزود الخدمة');
        }

        const createRes = await DigitalVaultService.createOrder({
          externalOrderId: currentOrder.external_order_id,
          items: items.map(it => ({
            product_id: it.product_id,
            quantity: it.quantity || 1
          }))
        });

        if (!createRes.ok || !createRes.success) {
          const errReason = createRes.error || createRes.rawText || 'رفض المزود إنشاء الطلب';
          setSyncMessage(`❌ تعذر إنشاء الطلب لدى المزود: ${errReason}`);
          setProviderResponse(createRes);
          return;
        }

        activeSellerOrderId = createRes.data?.id;

        // حفظ رقم طلب المزود في Supabase
        await supabase
          .from('orders')
          .update({
            seller_order_id: activeSellerOrderId,
            updated_at: new Date().toISOString()
          })
          .eq('id', currentOrder.id);

        setCurrentOrder(prev => ({ ...prev, seller_order_id: activeSellerOrderId }));
      }

      // ب) فحص حالة الطلب لدى المزود بعد التأكد من وجود activeSellerOrderId
      const orderData = await DigitalVaultService.getSellerOrder(activeSellerOrderId);
      setProviderResponse(orderData);

      // ج) إذا كانت حالة التسليم جاهزة (ready)، نسحب الكود والمفتاح فوراً
      if (orderData?.success && orderData?.data?.fulfillment_status === 'ready') {
        const tokenRes = await DigitalVaultService.requestDeliveryAccess(activeSellerOrderId);
        if (tokenRes?.success && tokenRes?.data?.access_token) {
          const consumeRes = await DigitalVaultService.consumeDeliveryAccess(tokenRes.data.access_token);
          const rawAssets = consumeRes?.data?.assets;
          if (Array.isArray(rawAssets) && rawAssets.length > 0) {
            const deliveredAssets = rawAssets.map(a => ({
              type: a.type || 'key',
              value: a.value || '',
              ...(a.url ? { url: a.url } : {})
            })).filter(a => a.value);

            if (deliveredAssets.length > 0) {
              const execPayload = {
                seller_order_id: activeSellerOrderId,
                fulfillment_status: 'ready',
                status: 'completed',
                delivered_assets: deliveredAssets,
                updated_at: new Date().toISOString()
              };

              try {
                await supabase
                  .from('orders')
                  .update(execPayload)
                  .eq('id', currentOrder.id);
              } catch (_) {}

              try {
                await fetch('/api/orders', {
                  method: 'PATCH',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    id: currentOrder.id,
                    external_order_id: currentOrder.external_order_id,
                    ...execPayload
                  })
                });
              } catch (_) {}

              const updated = {
                ...currentOrder,
                ...execPayload
              };

              setCurrentOrder(updated);

              const keysSummary = deliveredAssets.map(a => a.value).join(', ');
              setSyncMessage(`✅ تم تنفيذ الطلب لدى المزود وسحب المفتاح الرقمي بنجاح (${deliveredAssets.length} عنصر): ${keysSummary}`);
              if (onOrderUpdated) onOrderUpdated(updated);
              return;
            }
          }
        }
      }

      // د) إذا كان الطلب مسجلاً ولكن المزود لم يجهزه بعد (processing)
      const fulfillmentStatus = orderData?.data?.fulfillment_status || 'processing';
      setSyncMessage(`تم ربط وتأكيد الطلب لدى المزود برقم #${activeSellerOrderId}، وحالته الحالية لدى المزود: ${fulfillmentStatus === 'ready' ? 'جاهز للتسليم' : 'قيد المعالجة والتجهيز (خلال 24 ساعة)'}.`);
      if (onOrderUpdated) onOrderUpdated();
    } catch (err) {
      setSyncMessage(`❌ خطأ أثناء تنفيذ الطلب لدى المزود: ${err.message}`);
    } finally {
      setIsExecuting(false);
    }
  };

  // 3. إلغاء وتفشيل العملية وعكس المبلغ لمحفظة العميل
  const handleCancelOrder = async () => {
    if (!cancelNote.trim()) {
      alert('يرجى كتابة سبب الإلغاء وتأكيد عكس المبلغ لمحفظة العميل');
      return;
    }
    setIsCancelling(true);
    setSyncMessage(null);
    try {
      const cancelPayload = {
        fulfillment_status: 'failed',
        status: 'cancelled',
        notes: cancelNote.trim(),
        updated_at: new Date().toISOString()
      };

      try {
        await supabase
          .from('orders')
          .update(cancelPayload)
          .eq('id', currentOrder.id);
      } catch (_) {}

      try {
        await fetch('/api/orders', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: currentOrder.id,
            external_order_id: currentOrder.external_order_id,
            ...cancelPayload
          })
        });
      } catch (_) {}

      // إشعار المزود بالإلغاء إن كان الطلب منشأ لديه
      if (currentOrder.seller_order_id) {
        try {
          await DigitalVaultService.requestCancellation(currentOrder.seller_order_id, cancelNote.trim());
        } catch (_) {}
      }

      const updated = {
        ...currentOrder,
        ...cancelPayload
      };

      setCurrentOrder(updated);

      setShowCancelForm(false);
      setSyncMessage('✅ تم إلغاء وتفشيل العملية بنجاح وتسجيل تأكيد عكس المبلغ. ستظهر الملاحظة فوراً للعميل في التطبيق.');
      if (onOrderUpdated) onOrderUpdated(updated);
    } catch (err) {
      alert('فشل إلغاء الطلب: ' + err.message);
    } finally {
      setIsCancelling(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-sm flex items-center justify-center p-2 sm:p-4">
      <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl sm:rounded-3xl w-full max-w-xl max-h-[92vh] overflow-y-auto shadow-2xl p-4 sm:p-6 space-y-4 sm:space-y-6">
        
        {/* رأس النافذة */}
        <div className="flex items-center justify-between pb-4 border-b border-slate-200 dark:border-slate-800">
          <div>
            <h3 className="text-lg font-bold text-slate-900 dark:text-white flex items-center gap-2">
              <span>تفاصيل الطلب #{currentOrder.external_order_id?.replace('ord_', '')}</span>
            </h3>
            <span className="text-xs text-slate-500">
              تاريخ الإنشاء: {new Date(currentOrder.created_at).toLocaleString('ar-SA')}
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
                : isFailed
                  ? 'bg-rose-100 dark:bg-rose-950 text-rose-700 dark:text-rose-400'
                  : 'bg-amber-100 dark:bg-amber-950 text-amber-700 dark:text-amber-400'
            }`}>
              {isReady && <CheckCircle2 className="w-3.5 h-3.5" />}
              {isFailed && <Ban className="w-3.5 h-3.5" />}
              {!isReady && !isFailed && <Clock className="w-3.5 h-3.5" />}
              {isReady ? 'مكتمل (تم التسليم)' : (isFailed ? 'ملغي / فاشل' : 'قيد المعالجة (خلال 24 ساعة)')}
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3 text-xs pt-2 border-t border-slate-200 dark:border-slate-700">
            <div>
              <span className="text-slate-500 block">المبلغ الإجمالي:</span>
              <span className="font-bold text-slate-900 dark:text-white text-sm">
                ${((currentOrder.total_cents || 0) / 100).toFixed(2)} USD
              </span>
            </div>
            <div>
              <span className="text-slate-500 block">رقم طلب المزود:</span>
              <span className="font-mono text-slate-900 dark:text-white font-bold">
                {currentOrder.seller_order_id ? `#${currentOrder.seller_order_id}` : 'غير متوفر'}
              </span>
            </div>
          </div>

          {/* ملاحظة الإدارة (إن وجدت) */}
          {currentOrder.notes && (
            <div className="pt-2 border-t border-slate-200 dark:border-slate-700">
              <span className="text-xs font-bold text-rose-600 dark:text-rose-400 block mb-1">
                ملاحظة الإدارة والدعم الفني:
              </span>
              <p className="text-xs text-slate-700 dark:text-slate-300 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/50 p-2.5 rounded-xl whitespace-pre-wrap">
                {currentOrder.notes}
              </p>
            </div>
          )}
        </div>

        {/* بيانات العميل والتواصل */}
        <div className="space-y-2 text-xs">
          <h4 className="font-bold text-slate-800 dark:text-slate-200">بيانات العميل:</h4>
          <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-700/50 space-y-2">
            <div className="flex justify-between items-center">
              <span className="text-slate-500">حساب تيليجرام:</span>
              {currentOrder.telegram_user ? (
                <a
                  href={`https://t.me/${currentOrder.telegram_user.replace('@', '')}`}
                  target="_blank"
                  rel="noreferrer"
                  className="font-bold text-blue-600 dark:text-blue-400 hover:underline flex items-center gap-1"
                >
                  <Send className="w-3 h-3" /> @{currentOrder.telegram_user.replace('@', '')}
                </a>
              ) : (
                <span className="text-slate-400">غير مسجل</span>
              )}
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">رقم الهاتف / الواتساب:</span>
              <span className="font-semibold text-slate-800 dark:text-slate-200">
                {currentOrder.contact_phone || 'غير مسجل'}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">معرّف الجهاز (Device ID):</span>
              <span className="font-mono text-slate-400 text-[10px]">
                {currentOrder.device_id || 'غير متوفر'}
              </span>
            </div>
            {currentOrder.payment_id && (
              <div className="flex justify-between pt-1 border-t border-slate-200 dark:border-slate-700">
                <span className="text-slate-500 flex items-center gap-1">
                  <DollarSign className="w-3 h-3" /> رقم عملية الدفع البنكي:
                </span>
                <span className="font-mono font-bold text-emerald-600 dark:text-emerald-400 text-[11px]">
                  {currentOrder.payment_id}
                </span>
              </div>
            )}
          </div>
        </div>

        {/* M1: عناصر الطلب (المنتجات المشتراة) */}
        <div className="space-y-2">
          <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
            <FileText className="w-4 h-4 text-blue-500" />
            <span>عناصر الطلب (الخدمات المشتراة):</span>
          </h4>
          {isLoadingItems ? (
            <div className="p-3 text-center text-xs text-slate-400">جارٍ تحميل عناصر الطلب...</div>
          ) : orderItems.length > 0 ? (
            <div className="rounded-xl border border-slate-200 dark:border-slate-700/50 overflow-hidden">
              <table className="w-full text-xs">
                <thead>
                  <tr className="bg-slate-50 dark:bg-slate-800/60 text-slate-500">
                    <th className="text-right py-2 px-3 font-medium">المنتج</th>
                    <th className="text-center py-2 px-3 font-medium">الكمية</th>
                    <th className="text-left py-2 px-3 font-medium">السعر (USD)</th>
                  </tr>
                </thead>
                <tbody>
                  {orderItems.map((item, idx) => (
                    <tr key={idx} className="border-t border-slate-100 dark:border-slate-800">
                      <td className="py-2 px-3 font-semibold text-slate-800 dark:text-slate-200">
                        {item.product_name || `منتج #${item.product_id}`}
                      </td>
                      <td className="py-2 px-3 text-center text-slate-600 dark:text-slate-300">
                        {item.quantity || 1}
                      </td>
                      <td className="py-2 px-3 text-left font-mono font-bold text-slate-700 dark:text-slate-300">
                        ${((item.unit_price_cents || 0) / 100).toFixed(2)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="p-3 text-center text-xs text-slate-400 bg-slate-50 dark:bg-slate-800/40 rounded-xl">
              لا توجد بيانات عناصر مسجلة لهذا الطلب
            </div>
          )}
        </div>

        {/* بيانات المفتاح المسلم أو إدخال كود جديد */}
        <div className="space-y-3">
          <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
            <Key className="w-4 h-4 text-amber-500" />
            <span>بيانات المفتاح الرقمي / كود التفعيل:</span>
          </h4>

          {allKeys.length > 0 ? (
            <div className="space-y-2">
              {allKeys.length > 1 && (
                <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span className="font-semibold text-emerald-600 dark:text-emerald-400">
                    تم استلام {allKeys.length} مفاتيح / أكواد رقمية:
                  </span>
                  <button
                    onClick={() => handleCopy(allKeys.join('\n'))}
                    className="text-blue-600 dark:text-blue-400 hover:underline flex items-center gap-1 text-[11px]"
                  >
                    <Copy className="w-3 h-3" /> نسخ كافة الأكواد
                  </button>
                </div>
              )}

              {allKeys.map((k, index) => {
                const isUrl = typeof k === 'string' && (k.startsWith('http://') || k.startsWith('https://'));
                return (
                  <div key={index} className="p-3 bg-slate-950 rounded-xl border border-slate-800 flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2 overflow-hidden">
                      {allKeys.length > 1 && (
                        <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-slate-800 text-slate-400">
                          #{index + 1}
                        </span>
                      )}
                      <span className="font-mono text-xs text-emerald-400 font-bold break-all select-all">
                        {k}
                      </span>
                    </div>
                    <div className="flex items-center gap-1 shrink-0">
                      {isUrl && (
                        <a
                          href={k}
                          target="_blank"
                          rel="noreferrer"
                          className="p-1.5 text-blue-400 hover:text-blue-300 rounded-lg transition-colors"
                          title="فتح في المتصفح"
                        >
                          <ExternalLink className="w-3.5 h-3.5" />
                        </a>
                      )}
                      <button
                        onClick={() => handleCopy(k)}
                        className="p-1.5 text-slate-400 hover:text-white rounded-lg transition-colors"
                        title="نسخ"
                      >
                        <Copy className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                );
              })}

              {!isFailed && !showEditKey && (
                <div className="pt-1">
                  <button
                    onClick={() => {
                      setManualKey(allKeys.join('\n'));
                      setShowEditKey(true);
                    }}
                    className="text-[11px] text-blue-600 dark:text-blue-400 hover:underline flex items-center gap-1"
                  >
                    <span>تعديل أو استبدال المفتاح المسلّم</span>
                  </button>
                </div>
              )}
            </div>
          ) : null}

          {(!existingKey || showEditKey) && !isFailed && (
            <div className="space-y-3 pt-1">
              <div className="flex items-center justify-between">
                {showEditKey ? (
                  <div className="flex items-center justify-between text-xs text-amber-600 dark:text-amber-400 w-full">
                    <span>تعديل كود التفعيل (سيتم استبدال الكود الحالي):</span>
                    <button
                      onClick={() => setShowEditKey(false)}
                      className="text-slate-400 hover:text-slate-200"
                    >
                      إلغاء التعديل
                    </button>
                  </div>
                ) : (
                  <>
                    <span className="text-xs text-slate-500">حقل كود / رابط التفعيل للعميل:</span>
                    {currentOrder.seller_order_id && (
                      <button
                        type="button"
                        onClick={handleAutoFetchKeyFromProvider}
                        disabled={isCheckingStatus}
                        className="text-[11px] text-blue-600 dark:text-blue-400 hover:text-blue-700 dark:hover:text-blue-300 font-bold flex items-center gap-1.5 py-1 px-2.5 rounded-lg bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-900 transition-colors"
                      >
                        <RefreshCw className={`w-3 h-3 ${isCheckingStatus ? 'animate-spin' : ''}`} />
                        <span>سحب وتعبئة المفتاح آلياً من المزود</span>
                      </button>
                    )}
                  </>
                )}
              </div>
              <textarea
                value={manualKey}
                onChange={(e) => setManualKey(e.target.value)}
                placeholder="أدخل كود التفعيل أو مفتاح الترخيص أو بيانات الحساب المسلم هنا (سطر لكل كود إن وُجد أكثر من كود)..."
                rows={3}
                className="w-full text-xs p-3 rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white focus:outline-none focus:border-blue-500 font-mono"
              />
              <button
                onClick={handleDeliverManualKey}
                disabled={isSubmitting || !manualKey.trim()}
                className="w-full py-2.5 bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-2 shadow-lg shadow-blue-600/20"
              >
                <CheckCircle2 className="w-4 h-4" />
                <span>{existingKey ? 'تحديث المفتاح وإشعار العميل عبر Realtime' : 'تسليم المفتاح وإشعار العميل عبر Realtime'}</span>
              </button>
            </div>
          )}
        </div>

        {/* قسم إدارة الطلب مع مزود الخدمة (Digital Vault) */}
        {(!isReady || allKeys.length === 0) && !isFailed && (
          <div className="pt-3 border-t border-slate-200 dark:border-slate-800 space-y-3">
            <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
              <RefreshCw className="w-4 h-4 text-blue-500" />
              <span>إجراءات مزود الخدمة (Digital Vault):</span>
            </h4>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5">
              {/* 1. زر فحص حالة العملية فقط لدى المزود (يرجع نص الاستجابة الحقيقي) */}
              <button
                onClick={handleCheckProviderStatus}
                disabled={isCheckingStatus || isExecuting}
                className="py-2.5 px-3 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-750 text-slate-800 dark:text-slate-200 font-bold rounded-xl text-xs flex items-center justify-center gap-2 border border-slate-300 dark:border-slate-700 transition-colors"
                title="فحص حالة العملية لدى المزود دون تنفيذ أي إجراء"
              >
                <Search className={`w-3.5 h-3.5 ${isCheckingStatus ? 'animate-spin' : ''}`} />
                <span>فحص حالة العملية لدى المزود</span>
              </button>

              {/* 2. زر تنفيذ العملية لدى المزود */}
              <button
                onClick={handleExecuteOrder}
                disabled={isExecuting || isCheckingStatus}
                className="py-2.5 px-3 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-2 shadow-sm transition-colors disabled:opacity-50"
                title="تنفيذ الطلب لدى المزود وسحب المفتاح وتسليمه للعميل فوراً"
              >
                <PlayCircle className={`w-3.5 h-3.5 ${isExecuting ? 'animate-spin' : ''}`} />
                <span>تنفيذ العملية لدى المزود</span>
              </button>
            </div>

            {/* عرض استجابة المزود الحقيقية (Real Provider Response) */}
            {providerResponse && (
              <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-700 text-xs space-y-2">
                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                  <span className="font-bold text-slate-200 flex items-center gap-1.5">
                    <FileText className="w-3.5 h-3.5 text-blue-400" />
                    استجابة المزود الحقيقية:
                  </span>
                  <span className={`px-2 py-0.5 rounded text-[10px] font-mono font-bold ${
                    providerResponse.success
                      ? 'bg-emerald-950 text-emerald-400 border border-emerald-800'
                      : 'bg-amber-950 text-amber-400 border border-amber-800'
                  }`}>
                    {providerResponse.httpStatus ? `HTTP ${providerResponse.httpStatus}` : (providerResponse.success ? 'Success' : 'Alert')}
                  </span>
                </div>

                {/* تفاصيل مبسطة ومقروءة من الرد الحقيقي */}
                {providerResponse.data && (
                  <div className="grid grid-cols-2 gap-2 text-[11px] text-slate-300 py-1">
                    <div>
                      <span className="text-slate-500">حالة الطلب لدى المزود: </span>
                      <span className="font-mono font-bold text-white">
                        {providerResponse.data.status || 'غير محدد'}
                      </span>
                    </div>
                    <div>
                      <span className="text-slate-500">حالة التسليم: </span>
                      <span className={`font-mono font-bold ${
                        providerResponse.data.fulfillment_status === 'ready' ? 'text-emerald-400' : 'text-amber-400'
                      }`}>
                        {providerResponse.data.fulfillment_status || 'غير محدد'}
                      </span>
                    </div>
                    {providerResponse.data.total && (
                      <div>
                        <span className="text-slate-500">المبلغ لدى المزود: </span>
                        <span className="font-bold text-white">
                          ${(providerResponse.data.total.amount_cents / 100).toFixed(2)} {providerResponse.data.total.currency}
                        </span>
                      </div>
                    )}
                    {providerResponse.data.id && (
                      <div>
                        <span className="text-slate-500">رقم طلب المزود: </span>
                        <span className="font-mono font-bold text-blue-400">
                          #{providerResponse.data.id}
                        </span>
                      </div>
                    )}
                  </div>
                )}

                {/* رسالة الخطأ أو التنبيه الحقيقية */}
                {(providerResponse.error || providerResponse.message) && (
                  <div className="text-[11px] text-amber-300 bg-amber-950/40 p-2 rounded-lg border border-amber-900/50">
                    {providerResponse.error || providerResponse.message}
                  </div>
                )}

                {/* زر إظهار/إخفاء نص JSON الخام الكامل */}
                {providerResponse.rawText && (
                  <div className="pt-1">
                    <button
                      onClick={() => setShowRawJson(prev => !prev)}
                      className="text-[10px] text-slate-400 hover:text-slate-200 flex items-center gap-1 font-mono"
                    >
                      {showRawJson ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                      <span>{showRawJson ? 'إخفاء النص الخام للاستجابة' : 'عرض نص الاستجابة الكامل (Raw JSON)'}</span>
                    </button>
                    {showRawJson && (
                      <pre className="mt-2 text-[10px] font-mono p-2.5 bg-black/60 text-slate-300 rounded-lg overflow-x-auto max-h-40 border border-slate-800 break-all whitespace-pre-wrap">
                        {providerResponse.rawText}
                      </pre>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* 3. زر إلغاء العملية وتفشيلها وعكس المبلغ للعميل */}
        {!isReady && !isFailed && (
          <div className="pt-2 border-t border-slate-200 dark:border-slate-800">
            {!showCancelForm ? (
              <button
                onClick={() => setShowCancelForm(true)}
                className="w-full py-2 bg-rose-50 dark:bg-rose-950/40 hover:bg-rose-100 dark:hover:bg-rose-900/40 text-rose-600 dark:text-rose-400 font-bold rounded-xl text-xs flex items-center justify-center gap-2 border border-rose-200 dark:border-rose-900/60 transition-colors"
              >
                <Ban className="w-3.5 h-3.5" />
                <span>إلغاء العملية وعكس المبلغ لمحفظة العميل</span>
              </button>
            ) : (
              <div className="p-4 rounded-2xl bg-rose-50 dark:bg-rose-950/50 border border-rose-200 dark:border-rose-900/60 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-rose-700 dark:text-rose-300 flex items-center gap-1.5">
                    <AlertCircle className="w-4 h-4 text-rose-500" />
                    تأكيد إلغاء وتفشيل العملية:
                  </span>
                  <button
                    onClick={() => setShowCancelForm(false)}
                    className="text-xs text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
                  >
                    تراجع
                  </button>
                </div>

                <p className="text-[11px] text-rose-600/90 dark:text-rose-400 leading-relaxed">
                  عند الإلغاء، ستتحول حالة الطلب فوراً إلى فاشل، ويتم إشعار العميل عبر Realtime. يرجى تأكيد عكس المبلغ يدوياً وتوثيق ذلك في الملاحظة أدناه لتظهر في تطبيق العميل:
                </p>

                <div>
                  <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300 block mb-1">
                    ملاحظة التفشيل وتأكيد عكس المبلغ (تظهر للعميل في التطبيق):
                  </label>
                  <textarea
                    value={cancelNote}
                    onChange={(e) => setCancelNote(e.target.value)}
                    rows={3}
                    placeholder="اكتب سبب الإلغاء وتأكيد عكس المبلغ لمحفظة العميل هنا..."
                    className="w-full text-xs p-2.5 rounded-xl bg-white dark:bg-slate-900 border border-rose-200 dark:border-rose-900/80 text-slate-900 dark:text-white focus:outline-none focus:border-rose-500"
                  />
                </div>

                <div className="flex gap-2">
                  <button
                    onClick={handleCancelOrder}
                    disabled={isCancelling || !cancelNote.trim()}
                    className="flex-1 py-2 bg-rose-600 hover:bg-rose-700 disabled:opacity-50 text-white font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 shadow-sm"
                  >
                    <Ban className={`w-3.5 h-3.5 ${isCancelling ? 'animate-spin' : ''}`} />
                    <span>تأكيد إلغاء وتفشيل العملية</span>
                  </button>
                  <button
                    onClick={() => setShowCancelForm(false)}
                    className="px-4 py-2 bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-300 font-bold rounded-xl text-xs"
                  >
                    إلغاء
                  </button>
                </div>
              </div>
            )}
          </div>
        )}

        {/* رسائل التنبيه والنجاح */}
        {syncMessage && (
          <div className="p-3 bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-800 rounded-xl text-xs text-blue-700 dark:text-blue-300 leading-relaxed">
            {syncMessage}
          </div>
        )}
      </div>
    </div>
  );
};
