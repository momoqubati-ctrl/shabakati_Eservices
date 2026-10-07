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
  const isAdmin = session?.user?.app_metadata?.role === 'admin';

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

  // جلب الطلبات من Supabase ودمجها مع سجلات الدفع بالمحافظ الإلكترونية
  const fetchOrders = async () => {
    try {
      const [{ data, error }, { data: paymentsData }] = await Promise.all([
        supabase
          .from('orders')
          .select('*')
          .order('created_at', { ascending: false }),
        supabase
          .from('payments')
          .select('id, external_order_id, amount, currency, payment_reference, wallet_name, provider, status, user_account, metadata, created_at')
          .order('created_at', { ascending: false })
          .limit(500),
      ]);

      if (!error && data) {
        const paymentsById = {};
        const paymentsByOrderId = {};
        const paymentsByRef = {};
        if (Array.isArray(paymentsData)) {
          paymentsData.forEach((p) => {
            if (p.id) paymentsById[p.id] = p;
            if (p.external_order_id) paymentsByOrderId[p.external_order_id] = p;
            if (p.payment_reference) paymentsByRef[p.payment_reference] = p;
            if (p.metadata?.consumed_by_order) {
              paymentsByOrderId[p.metadata.consumed_by_order] = p;
            }
          });
        }

        let overrides = {};
        try {
          overrides = JSON.parse(localStorage.getItem('shabakti_order_overrides') || '{}');
        } catch (_) {}

        const merged = data.map((o) => {
          const matchedPayment =
            (o.payment_id && paymentsById[o.payment_id]) ||
            (o.external_order_id && paymentsByOrderId[o.external_order_id]) ||
            (o.payment_reference && paymentsByRef[o.payment_reference]) ||
            null;

          const rawAmountYer = matchedPayment?.amount
            ? Number(matchedPayment.amount)
            : o.paid_amount_yer
              ? Number(o.paid_amount_yer)
              : o.total_cents === 189
                ? 1500
                : Math.round(((o.total_cents || 0) / 100) * (exchangeRate || 535));

          const knownDvBotCodes = {
            11: 'ORD-MLRX0MBV0R',
            4: 'ORD-UYAGV29QYP',
            3: 'ORD-OWYF6E5WCG',
            2: 'ORD-KEOPRPBJA1',
          };
          const dvBotCode =
            o.provider_order_code ||
            o.dv_order_code ||
            (o.seller_order_id && knownDvBotCodes[o.seller_order_id]) ||
            null;

          const enriched = {
            ...o,
            payment_id: o.payment_id || matchedPayment?.id || null,
            payment_reference:
              o.payment_reference ||
              matchedPayment?.payment_reference ||
              o.payment_id ||
              matchedPayment?.id ||
              null,
            payment_method: o.payment_method || 'المحافظ الإلكترونية',
            wallet_name: o.wallet_name || matchedPayment?.wallet_name || null,
            paid_amount_yer: rawAmountYer,
            gateway_order_id: matchedPayment?.external_order_id || o.external_order_id || null,
            gateway_raw_order_id: matchedPayment?.external_order_id || null,
            digital_vault_ref: dvBotCode ? `#${dvBotCode}` : (o.seller_order_id ? `#${o.seller_order_id}` : null),
            digital_vault_bot_code: dvBotCode,
          };

          const key = enriched.id || enriched.external_order_id;
          if (overrides[key]) {
            return { ...enriched, ...overrides[key] };
          }
          return enriched;
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
      if (catRes?.success && Array.isArray(catRes?.data) && catRes.data.length > 0) {
        setProducts(catRes.data);
      } else {
        // Fallback مباشر: جلب الكتالوج من جدول cached_products في Supabase
        const { data: cachedProds } = await supabase
          .from('cached_products')
          .select('*')
          .order('id', { ascending: true });
        if (Array.isArray(cachedProds) && cachedProds.length > 0) {
          const formatted = cachedProds.map(p => ({
            id: p.id,
            sku: p.sku,
            name: p.name,
            availability: (p.availability || 'available').replace(/"/g, ''),
            pricing_quantity: 1,
            seller_price: {
              amount_cents: p.price_cents || 0,
              currency: p.currency || 'USD'
            },
            seller_base_price: {
              amount_cents: p.price_cents || 0,
              currency: p.currency || 'USD'
            },
            line_total: {
              amount_cents: p.price_cents || 0,
              currency: p.currency || 'USD'
            }
          }));
          setProducts(formatted);
        }
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
    if (!isAdmin) return;

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
  }, [isAdmin]);

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

  if (!isAdmin) {
    return (
      <div className="min-h-screen bg-slate-950 flex flex-col items-center justify-center gap-4 text-white" dir="rtl">
        <p className="text-sm text-slate-300">هذا الحساب غير مخول للوصول إلى لوحة الإدارة.</p>
        <button
          type="button"
          onClick={handleLogout}
          className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-bold hover:bg-blue-700"
        >
          تسجيل الخروج
        </button>
      </div>
    );
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
