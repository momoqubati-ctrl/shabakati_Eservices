import React, { useState } from 'react';
import { 
  Search, 
  Filter, 
  Clock, 
  CheckCircle2, 
  Send, 
  Key, 
  ChevronLeft,
  ChevronRight
} from 'lucide-react';

export const OrdersManagement = ({ orders = [], onSelectOrder }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all'); // all, processing, ready

  const filteredOrders = orders.filter((order) => {
    // فلتر الحالة
    if (statusFilter === 'processing') {
      if (order.fulfillment_status === 'ready' || order.status === 'completed') return false;
    } else if (statusFilter === 'ready') {
      if (order.fulfillment_status !== 'ready' && order.status !== 'completed') return false;
    }

    // فلتر البحث
    if (!searchTerm.trim()) return true;
    const term = searchTerm.toLowerCase();
    const idMatch = order.external_order_id?.toLowerCase().includes(term);
    const tgMatch = order.telegram_user?.toLowerCase().includes(term);
    const phoneMatch = order.contact_phone?.toLowerCase().includes(term);
    const deviceMatch = order.device_id?.toLowerCase().includes(term);
    return idMatch || tgMatch || phoneMatch || deviceMatch;
  });

  return (
    <div className="space-y-6">
      {/* شريط البحث والفلترة */}
      <div className="bg-white dark:bg-slate-800 p-4 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex flex-col md:flex-row gap-4 justify-between items-center">
        {/* حقل البحث */}
        <div className="relative w-full md:w-96">
          <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3.5" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="ابحث برقم الطلب، يوزر تيليجرام، أو الهاتف..."
            className="w-full pl-4 pr-10 py-2.5 text-xs rounded-xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white focus:outline-none focus:border-blue-500"
          />
        </div>

        {/* أزرار الفلترة السريعة */}
        <div className="flex items-center gap-2 w-full md:w-auto overflow-x-auto">
          <button
            onClick={() => setStatusFilter('all')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-colors ${
              statusFilter === 'all'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200'
            }`}
          >
            جميع الطلبات ({orders.length})
          </button>
          <button
            onClick={() => setStatusFilter('processing')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-colors flex items-center gap-1.5 ${
              statusFilter === 'processing'
                ? 'bg-amber-600 text-white shadow-sm'
                : 'bg-slate-100 dark:bg-slate-700 text-amber-600 dark:text-amber-400 hover:bg-slate-200'
            }`}
          >
            <Clock className="w-3.5 h-3.5" />
            <span>قيد المعالجة (خلال 24 ساعة)</span>
          </button>
          <button
            onClick={() => setStatusFilter('ready')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-colors flex items-center gap-1.5 ${
              statusFilter === 'ready'
                ? 'bg-emerald-600 text-white shadow-sm'
                : 'bg-slate-100 dark:bg-slate-700 text-emerald-600 dark:text-emerald-400 hover:bg-slate-200'
            }`}
          >
            <CheckCircle2 className="w-3.5 h-3.5" />
            <span>المكتملة والمسلّمة</span>
          </button>
        </div>
      </div>

      {/* جدول الطلبات الشامل */}
      <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-right text-xs">
            <thead className="bg-slate-50 dark:bg-slate-900 text-slate-500 font-semibold border-b border-slate-200 dark:border-slate-700">
              <tr>
                <th className="p-4">رقم الطلب</th>
                <th className="p-4">تاريخ الطلب</th>
                <th className="p-4">العميل / التواصل</th>
                <th className="p-4">المبلغ</th>
                <th className="p-4">حالة التنفيذ</th>
                <th className="p-4">المفتاح المسلم</th>
                <th className="p-4 text-center">الإجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-700/60">
              {filteredOrders.map((order) => {
                const isReady = order.fulfillment_status === 'ready' || order.status === 'completed';
                const hasKey = order.delivered_assets && order.delivered_assets.length > 0;
                return (
                  <tr key={order.id} className="hover:bg-slate-50/60 dark:hover:bg-slate-750/50 transition-colors">
                    <td className="p-4 font-mono font-bold text-blue-600 dark:text-blue-400">
                      #{order.external_order_id?.replace('ord_', '')}
                    </td>
                    <td className="p-4 text-slate-500">
                      {new Date(order.created_at).toLocaleDateString('ar-SA', {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </td>
                    <td className="p-4">
                      {order.telegram_user ? (
                        <span className="font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1">
                          <Send className="w-3 h-3 text-[#229ED9]" /> @{order.telegram_user.replace('@', '')}
                        </span>
                      ) : (
                        <span className="text-slate-500">{order.contact_phone || 'تطبيق الموبايل'}</span>
                      )}
                    </td>
                    <td className="p-4 font-extrabold text-slate-900 dark:text-white">
                      ${((order.total_cents || 0) / 100).toFixed(2)} USD
                    </td>
                    <td className="p-4">
                      <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold inline-flex items-center gap-1 ${
                        isReady 
                          ? 'bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-400' 
                          : 'bg-amber-100 dark:bg-amber-950 text-amber-700 dark:text-amber-400'
                      }`}>
                        {isReady ? <CheckCircle2 className="w-3 h-3" /> : <Clock className="w-3 h-3" />}
                        {isReady ? 'مكتمل (جاهز)' : 'قيد المعالجة (24 ساعة)'}
                      </span>
                    </td>
                    <td className="p-4 font-mono text-xs">
                      {hasKey ? (
                        <span className="text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1">
                          <Key className="w-3 h-3" /> تم التسليم
                        </span>
                      ) : (
                        <span className="text-amber-600 dark:text-amber-500">⏳ لم يسلّم بعد</span>
                      )}
                    </td>
                    <td className="p-4 text-center">
                      <button
                        onClick={() => onSelectOrder(order)}
                        className="px-3.5 py-1.5 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold shadow-sm transition-all"
                      >
                        معاينة وتفعيل
                      </button>
                    </td>
                  </tr>
                );
              })}
              {filteredOrders.length === 0 && (
                <tr>
                  <td colSpan="7" className="p-12 text-center text-slate-400">
                    لم يتم العثور على أي طلبات مطابقة للفلترة أو البحث.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
