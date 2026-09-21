import { getDashboardData } from "@/lib/data";

const formatter = new Intl.NumberFormat("ko-KR");

function money(value: number | null | undefined) {
  return `${formatter.format(value ?? 0)}원`;
}

function StatusBadge({ status }: { status: string }) {
  const className = status === "품절" ? "danger" : status === "발주필요" ? "warning" : "success";
  return <span className={`badge ${className}`}>{status}</span>;
}

export default async function Home() {
  const data = await getDashboardData();
  const totalProducts = data.products.length;
  const lowStockCount = data.lowStockProducts.length;
  const outOfStockCount = data.products.filter((product) => product.current_stock === 0).length;
  const inventoryValue = data.products.reduce((sum, product) => sum + (product.sale_price ?? 0) * product.current_stock, 0);

  return (
    <div>
      <section className="hero" id="dashboard">
        <div>
          <p className="eyebrow">USB 케이블 전문 매장</p>
          <h1>재고, 입고, 판매, 발주를 한 화면에서 관리합니다.</h1>
          <p className="hero-copy">
            현재는 {data.source === "mock" ? "샘플 데이터" : "Supabase 데이터"}로 표시 중입니다. Supabase 환경변수를 연결하면 실제 매장 데이터로 전환됩니다.
          </p>
        </div>
        <div className="connection-card">
          <span>데이터 연결 상태</span>
          <strong>{data.source === "mock" ? "샘플 모드" : "Supabase 연결됨"}</strong>
          <small>{data.source === "mock" ? ".env.local 설정 후 실제 데이터 사용" : "실시간 DB 조회 중"}</small>
        </div>
      </section>

      <section className="stat-grid">
        <article className="stat-card">
          <span>오늘 매출</span>
          <strong>{money(data.salesSummary.total_sales_amount)}</strong>
          <small>판매 {formatter.format(data.salesSummary.sales_count ?? 0)}건</small>
        </article>
        <article className="stat-card">
          <span>오늘 판매수량</span>
          <strong>{formatter.format(data.salesSummary.total_sales_quantity ?? 0)}개</strong>
          <small>POS CSV 연동 전 수동 입력 가능</small>
        </article>
        <article className="stat-card warning-card">
          <span>발주 필요</span>
          <strong>{formatter.format(lowStockCount)}개</strong>
          <small>안전재고 이하 상품</small>
        </article>
        <article className="stat-card danger-card">
          <span>품절 상품</span>
          <strong>{formatter.format(outOfStockCount)}개</strong>
          <small>즉시 발주/진열 확인</small>
        </article>
      </section>

      <section className="panel" id="products">
        <div className="panel-header">
          <div>
            <p className="eyebrow">상품/재고</p>
            <h2>현재 재고 현황</h2>
          </div>
          <div className="summary-pill">상품 {totalProducts}개 · 재고 판매가 {money(inventoryValue)}</div>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>상품코드</th>
                <th>상품명</th>
                <th>규격</th>
                <th>현재/안전</th>
                <th>판매가</th>
                <th>위치</th>
                <th>상태</th>
              </tr>
            </thead>
            <tbody>
              {data.products.map((product) => (
                <tr key={product.id}>
                  <td className="code">{product.product_code}</td>
                  <td>{product.name}</td>
                  <td>{[product.connector_type, product.cable_length, product.color].filter(Boolean).join(" · ")}</td>
                  <td>{product.current_stock} / {product.safety_stock}</td>
                  <td>{money(product.sale_price)}</td>
                  <td>{product.display_location ?? "-"}</td>
                  <td><StatusBadge status={product.status} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="two-column">
        <article className="panel" id="low-stock">
          <div className="panel-header">
            <div>
              <p className="eyebrow">발주 관리</p>
              <h2>오늘 발주해야 할 상품</h2>
            </div>
          </div>
          <div className="order-list">
            {data.lowStockProducts.length === 0 ? (
              <p className="empty">현재 발주 필요 상품이 없습니다.</p>
            ) : (
              data.lowStockProducts.map((product) => (
                <div className="order-item" key={product.id}>
                  <div>
                    <strong>{product.name}</strong>
                    <small>{product.product_code} · 현재 {product.current_stock}개 · 안전 {product.safety_stock}개</small>
                  </div>
                  <span>{formatter.format(product.recommended_order_quantity ?? Math.max(product.safety_stock * 2 - product.current_stock, 0))}개 발주</span>
                </div>
              ))
            )}
          </div>
        </article>

        <article className="panel" id="reports">
          <div className="panel-header">
            <div>
              <p className="eyebrow">직원 업무</p>
              <h2>오늘 체크리스트</h2>
            </div>
          </div>
          <div className="task-list">
            {data.dailyTasks.map((task, index) => (
              <label className="task" key={`${task.type}-${index}`}>
                <input type="checkbox" checked={task.checked} readOnly />
                <span><b>{task.type}</b> {task.text}</span>
              </label>
            ))}
          </div>
        </article>
      </section>

      <section className="panel" id="workflow">
        <div className="panel-header">
          <div>
            <p className="eyebrow">운영 흐름</p>
            <h2>1차 MVP 업무 흐름</h2>
          </div>
        </div>
        <div className="workflow">
          {[
            ["상품 등록", "케이블 타입, 길이, 색상, 안전재고 입력"],
            ["입고 등록", "공급처/수량/불량 수량 입력 후 재고 자동 증가"],
            ["판매 등록", "판매 수량 입력 후 재고 자동 차감"],
            ["발주 확인", "안전재고 이하 상품을 공급처별로 확인"],
            ["마감 보고", "매출, 품절, 불량, 내일 할 일 기록"],
          ].map(([title, text]) => (
            <div className="workflow-step" key={title}>
              <strong>{title}</strong>
              <p>{text}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="panel setup" id="setup">
        <div className="panel-header">
          <div>
            <p className="eyebrow">설정</p>
            <h2>Supabase 연결 방법</h2>
          </div>
        </div>
        <ol>
          <li>Supabase 프로젝트를 만들고 SQL Editor에서 <code>supabase/migrations/001_initial_schema.sql</code>을 실행합니다.</li>
          <li><code>.env.example</code>을 복사해 <code>.env.local</code>을 만듭니다.</li>
          <li><code>NEXT_PUBLIC_SUPABASE_URL</code>, <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>를 입력합니다.</li>
          <li><code>npm run dev</code>로 다시 실행하면 실제 DB 데이터를 조회합니다.</li>
        </ol>
      </section>
    </div>
  );
}
