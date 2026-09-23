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
  // حالة التحقق وتسجيل الدخول
  const [isAuthenticated, setIsAuthenticated] = useState(() => {
    return !!localStorage.getItem('shabakti_admin_auth');
  });

  const [activeTab, setActiveTab] = useState('dashboard');
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [walletBalance, setWalletBalance] = useState(null);
  const [sellerProfile, setSellerProfile] = useState(null);
  const [exchangeRate, setExchangeRate] = useState(535);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState(null);

  // تسجيل الخروج
  const handleLogout = () => {
    localStorage.removeItem('shabakti_admin_auth');
    setIsAuthenticated(false);
  };

  // جلب الطلبات من Supabase
  const fetchOrders = async () => {
    try {
      const { data, error } = await supabase
        .from('orders')
        .select('*')
        .order('created_at', { ascending: false });
      if (!error && data) {
        setOrders(data);
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
    if (!isAuthenticated) return;

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
  }, [isAuthenticated]);

  if (!isAuthenticated) {
    return <LoginPage onLoginSuccess={() => setIsAuthenticated(true)} />;
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
      />

      {/* المحتوى الرئيسي */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Navbar
          title={getPageTitle()}
          walletBalance={walletBalance}
          exchangeRate={exchangeRate}
          isLoading={isLoading}
          onRefresh={handleRefreshAll}
          onLogout={handleLogout}
        />

        <main className="flex-1 p-8 overflow-y-auto">
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
          onOrderUpdated={() => {
            fetchOrders();
            setSelectedOrder(null);
          }}
        />
      )}
    </div>
  );
}

export default App;
