import React from 'react';
import { RefreshCw, Wallet, Send, LogOut, Coins } from 'lucide-react';
import { API_CONFIG } from '../config/apiConfig';

export const Navbar = ({ 
  title, 
  walletBalance, 
  exchangeRate,
  isLoading, 
  onRefresh, 
  onLogout,
  isRealtimeActive = true 
}) => {
  return (
    <header className="h-16 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-8 flex items-center justify-between shadow-sm">
      <div className="flex items-center gap-4">
        <h2 className="text-xl font-bold text-slate-800 dark:text-slate-100">{title}</h2>
        <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-emerald-50 dark:bg-emerald-950/60 border border-emerald-200 dark:border-emerald-800 text-xs font-semibold text-emerald-700 dark:text-emerald-400">
          <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
          <span>بث Realtime نشط</span>
        </div>
      </div>

      <div className="flex items-center gap-4">
        {/* سعر الصرف الحالي */}
        {exchangeRate && (
          <div className="hidden sm:flex items-center gap-2 bg-amber-50 dark:bg-amber-950/50 border border-amber-200 dark:border-amber-800/80 px-3 py-1.5 rounded-xl text-xs">
            <Coins className="w-4 h-4 text-amber-600 dark:text-amber-400" />
            <span className="text-slate-600 dark:text-slate-300 font-bold">1$ = {exchangeRate} ر.ي</span>
          </div>
        )}

        {/* رصيد المحفظة لدى المزود */}
        <div className="flex items-center gap-2.5 bg-slate-100 dark:bg-slate-800 px-3.5 py-1.5 rounded-xl border border-slate-200 dark:border-slate-700">
          <Wallet className="w-4 h-4 text-blue-600 dark:text-blue-400" />
          <div className="text-xs">
            <span className="text-slate-500 dark:text-slate-400 block text-[10px]">رصيد المزود (Digital Vault)</span>
            <span className="font-extrabold text-slate-800 dark:text-slate-100">
              {walletBalance !== null ? `$${(walletBalance / 100).toFixed(2)} USD` : '...'}
            </span>
          </div>
        </div>

        {/* زر التحديث السريع */}
        <button
          onClick={onRefresh}
          disabled={isLoading}
          className="p-2.5 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all border border-slate-200 dark:border-slate-700"
          title="تحديث البيانات"
        >
          <RefreshCw className={`w-4 h-4 ${isLoading ? 'animate-spin text-blue-600' : ''}`} />
        </button>

        {/* فتح بوت تيليجرام */}
        <a
          href={`https://t.me/${API_CONFIG.telegramBotUsername}`}
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-2 px-3 py-1.5 bg-[#229ED9]/10 text-[#229ED9] hover:bg-[#229ED9]/20 font-semibold rounded-xl text-xs transition-colors border border-[#229ED9]/30"
        >
          <Send className="w-3.5 h-3.5" />
          <span className="hidden sm:inline">بوت تيليجرام</span>
        </a>

        {/* زر تسجيل الخروج */}
        <button
          onClick={onLogout}
          className="p-2.5 text-red-500 hover:bg-red-50 dark:hover:bg-red-950/60 rounded-xl transition-colors border border-red-200 dark:border-red-900/60"
          title="تسجيل الخروج"
        >
          <LogOut className="w-4 h-4" />
        </button>
      </div>
    </header>
  );
};
