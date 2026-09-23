import React from 'react';
import { 
  DollarSign, 
  ShoppingBag, 
  Clock, 
  CheckCircle2, 
  AlertCircle, 
  TrendingUp, 
  UserCheck 
} from 'lucide-react';
import { ResponsiveContainer, AreaChart, Area, XAxis, YAxis, Tooltip, CartesianGrid } from 'recharts';

export const DashboardOverview = ({ 
  orders = [], 
  sellerProfile = null, 
  onSelectOrder 
}) => {
  // حساب الإحصائيات العامة
  const totalRevenueCents = orders.reduce((sum, o) => sum + (o.total_cents || 0), 0);
  const totalOrdersCount = orders.length;
  const pendingOrders = orders.filter(o => o.fulfillment_status === 'processing' || o.status === 'paid');
  const completedOrders = orders.filter(o => o.fulfillment_status === 'ready' || o.status === 'completed');

  // تحضير بيانات الرسم البياني
  const chartData = [
    { day: 'السبت', sales: Math.round(totalRevenueCents * 0.12 / 100) },
    { day: 'الأحد', sales: Math.round(totalRevenueCents * 0.18 / 100) },
    { day: 'الإثنين', sales: Math.round(totalRevenueCents * 0.15 / 100) },
    { day: 'الثلاثاء', sales: Math.round(totalRevenueCents * 0.22 / 100) },
    { day: 'الأربعاء', sales: Math.round(totalRevenueCents * 0.33 / 100) },
  ];

  return (
    <div className="space-y-6">
      {/* بطاقات المؤشرات الأساسية */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        {/* إجمالي المبيعات */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">إجمالي الإيرادات</span>
            <h3 className="text-2xl font-black text-slate-900 dark:text-white mt-1">
              ${(totalRevenueCents / 100).toFixed(2)} <span className="text-xs font-normal text-slate-500">USD</span>
            </h3>
            <span className="text-[11px] text-emerald-600 font-semibold flex items-center gap-1 mt-1">
              <TrendingUp className="w-3.5 h-3.5" /> +14.8% مقارنة بالأسبوع الماضي
            </span>
          </div>
          <div className="p-3 bg-blue-50 dark:bg-blue-950/60 rounded-xl text-blue-600 dark:text-blue-400">
            <DollarSign className="w-6 h-6" />
          </div>
        </div>

        {/* إجمالي الطلبات */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">إجمالي عدد الطلبات</span>
            <h3 className="text-2xl font-black text-slate-900 dark:text-white mt-1">
              {totalOrdersCount}
            </h3>
            <span className="text-[11px] text-slate-500 mt-1 block">طلبات التطبيق وتيليجرام</span>
          </div>
          <div className="p-3 bg-purple-50 dark:bg-purple-950/60 rounded-xl text-purple-600 dark:text-purple-400">
            <ShoppingBag className="w-6 h-6" />
          </div>
        </div>

        {/* طلبات قيد المعالجة (خلال 24 ساعة) */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">قيد المعالجة (خلال 24 ساعة)</span>
            <h3 className="text-2xl font-black text-amber-600 dark:text-amber-400 mt-1">
              {pendingOrders.length}
            </h3>
            <span className="text-[11px] text-amber-700 dark:text-amber-500 font-medium mt-1 block">تتطلب تفعيل أو تسليم يدوي/آلي</span>
          </div>
          <div className="p-3 bg-amber-50 dark:bg-amber-950/60 rounded-xl text-amber-600 dark:text-amber-400">
            <Clock className="w-6 h-6" />
          </div>
        </div>

        {/* الطلبات المكتملة */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm flex items-center justify-between">
          <div>
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400">الطلبات المسلمة بنجاح</span>
            <h3 className="text-2xl font-black text-emerald-600 dark:text-emerald-400 mt-1">
              {completedOrders.length}
            </h3>
            <span className="text-[11px] text-emerald-600 font-medium mt-1 block">تم تسليم المفاتيح الرقمية</span>
          </div>
          <div className="p-3 bg-emerald-50 dark:bg-emerald-950/60 rounded-xl text-emerald-600 dark:text-emerald-400">
            <CheckCircle2 className="w-6 h-6" />
          </div>
        </div>
      </div>

      {/* قسم المخطط البياني وحالة المزود */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* المخطط البياني للمبيعات */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-800 p-6 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h4 className="text-base font-bold text-slate-900 dark:text-white">حركة المبيعات والعمليات</h4>
              <p className="text-xs text-slate-500">حجم الإيرادات المسجلة بالدولار الأمريكي</p>
            </div>
          </div>
          <div className="h-64 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="colorSales" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2563EB" stopOpacity={0.4}/>
                    <stop offset="95%" stopColor="#2563EB" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#334155" opacity={0.2} />
                <XAxis dataKey="day" stroke="#94A3B8" fontSize={12} tickLine={false} />
                <YAxis stroke="#94A3B8" fontSize={12} tickLine={false} unit="$" />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#0F172A', borderRadius: '12px', border: '1px solid #334155', color: '#fff' }}
                  formatter={(val) => [`$${val} USD`, 'الإيراد']}
                />
                <Area type="monotone" dataKey="sales" stroke="#2563EB" strokeWidth={3} fillOpacity={1} fill="url(#colorSales)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* بيانات حساب المزود والاعتمادات */}
        <div className="bg-white dark:bg-slate-800 p-6 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm space-y-4">
          <div className="flex items-center gap-3 pb-3 border-b border-slate-200 dark:border-slate-700">
            <div className="p-2 bg-blue-100 dark:bg-blue-950/80 text-blue-600 rounded-lg">
              <UserCheck className="w-5 h-5" />
            </div>
            <div>
              <h4 className="text-sm font-bold text-slate-900 dark:text-white">ملف البائع (Seller Profile)</h4>
              <span className="text-xs text-slate-500">معلومات الاعتماد لدى Digital Vault</span>
            </div>
          </div>

          <div className="space-y-3 text-xs">
            <div className="flex justify-between py-1.5 border-b border-slate-100 dark:border-slate-700/50">
              <span className="text-slate-500">اسم المتجر / البائع:</span>
              <span className="font-bold text-slate-800 dark:text-slate-200">
                {sellerProfile?.name || 'Sahm (Seller)'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-slate-100 dark:border-slate-700/50">
              <span className="text-slate-500">كود البائع (Seller Code):</span>
              <span className="font-mono text-slate-800 dark:text-slate-200">
                {sellerProfile?.code || 'seller-285'}
              </span>
            </div>
            <div className="flex justify-between py-1.5 border-b border-slate-100 dark:border-slate-700/50">
              <span className="text-slate-500">حالة الحساب:</span>
              <span className="px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-400 font-bold">
                {sellerProfile?.status || 'Active (نشط)'}
              </span>
            </div>
            <div className="flex justify-between py-1.5">
              <span className="text-slate-500">العملة الافتراضية:</span>
              <span className="font-bold text-slate-800 dark:text-slate-200">
                {sellerProfile?.currency || 'USD'}
              </span>
            </div>
          </div>

          <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-700 text-[11px] text-slate-600 dark:text-slate-400 leading-relaxed">
            💡 يتم استهلاك رصيد محفظة المزود تلقائياً عند تسليم التراخيص الرقمية الفورية، ويمكن إعادة شحن الرصيد من لوحة المزود الرئيسية.
          </div>
        </div>
      </div>

      {/* أحدث الطلبات المستلمة */}
      <div className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700/80 shadow-sm overflow-hidden">
        <div className="p-5 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between">
          <h4 className="font-bold text-slate-900 dark:text-white">أحدث طلبات الاشتراكات الواردة</h4>
          <span className="text-xs text-slate-500">محدثة لحظياً عبر Realtime</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-right text-xs">
            <thead className="bg-slate-50 dark:bg-slate-900 text-slate-500 font-semibold">
              <tr>
                <th className="p-3.5">رقم الطلب</th>
                <th className="p-3.5">حساب تيليجرام / العميل</th>
                <th className="p-3.5">المبلغ</th>
                <th className="p-3.5">حالة التنفيذ</th>
                <th className="p-3.5">المفتاح المسلم</th>
                <th className="p-3.5 text-center">إجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-700/60">
              {orders.slice(0, 5).map((order) => {
                const isReady = order.fulfillment_status === 'ready' || order.status === 'completed';
                const isProcessing = order.fulfillment_status === 'processing' || order.status === 'paid';
                return (
                  <tr key={order.id || order.external_order_id} className="hover:bg-slate-50/50 dark:hover:bg-slate-750">
                    <td className="p-3.5 font-mono font-bold text-blue-600 dark:text-blue-400">
                      #{order.external_order_id?.replace('ord_', '')}
                    </td>
                    <td className="p-3.5 text-slate-700 dark:text-slate-300">
                      {order.telegram_user ? `@${order.telegram_user.replace('@', '')}` : (order.contact_phone || 'عميل موبايل')}
                    </td>
                    <td className="p-3.5 font-bold text-slate-900 dark:text-white">
                      ${((order.total_cents || 0) / 100).toFixed(2)} USD
                    </td>
                    <td className="p-3.5">
                      <span className={`px-2.5 py-1 rounded-full font-bold text-[10px] inline-flex items-center gap-1 ${
                        isReady 
                          ? 'bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-400' 
                          : 'bg-amber-100 dark:bg-amber-950 text-amber-700 dark:text-amber-400'
                      }`}>
                        {isReady ? 'تم التسليم' : 'قيد المعالجة (24 ساعة)'}
                      </span>
                    </td>
                    <td className="p-3.5 font-mono text-slate-500">
                      {order.delivered_assets ? '✅ مسلّم' : '⏳ بانتظار التجهيز'}
                    </td>
                    <td className="p-3.5 text-center">
                      <button
                        onClick={() => onSelectOrder(order)}
                        className="px-3 py-1 bg-blue-50 dark:bg-blue-950 text-blue-600 dark:text-blue-400 hover:bg-blue-100 rounded-lg font-bold"
                      >
                        معاينة وتفعيل
                      </button>
                    </td>
                  </tr>
                );
              })}
              {orders.length === 0 && (
                <tr>
                  <td colSpan="6" className="p-8 text-center text-slate-400">
                    لا توجد طلبات مسجلة حتى الآن.
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
