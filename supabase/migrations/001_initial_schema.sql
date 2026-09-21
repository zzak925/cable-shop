-- cable-shop initial database schema
-- Target: Supabase / PostgreSQL
-- Purpose: USB 케이블 전문 매장 운영 관리 웹툴 MVP

begin;

create extension if not exists pgcrypto;

-- =========================================================
-- Common trigger: updated_at 자동 갱신
-- =========================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- 1. 직원/관리자 계정
-- Supabase Auth를 쓰는 경우 auth.users.id와 같은 UUID를 사용해도 됩니다.
-- =========================================================
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  name varchar(50) not null,
  email varchar(120) not null unique,
  password_hash text,
  role varchar(20) not null default 'staff'
    check (role in ('admin', 'manager', 'staff', 'viewer')),
  phone varchar(30),
  is_active boolean not null default true,
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

-- =========================================================
-- 2. 공급처
-- =========================================================
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  name varchar(100) not null,
  contact_name varchar(50),
  phone varchar(30),
  email varchar(120),
  address text,
  default_lead_days integer check (default_lead_days is null or default_lead_days >= 0),
  memo text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_suppliers_name on public.suppliers(name);

create trigger trg_suppliers_updated_at
before update on public.suppliers
for each row execute function public.set_updated_at();

-- =========================================================
-- 3. 상품 카테고리
-- =========================================================
create table if not exists public.product_categories (
  id uuid primary key default gen_random_uuid(),
  name varchar(80) not null,
  parent_id uuid references public.product_categories(id) on delete set null,
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(parent_id, name)
);

create index if not exists idx_product_categories_parent_id on public.product_categories(parent_id);

create trigger trg_product_categories_updated_at
before update on public.product_categories
for each row execute function public.set_updated_at();

-- =========================================================
-- 4. 상품 마스터
-- =========================================================
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  product_code varchar(60) not null unique,
  barcode varchar(80) unique,
  name varchar(150) not null,
  category_id uuid not null references public.product_categories(id) on delete restrict,
  supplier_id uuid references public.suppliers(id) on delete set null,
  connector_type varchar(50),
  cable_length varchar(30),
  color varchar(30),
  brand varchar(80),
  supports_fast_charge boolean not null default false,
  supports_data_transfer boolean not null default false,
  max_watt integer check (max_watt is null or max_watt >= 0),
  purchase_price integer not null default 0 check (purchase_price >= 0),
  sale_price integer not null default 0 check (sale_price >= 0),
  current_stock integer not null default 0 check (current_stock >= 0),
  safety_stock integer not null default 0 check (safety_stock >= 0),
  display_location varchar(100),
  storage_location varchar(100),
  status varchar(20) not null default '판매중'
    check (status in ('판매중', '품절', '발주필요', '단종', '숨김')),
  memo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_products_category_id on public.products(category_id);
create index if not exists idx_products_supplier_id on public.products(supplier_id);
create index if not exists idx_products_status on public.products(status);
create index if not exists idx_products_low_stock on public.products(current_stock, safety_stock);
create index if not exists idx_products_name on public.products(name);

create trigger trg_products_updated_at
before update on public.products
for each row execute function public.set_updated_at();

-- =========================================================
-- 5. 재고 변동 내역
-- =========================================================
create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  transaction_type varchar(30) not null
    check (transaction_type in ('입고', '판매', '반품', '불량', '조정', '폐기')),
  quantity_change integer not null,
  stock_after integer not null check (stock_after >= 0),
  reference_type varchar(30)
    check (reference_type is null or reference_type in ('sales', 'receiving', 'defect', 'adjustment', 'purchase_order')),
  reference_id uuid,
  reason text,
  created_by uuid not null references public.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index if not exists idx_inventory_transactions_product_id on public.inventory_transactions(product_id);
create index if not exists idx_inventory_transactions_created_at on public.inventory_transactions(created_at desc);
create index if not exists idx_inventory_transactions_reference on public.inventory_transactions(reference_type, reference_id);

-- =========================================================
-- 6. 입고 기록
-- =========================================================
create table if not exists public.stock_receipts (
  id uuid primary key default gen_random_uuid(),
  receipt_no varchar(60) not null unique,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  received_at timestamptz not null default now(),
  received_by uuid not null references public.users(id) on delete restrict,
  total_quantity integer not null default 0 check (total_quantity >= 0),
  total_amount integer not null default 0 check (total_amount >= 0),
  memo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_stock_receipts_supplier_id on public.stock_receipts(supplier_id);
create index if not exists idx_stock_receipts_received_at on public.stock_receipts(received_at desc);

create trigger trg_stock_receipts_updated_at
before update on public.stock_receipts
for each row execute function public.set_updated_at();

create table if not exists public.stock_receipt_items (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.stock_receipts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  purchase_price integer not null default 0 check (purchase_price >= 0),
  defective_quantity integer not null default 0 check (defective_quantity >= 0),
  final_stock_after integer check (final_stock_after is null or final_stock_after >= 0),
  memo text,
  check (defective_quantity <= quantity)
);

create index if not exists idx_stock_receipt_items_receipt_id on public.stock_receipt_items(receipt_id);
create index if not exists idx_stock_receipt_items_product_id on public.stock_receipt_items(product_id);

-- =========================================================
-- 7. 판매 기록
-- =========================================================
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  sale_no varchar(60) not null unique,
  sold_at timestamptz not null default now(),
  sold_by uuid not null references public.users(id) on delete restrict,
  payment_method varchar(30)
    check (payment_method is null or payment_method in ('카드', '현금', '계좌이체', '기타')),
  total_amount integer not null default 0 check (total_amount >= 0),
  discount_amount integer not null default 0 check (discount_amount >= 0),
  memo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_sales_sold_at on public.sales(sold_at desc);
create index if not exists idx_sales_sold_by on public.sales(sold_by);

create trigger trg_sales_updated_at
before update on public.sales
for each row execute function public.set_updated_at();

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  sale_price integer not null default 0 check (sale_price >= 0),
  discount_amount integer not null default 0 check (discount_amount >= 0),
  final_stock_after integer check (final_stock_after is null or final_stock_after >= 0),
  memo text
);

create index if not exists idx_sale_items_sale_id on public.sale_items(sale_id);
create index if not exists idx_sale_items_product_id on public.sale_items(product_id);

-- =========================================================
-- 8. 발주
-- =========================================================
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  order_no varchar(60) not null unique,
  supplier_id uuid not null references public.suppliers(id) on delete restrict,
  status varchar(20) not null default '발주필요'
    check (status in ('발주필요', '발주완료', '입고대기', '일부입고', '입고완료', '취소')),
  ordered_by uuid references public.users(id) on delete set null,
  ordered_at timestamptz,
  expected_arrival_at date,
  received_at timestamptz,
  memo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_purchase_orders_supplier_id on public.purchase_orders(supplier_id);
create index if not exists idx_purchase_orders_status on public.purchase_orders(status);

create trigger trg_purchase_orders_updated_at
before update on public.purchase_orders
for each row execute function public.set_updated_at();

create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  order_quantity integer not null check (order_quantity > 0),
  received_quantity integer not null default 0 check (received_quantity >= 0),
  purchase_price integer check (purchase_price is null or purchase_price >= 0),
  memo text,
  check (received_quantity <= order_quantity)
);

create index if not exists idx_purchase_order_items_order_id on public.purchase_order_items(purchase_order_id);
create index if not exists idx_purchase_order_items_product_id on public.purchase_order_items(product_id);

-- =========================================================
-- 9. 불량/교환/반품
-- =========================================================
create table if not exists public.defects_returns (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  sale_item_id uuid references public.sale_items(id) on delete set null,
  issue_type varchar(30) not null
    check (issue_type in ('불량', '교환', '환불', '공급처반품')),
  symptom text not null,
  quantity integer not null check (quantity > 0),
  status varchar(20) not null default '접수'
    check (status in ('접수', '확인중', '교환완료', '환불완료', '공급처반품', '종료')),
  customer_note text,
  supplier_return_needed boolean not null default false,
  handled_by uuid not null references public.users(id) on delete restrict,
  handled_at timestamptz,
  memo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_defects_returns_product_id on public.defects_returns(product_id);
create index if not exists idx_defects_returns_status on public.defects_returns(status);
create index if not exists idx_defects_returns_created_at on public.defects_returns(created_at desc);

create trigger trg_defects_returns_updated_at
before update on public.defects_returns
for each row execute function public.set_updated_at();

-- =========================================================
-- 10. 직원 일일 체크리스트
-- =========================================================
create table if not exists public.daily_checklists (
  id uuid primary key default gen_random_uuid(),
  checklist_date date not null default current_date,
  checklist_type varchar(20) not null check (checklist_type in ('오픈', '영업중', '마감')),
  item_text varchar(200) not null,
  is_checked boolean not null default false,
  checked_by uuid references public.users(id) on delete set null,
  checked_at timestamptz,
  memo text,
  created_at timestamptz not null default now()
);

create index if not exists idx_daily_checklists_date on public.daily_checklists(checklist_date desc);
create index if not exists idx_daily_checklists_type on public.daily_checklists(checklist_type);

-- =========================================================
-- 11. 마감 보고
-- =========================================================
create table if not exists public.daily_reports (
  id uuid primary key default gen_random_uuid(),
  report_date date not null,
  staff_id uuid not null references public.users(id) on delete restrict,
  total_sales_amount integer not null default 0 check (total_sales_amount >= 0),
  total_sales_quantity integer not null default 0 check (total_sales_quantity >= 0),
  cash_amount integer not null default 0 check (cash_amount >= 0),
  card_amount integer not null default 0 check (card_amount >= 0),
  transfer_amount integer not null default 0 check (transfer_amount >= 0),
  best_selling_items text,
  low_stock_items text,
  defective_items text,
  customer_requests text,
  tomorrow_tasks text,
  issue_notes text,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(report_date, staff_id)
);

create index if not exists idx_daily_reports_report_date on public.daily_reports(report_date desc);
create index if not exists idx_daily_reports_staff_id on public.daily_reports(staff_id);

create trigger trg_daily_reports_updated_at
before update on public.daily_reports
for each row execute function public.set_updated_at();

-- =========================================================
-- 12. 재고 조정
-- =========================================================
create table if not exists public.stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  before_quantity integer not null check (before_quantity >= 0),
  after_quantity integer not null check (after_quantity >= 0),
  adjustment_quantity integer not null,
  reason varchar(100) not null,
  approved_by uuid references public.users(id) on delete set null,
  adjusted_by uuid not null references public.users(id) on delete restrict,
  adjusted_at timestamptz not null default now(),
  memo text,
  created_at timestamptz not null default now(),
  check (adjustment_quantity = after_quantity - before_quantity)
);

create index if not exists idx_stock_adjustments_product_id on public.stock_adjustments(product_id);
create index if not exists idx_stock_adjustments_adjusted_at on public.stock_adjustments(adjusted_at desc);

-- =========================================================
-- 13. POS/CSV 업로드 이력
-- =========================================================
create table if not exists public.pos_imports (
  id uuid primary key default gen_random_uuid(),
  file_name varchar(200) not null,
  imported_by uuid not null references public.users(id) on delete restrict,
  imported_at timestamptz not null default now(),
  total_rows integer not null default 0 check (total_rows >= 0),
  success_rows integer not null default 0 check (success_rows >= 0),
  failed_rows integer not null default 0 check (failed_rows >= 0),
  status varchar(20) not null default '대기'
    check (status in ('대기', '처리완료', '실패')),
  error_log text,
  check (success_rows + failed_rows <= total_rows)
);

create index if not exists idx_pos_imports_imported_at on public.pos_imports(imported_at desc);

-- =========================================================
-- 14. 운영 설정
-- =========================================================
create table if not exists public.app_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key varchar(100) not null unique,
  setting_value text,
  description text,
  updated_by uuid references public.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

create trigger trg_app_settings_updated_at
before update on public.app_settings
for each row execute function public.set_updated_at();

-- =========================================================
-- 재고 상태 자동 계산 함수
-- =========================================================
create or replace function public.refresh_product_status(target_product_id uuid)
returns void
language plpgsql
as $$
declare
  v_current_stock integer;
  v_safety_stock integer;
  v_status varchar(20);
begin
  select current_stock, safety_stock, status
    into v_current_stock, v_safety_stock, v_status
  from public.products
  where id = target_product_id;

  if v_status in ('단종', '숨김') then
    return;
  end if;

  update public.products
  set status = case
    when v_current_stock = 0 then '품절'
    when v_current_stock <= v_safety_stock then '발주필요'
    else '판매중'
  end
  where id = target_product_id;
end;
$$;

-- =========================================================
-- 입고 상세 저장 시 재고 증가
-- =========================================================
create or replace function public.apply_stock_receipt_item()
returns trigger
language plpgsql
as $$
declare
  v_stock_after integer;
  v_created_by uuid;
  v_qty_to_add integer;
begin
  v_qty_to_add := new.quantity - new.defective_quantity;

  update public.products
  set current_stock = current_stock + v_qty_to_add,
      purchase_price = new.purchase_price
  where id = new.product_id
  returning current_stock into v_stock_after;

  new.final_stock_after := v_stock_after;

  select received_by into v_created_by
  from public.stock_receipts
  where id = new.receipt_id;

  if v_qty_to_add > 0 then
    insert into public.inventory_transactions (
      product_id,
      transaction_type,
      quantity_change,
      stock_after,
      reference_type,
      reference_id,
      reason,
      created_by
    ) values (
      new.product_id,
      '입고',
      v_qty_to_add,
      v_stock_after,
      'receiving',
      new.receipt_id,
      '입고 등록',
      v_created_by
    );
  end if;

  perform public.refresh_product_status(new.product_id);
  return new;
end;
$$;

create trigger trg_apply_stock_receipt_item
before insert on public.stock_receipt_items
for each row execute function public.apply_stock_receipt_item();

-- =========================================================
-- 판매 상세 저장 시 재고 차감
-- =========================================================
create or replace function public.apply_sale_item()
returns trigger
language plpgsql
as $$
declare
  v_stock_after integer;
  v_created_by uuid;
begin
  update public.products
  set current_stock = current_stock - new.quantity
  where id = new.product_id
    and current_stock >= new.quantity
  returning current_stock into v_stock_after;

  if v_stock_after is null then
    raise exception '재고가 부족합니다. product_id=%, quantity=%', new.product_id, new.quantity;
  end if;

  new.final_stock_after := v_stock_after;

  select sold_by into v_created_by
  from public.sales
  where id = new.sale_id;

  insert into public.inventory_transactions (
    product_id,
    transaction_type,
    quantity_change,
    stock_after,
    reference_type,
    reference_id,
    reason,
    created_by
  ) values (
    new.product_id,
    '판매',
    -new.quantity,
    v_stock_after,
    'sales',
    new.sale_id,
    '판매 등록',
    v_created_by
  );

  perform public.refresh_product_status(new.product_id);
  return new;
end;
$$;

create trigger trg_apply_sale_item
before insert on public.sale_items
for each row execute function public.apply_sale_item();

-- =========================================================
-- 재고 조정 저장 시 현재 재고 반영
-- =========================================================
create or replace function public.apply_stock_adjustment()
returns trigger
language plpgsql
as $$
begin
  update public.products
  set current_stock = new.after_quantity
  where id = new.product_id;

  insert into public.inventory_transactions (
    product_id,
    transaction_type,
    quantity_change,
    stock_after,
    reference_type,
    reference_id,
    reason,
    created_by
  ) values (
    new.product_id,
    '조정',
    new.adjustment_quantity,
    new.after_quantity,
    'adjustment',
    new.id,
    new.reason,
    new.adjusted_by
  );

  perform public.refresh_product_status(new.product_id);
  return new;
end;
$$;

create trigger trg_apply_stock_adjustment
after insert on public.stock_adjustments
for each row execute function public.apply_stock_adjustment();

-- =========================================================
-- 합계 자동 업데이트 함수
-- =========================================================
create or replace function public.refresh_stock_receipt_totals(target_receipt_id uuid)
returns void
language sql
as $$
  update public.stock_receipts
  set total_quantity = coalesce((
        select sum(quantity)
        from public.stock_receipt_items
        where receipt_id = target_receipt_id
      ), 0),
      total_amount = coalesce((
        select sum(quantity * purchase_price)
        from public.stock_receipt_items
        where receipt_id = target_receipt_id
      ), 0)
  where id = target_receipt_id;
$$;

create or replace function public.refresh_sale_totals(target_sale_id uuid)
returns void
language sql
as $$
  update public.sales
  set total_amount = coalesce((
        select sum((quantity * sale_price) - discount_amount)
        from public.sale_items
        where sale_id = target_sale_id
      ), 0),
      discount_amount = coalesce((
        select sum(discount_amount)
        from public.sale_items
        where sale_id = target_sale_id
      ), 0)
  where id = target_sale_id;
$$;

create or replace function public.after_stock_receipt_item_change()
returns trigger
language plpgsql
as $$
begin
  perform public.refresh_stock_receipt_totals(coalesce(new.receipt_id, old.receipt_id));

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create trigger trg_after_stock_receipt_item_change
after insert or update or delete on public.stock_receipt_items
for each row execute function public.after_stock_receipt_item_change();

create or replace function public.after_sale_item_change()
returns trigger
language plpgsql
as $$
begin
  perform public.refresh_sale_totals(coalesce(new.sale_id, old.sale_id));

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create trigger trg_after_sale_item_change
after insert or update or delete on public.sale_items
for each row execute function public.after_sale_item_change();

-- =========================================================
-- 운영용 View
-- =========================================================
create or replace view public.low_stock_products as
select
  p.id,
  p.product_code,
  p.name,
  c.name as category_name,
  s.name as supplier_name,
  p.current_stock,
  p.safety_stock,
  greatest((p.safety_stock * 2) - p.current_stock, 0) as recommended_order_quantity,
  p.status,
  p.display_location,
  p.storage_location
from public.products p
join public.product_categories c on c.id = p.category_id
left join public.suppliers s on s.id = p.supplier_id
where p.status not in ('단종', '숨김')
  and p.current_stock <= p.safety_stock;

create or replace view public.today_sales_summary as
select
  current_date as sale_date,
  coalesce(sum(s.total_amount), 0) as total_sales_amount,
  coalesce(sum(si.quantity), 0) as total_sales_quantity,
  count(distinct s.id) as sales_count
from public.sales s
left join public.sale_items si on si.sale_id = s.id
where s.sold_at >= current_date
  and s.sold_at < current_date + interval '1 day';

create or replace view public.best_selling_products_7d as
select
  p.id,
  p.product_code,
  p.name,
  sum(si.quantity) as sold_quantity,
  sum((si.quantity * si.sale_price) - si.discount_amount) as sales_amount
from public.sale_items si
join public.sales s on s.id = si.sale_id
join public.products p on p.id = si.product_id
where s.sold_at >= now() - interval '7 days'
group by p.id, p.product_code, p.name
order by sold_quantity desc, sales_amount desc;

-- =========================================================
-- 기본 설정값
-- =========================================================
insert into public.app_settings (setting_key, setting_value, description)
values
  ('store_name', '케이블샵', '매장명'),
  ('default_safety_stock', '5', '상품 등록 시 기본 안전재고'),
  ('low_stock_multiplier', '2', '발주 추천 수량 계산 배수'),
  ('currency', 'KRW', '기본 통화')
on conflict (setting_key) do nothing;

-- 기본 카테고리
insert into public.product_categories (name, display_order)
values
  ('충전 케이블', 10),
  ('영상 케이블', 20),
  ('데이터 케이블', 30),
  ('네트워크 케이블', 40),
  ('오디오 케이블', 50),
  ('젠더/허브/액세서리', 60)
on conflict (parent_id, name) do nothing;

commit;
