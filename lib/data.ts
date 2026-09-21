import { getSupabaseServerClient } from "./supabase";
import { mockDailyTasks, mockProducts, mockSalesSummary } from "./mock-data";

export type ProductRow = {
  id: string;
  product_code: string;
  name: string;
  category_name?: string | null;
  supplier_name?: string | null;
  connector_type?: string | null;
  cable_length?: string | null;
  color?: string | null;
  current_stock: number;
  safety_stock: number;
  sale_price?: number | null;
  status: string;
  display_location?: string | null;
  recommended_order_quantity?: number | null;
};

export async function getDashboardData() {
  const supabase = getSupabaseServerClient();

  if (!supabase) {
    return {
      source: "mock" as const,
      products: mockProducts,
      lowStockProducts: mockProducts
        .filter((product) => product.current_stock <= product.safety_stock)
        .map((product) => ({
          ...product,
          recommended_order_quantity: Math.max(product.safety_stock * 2 - product.current_stock, 0),
        })),
      salesSummary: mockSalesSummary,
      dailyTasks: mockDailyTasks,
    };
  }

  const [productsResult, lowStockResult, salesSummaryResult, checklistResult] = await Promise.all([
    supabase
      .from("products")
      .select("id, product_code, name, connector_type, cable_length, color, current_stock, safety_stock, sale_price, status, display_location")
      .order("created_at", { ascending: false })
      .limit(20),
    supabase.from("low_stock_products").select("*").limit(20),
    supabase.from("today_sales_summary").select("*").single(),
    supabase
      .from("daily_checklists")
      .select("checklist_type, item_text, is_checked")
      .gte("checklist_date", new Date().toISOString().slice(0, 10))
      .limit(10),
  ]);

  return {
    source: "supabase" as const,
    products: (productsResult.data ?? []) as ProductRow[],
    lowStockProducts: (lowStockResult.data ?? []) as ProductRow[],
    salesSummary: salesSummaryResult.data ?? { total_sales_amount: 0, total_sales_quantity: 0, sales_count: 0 },
    dailyTasks: (checklistResult.data ?? []).map((item) => ({
      type: item.checklist_type,
      text: item.item_text,
      checked: item.is_checked,
    })),
  };
}
