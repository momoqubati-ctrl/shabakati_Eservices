import React, { useState, useEffect } from 'react';
import { Sidebar } from './components/Sidebar';
import { Navbar } from './components/Navbar';
import { DashboardOverview } from './pages/DashboardOverview';
import { OrdersManagement } from './pages/OrdersManagement';
import { OperationsReports } from './pages/OperationsReports';
import { CatalogManagement } from './pages/CatalogManagement';
import { OrderDetailModal } from './components/OrderDetailModal';
import { supabase } from './config/supabase';
import { DigitalVaultService } from './services/digitalVaultService';

export function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [walletBalance, setWalletBalance] = useState(null);
  const [sellerProfile, setSellerProfile] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState(null);

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

  // جلب بيانات المزود (Digital Vault)
  const fetchProviderData = async () => {
    try {
      // 1. المحفظة
      const walletRes = await DigitalVaultService.getSellerWallet();
      if (walletRes?.success && walletRes?.data?.available_balance) {
        setWalletBalance(walletRes.data.available_balance.amount_cents);
      }

      // 2. الملف الشخصي
      const profileRes = await DigitalVaultService.getSellerProfile();
      if (profileRes?.success && profileRes?.data) {
        setSellerProfile(profileRes.data);
      }

      // 3. الكتالوج
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
    await Promise.all([fetchOrders(), fetchProviderData()]);
    setIsLoading(false);
  };

  useEffect(() => {
    handleRefreshAll();

    // تفعيل الاستماع اللحظي (Supabase Realtime Stream)
    const channel = supabase
      .channel('admin-orders-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'orders' },
        (payload) => {
          console.log('Realtime Order Event received:', payload);
          fetchOrders(); // إعادة جلب فوري عند أي تغيير
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

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
          isLoading={isLoading}
          onRefresh={handleRefreshAll}
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
