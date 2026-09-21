import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cable Shop 운영관리",
  description: "USB 케이블 전문 매장 운영 관리 웹툴",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko">
      <body>
        <div className="app-shell">
          <aside className="sidebar">
            <div className="brand">
              <span className="brand-mark">C</span>
              <div>
                <strong>Cable Shop</strong>
                <small>운영 관리</small>
              </div>
            </div>
            <nav>
              <a href="#dashboard">대시보드</a>
              <a href="#products">상품/재고</a>
              <a href="#low-stock">발주 필요</a>
              <a href="#workflow">입고/판매 흐름</a>
              <a href="#reports">마감 보고</a>
              <a href="#setup">Supabase 연결</a>
            </nav>
          </aside>
          <main className="main-content">{children}</main>
        </div>
      </body>
    </html>
  );
}
