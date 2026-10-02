import React from 'react';
import { 
  LayoutDashboard, 
  ShoppingCart, 
  BarChart3, 
  Layers, 
  Wallet, 
  ExternalLink,
  ShieldCheck,
  X
} from 'lucide-react';

export const Sidebar = ({ 
  activeTab, 
  setActiveTab, 
  pendingOrdersCount = 0,
  isOpen = false,
  onClose
}) => {
  const navItems = [
    { id: 'dashboard', label: 'لوحة المؤشرات العامة', icon: LayoutDashboard },
    { 
      id: 'orders', 
      label: 'إدارة الطلبات والعمليات', 
      icon: ShoppingCart,
      badge: pendingOrdersCount > 0 ? pendingOrdersCount : null 
    },
    { id: 'reports', label: 'تقارير وتحليلات العمليات', icon: BarChart3 },
    { id: 'catalog', label: 'كتالوج الاشتراكات والخدمات', icon: Layers },
  ];

  return (
    <>
      {/* خلفية معتمة عند فتح القائمة في الموبايل */}
      {isOpen && (
        <div 
          onClick={onClose}
          className="fixed inset-0 z-40 bg-slate-950/70 backdrop-blur-sm lg:hidden transition-opacity duration-300"
        />
      )}

      <aside className={`fixed lg:static top-0 bottom-0 right-0 z-50 w-72 lg:w-64 bg-slate-900 text-slate-100 flex flex-col border-l border-slate-800 shadow-2xl lg:shadow-xl min-h-screen transition-transform duration-300 ease-in-out shrink-0 ${
        isOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'
      }`}>
        {/* رأس القائمة */}
        <div className="p-5 sm:p-6 border-b border-slate-800 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-blue-600 rounded-xl text-white shadow-lg shadow-blue-500/30">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-lg font-bold tracking-tight">شَبَكتي | أدمن</h1>
              <p className="text-xs text-slate-400">بوابة الإدارة المركزية</p>
            </div>
          </div>
          {/* زر إغلاق للموبايل */}
          <button
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-white rounded-lg lg:hidden transition-colors"
            title="إغلاق القائمة"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

      {/* عناصر التوجيه */}
      <nav className="flex-1 p-4 space-y-1.5">
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => {
                setActiveTab(item.id);
                if (onClose) onClose();
              }}
              className={`w-full flex items-center justify-between px-4 py-3 rounded-xl text-sm font-semibold transition-all duration-200 ${
                isActive
                  ? 'bg-blue-600 text-white shadow-md shadow-blue-600/20 translate-x-1'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
              }`}
            >
              <div className="flex items-center gap-3">
                <Icon className={`w-5 h-5 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                <span>{item.label}</span>
              </div>
              {item.badge && (
                <span className="px-2 py-0.5 text-xs font-bold bg-amber-500 text-slate-950 rounded-full animate-pulse">
                  {item.badge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* بطاقة المزود والرابط السريع */}
      <div className="p-4 border-t border-slate-800 bg-slate-950/40">
        <div className="p-3.5 rounded-xl bg-slate-800/80 border border-slate-700/60 space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-300 flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-emerald-500 inline-block animate-ping"></span>
              مزود Digital Vault
            </span>
            <span className="text-[10px] text-emerald-400 bg-emerald-950/80 px-2 py-0.5 rounded border border-emerald-800 font-mono">
              متصل
            </span>
          </div>
          <p className="text-[11px] text-slate-400 leading-relaxed">
            مفتاح API جاهز ومصرح له بالبيع الفوري والتسليم الآلي.
          </p>
        </div>
      </div>
    </aside>
    </>
  );
};
