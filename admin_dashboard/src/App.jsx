import React, { useState, useEffect } from 'react';
import { Sidebar } from './components/Sidebar';
import { Navbar } from './components/Navbar';
import { DashboardOverview } from './pages/DashboardOverview';
import { OrdersManagement } from './pages/OrdersManagement';
import { OperationsReports } from './pages/OperationsReports';
import { CatalogManagement } from './pages/CatalogManagement';
import { OrderDetailModal } from './components/OrderDetailModal';
import { LoginPage } from './pages/LoginPage';
import { supabase } from './config/supabase';
import { DigitalVaultService } from './services/digitalVaultService';

export function App() {
  const [session, setSession] = useState(null);
  const [isAuthLoading, setIsAuthLoading] = useState(true);

  const [activeTab, setActiveTab] = useState('dashboard');
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [walletBalance, setWalletBalance] = useState(null);
  const [sellerProfile, setSellerProfile] = useState(null);
  const [exchangeRate, setExchangeRate] = useState(535);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);

  // إدارة جلسة Supabase Auth
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setIsAuthLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setIsAuthLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  // تسجيل الخروج الآمن
  const handleLogout = async () => {
    await supabase.auth.signOut();
    setSession(null);
  };

  // جلب الطلبات من Supabase
  const fetchOrders = async () => {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false });
      if (!error && data) {
        let overrides = {};
        try {
          overrides = JSON.parse(localStorage.getItem('shabakti_order_overrides') || '{}');
        } catch (_) {}
        const merged = data.map(o => {
          const key = o.id || o.external_order_id;
          if (overrides[key]) {
            return { ...o, ...overrides[key] };
          }
          return o;
        });
        setOrders(merged);
      }
    } catch (e) {
      console.error('Error fetching orders:', e);
    }
  };

  // جلب سعر الصرف من Supabase
  const fetchSettings = async () => {
    try {
      const { data } = await supabase
        .from('app_settings')
        .select('*')
        .eq('id', 'general_settings')
        .single();
      if (data?.usd_to_yer_rate) {
        setExchangeRate(Number(data.usd_to_yer_rate));
      }
    } catch (_) {}
  };

  // جلب بيانات المزود (Digital Vault)
  const fetchProviderData = async () => {
    try {
      const walletRes = await DigitalVaultService.getSellerWallet();
      if (walletRes?.success && walletRes?.data?.available_balance) {
        setWalletBalance(walletRes.data.available_balance.amount_cents);
      }

      const profileRes = await DigitalVaultService.getSellerProfile();
      if (profileRes?.success && profileRes?.data) {
        setSellerProfile(profileRes.data);
      }

      const catRes = await DigitalVaultService.getCatalogProducts();
      if (catRes?.success && catRes?.data) {
        setProducts(catRes.data);
      }
    } catch (e) {
      console.warn('Digital Vault fetch warning:', e);
    }
  };

  // تحديث شامل
  const handleRefreshAll = async () => {
    setIsLoading(true);
    await Promise.all([fetchOrders(), fetchSettings(), fetchProviderData()]);
    setIsLoading(false);
  };

  useEffect(() => {
    if (!session) return;

    handleRefreshAll();

    // تفعيل الاستماع اللحظي (Supabase Realtime Stream)
    const channel = supabase
      .channel('admin-orders-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders' },
        () => {
          fetchOrders();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'app_settings' },
        () => {
          fetchSettings();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [session]);

  if (isAuthLoading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center text-white" dir="rtl">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
          <span className="text-xs text-slate-400">جاري التحقق من الصلاحيات الأمنية...</span>
        </div>
      </div>
    );
  }

  if (!session) {
    return <LoginPage onLoginSuccess={() => {}} />;
  }

  const pendingCount = orders.filter(
    (o) => o.fulfillment_status === 'processing' || o.status === 'paid'
  ).length;

  const getPageTitle = () => {
    switch (activeTab) {
      case 'dashboard':
        return 'لوحة المؤشرات والعمليات العامة';
      case 'orders':
        return 'إدارة ومتابعة طلبات الاشتراكات';
      case 'reports':
        return 'تقارير الأداء المالي والعمليات';
      case 'catalog':
        return 'كتالوج الخدمات والأسعار المربوطة';
      default:
        return 'لوحة التحكم';
    }
  };

  return (
    <div className="flex min-h-screen bg-slate-100 dark:bg-slate-950 font-sans text-slate-800 dark:text-slate-100 antialiased" dir="rtl">
      {/* القائمة الجانبية */}
      <Sidebar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab} 
        pendingOrdersCount={pendingCount}
        isOpen={isMobileSidebarOpen}
        onClose={() => setIsMobileSidebarOpen(false)}
      />

      {/* المحتوى الرئيسي */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden w-full">
        <Navbar
          title={getPageTitle()}
          walletBalance={walletBalance}
          exchangeRate={exchangeRate}
          isLoading={isLoading}
          onRefresh={handleRefreshAll}
          onLogout={handleLogout}
          onToggleSidebar={() => setIsMobileSidebarOpen(prev => !prev)}
        />

        <main className="flex-1 p-3.5 sm:p-6 lg:p-8 overflow-y-auto">
          {activeTab === 'dashboard' && (
            <DashboardOverview
              orders={orders}
              sellerProfile={sellerProfile}
              onSelectOrder={(order) => setSelectedOrder(order)}
            />
          )}

          {activeTab === 'orders' && (
            <OrdersManagement
              orders={orders}
              onSelectOrder={(order) => setSelectedOrder(order)}
            />
          )}

          {activeTab === 'reports' && (
            <OperationsReports orders={orders} />
          )}

          {activeTab === 'catalog' && (
            <CatalogManagement
              initialProducts={products}
              onSync={(newProds) => setProducts(newProds)}
            />
          )}
        </main>
      </div>

      {/* نافذة تفاصيل وتفعيل الطلب */}
      {selectedOrder && (
        <OrderDetailModal
          order={selectedOrder}
          onClose={() => setSelectedOrder(null)}
          onOrderUpdated={(updated) => {
            if (updated) {
              const key = updated.id || updated.external_order_id;
              try {
                const overrides = JSON.parse(localStorage.getItem('shabakti_order_overrides') || '{}');
                overrides[key] = updated;
                localStorage.setItem('shabakti_order_overrides', JSON.stringify(overrides));
              } catch (_) {}

              setOrders(prev => prev.map(o => 
                (o.id === updated.id || o.external_order_id === updated.external_order_id)
                  ? { ...o, ...updated }
                  : o
              ));
              setSelectedOrder(updated);
            }
            fetchOrders();
          }}
        />
      )}
    </div>
  );
}

export default App;
