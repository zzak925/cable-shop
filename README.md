# cable-shop

USB 케이블 전문 매장 운영 관리 웹툴을 위한 데이터베이스 설계표입니다.

실제 Supabase/PostgreSQL에 적용할 수 있는 SQL 스키마 파일:

- `supabase/migrations/001_initial_schema.sql`

## 설계 기준

- 1차 목표: 재고 정확도, 입고/판매 기록, 발주 필요 상품 확인, 직원 마감 보고
- 상품 단위: 케이블 종류, 길이, 색상, 브랜드, 충전/데이터 지원 여부를 구분
- 재고 흐름: 상품 등록 → 입고 → 판매/불량/조정 → 안전재고 확인 → 발주
- MVP 기준: POS 실시간 연동 전에도 수동 입력 또는 CSV 업로드로 운영 가능하게 설계

## 주요 상태값

### 상품 상태

| 상태 | 설명 |
|---|---|
| 판매중 | 정상 판매 가능 |
| 품절 | 현재 재고 0개 |
| 발주필요 | 안전재고 이하로 내려간 상품 |
| 단종 | 더 이상 판매/발주하지 않는 상품 |
| 숨김 | 운영상 화면에서 숨기는 상품 |

### 발주 상태

| 상태 | 설명 |
|---|---|
| 발주필요 | 시스템 또는 관리자가 발주 필요로 표시 |
| 발주완료 | 공급처에 발주 완료 |
| 입고대기 | 아직 입고되지 않음 |
| 일부입고 | 일부 수량만 입고됨 |
| 입고완료 | 전체 입고 완료 |
| 취소 | 발주 취소 |

### 불량/교환 상태

| 상태 | 설명 |
|---|---|
| 접수 | 고객 또는 직원이 불량/교환 건 등록 |
| 확인중 | 증상 확인 중 |
| 교환완료 | 교환 처리 완료 |
| 환불완료 | 환불 처리 완료 |
| 공급처반품 | 공급처 반품 대상 |
| 종료 | 처리 완료 후 종료 |

## 데이터베이스 설계표

## 1. users 직원/관리자 계정

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 직원 고유 ID |
| name | varchar(50) | Y | 직원 이름 |
| email | varchar(120) | Y | 로그인 이메일 |
| password_hash | text | Y | 암호화된 비밀번호 |
| role | varchar(20) | Y | admin, manager, staff, viewer |
| phone | varchar(30) | N | 연락처 |
| is_active | boolean | Y | 근무/사용 여부 |
| last_login_at | timestamp | N | 마지막 로그인 시간 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

권한 예시:

| 역할 | 권한 |
|---|---|
| admin | 전체 관리, 직원 계정, 설정 변경 |
| manager | 상품/재고/입고/판매/발주/보고 관리 |
| staff | 입고, 판매, 체크리스트, 마감 보고 작성 |
| viewer | 재고와 대시보드 조회만 가능 |

## 2. suppliers 공급처

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 공급처 ID |
| name | varchar(100) | Y | 공급처명 |
| contact_name | varchar(50) | N | 담당자명 |
| phone | varchar(30) | N | 전화번호 |
| email | varchar(120) | N | 이메일 |
| address | text | N | 주소 |
| default_lead_days | integer | N | 기본 입고 소요일 |
| memo | text | N | 메모 |
| is_active | boolean | Y | 거래 여부 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

## 3. product_categories 상품 카테고리

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 카테고리 ID |
| name | varchar(80) | Y | 카테고리명 예: USB-C, 라이트닝, HDMI |
| parent_id | uuid | N | 상위 카테고리 ID |
| display_order | integer | N | 화면 표시 순서 |
| is_active | boolean | Y | 사용 여부 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

카테고리 예시:

| 대분류 | 세부 예시 |
|---|---|
| 충전 케이블 | USB-C, 라이트닝, 마이크로 5핀, C to C |
| 영상 케이블 | HDMI, DP, VGA, DVI |
| 데이터 케이블 | USB-A to C, USB-A to B, 프린터 케이블 |
| 네트워크 | LAN 케이블, 젠더 |
| 오디오 | AUX, RCA, 광케이블 |
| 액세서리 | 젠더, 허브, 충전기 |

## 4. products 상품 마스터

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 상품 ID |
| product_code | varchar(60) | Y | 상품코드 예: USBC-1M-BLK-001 |
| barcode | varchar(80) | N | 바코드/QR 코드 |
| name | varchar(150) | Y | 상품명 |
| category_id | uuid | Y | 카테고리 ID |
| supplier_id | uuid | N | 기본 공급처 ID |
| connector_type | varchar(50) | N | C타입, 라이트닝, HDMI 등 |
| cable_length | varchar(30) | N | 0.5m, 1m, 2m 등 |
| color | varchar(30) | N | 색상 |
| brand | varchar(80) | N | 브랜드 |
| supports_fast_charge | boolean | Y | 고속충전 지원 여부 |
| supports_data_transfer | boolean | Y | 데이터 전송 가능 여부 |
| max_watt | integer | N | 최대 W 수 예: 60, 100 |
| purchase_price | integer | Y | 기본 매입가 |
| sale_price | integer | Y | 기본 판매가 |
| current_stock | integer | Y | 현재 재고 |
| safety_stock | integer | Y | 안전재고 |
| display_location | varchar(100) | N | 매장 진열 위치 |
| storage_location | varchar(100) | N | 창고/보관 위치 |
| status | varchar(20) | Y | 판매중, 품절, 발주필요, 단종, 숨김 |
| memo | text | N | 상품 메모 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

상품코드 규칙 예시:

| 예시 코드 | 의미 |
|---|---|
| USBC-1M-BLK-001 | USB-C 1m 블랙 001번 |
| LTG-2M-WHT-001 | 라이트닝 2m 화이트 001번 |
| HDMI-3M-BLK-001 | HDMI 3m 블랙 001번 |
| LAN-CAT6-5M-001 | CAT6 LAN 5m 001번 |

## 5. inventory_transactions 재고 변동 내역

모든 재고 증감은 이 테이블에 기록합니다. 현재 재고가 맞지 않을 때 원인을 추적하기 위한 핵심 테이블입니다.

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 재고 변동 ID |
| product_id | uuid | Y | 상품 ID |
| transaction_type | varchar(30) | Y | 입고, 판매, 반품, 불량, 조정, 폐기 |
| quantity_change | integer | Y | 증가/감소 수량. 판매는 음수 |
| stock_after | integer | Y | 변동 후 재고 |
| reference_type | varchar(30) | N | sales, receiving, defect, adjustment 등 |
| reference_id | uuid | N | 연결된 원본 기록 ID |
| reason | text | N | 변동 사유 |
| created_by | uuid | Y | 처리 직원 ID |
| created_at | timestamp | Y | 처리 시간 |

## 6. stock_receipts 입고 기록

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 입고 ID |
| receipt_no | varchar(60) | Y | 입고번호 |
| supplier_id | uuid | Y | 공급처 ID |
| received_at | timestamp | Y | 입고일시 |
| received_by | uuid | Y | 입고 담당자 |
| total_quantity | integer | Y | 총 입고 수량 |
| total_amount | integer | N | 총 매입 금액 |
| memo | text | N | 메모 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

## 7. stock_receipt_items 입고 상세

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 입고 상세 ID |
| receipt_id | uuid | Y | 입고 ID |
| product_id | uuid | Y | 상품 ID |
| quantity | integer | Y | 입고 수량 |
| purchase_price | integer | Y | 입고 매입 단가 |
| defective_quantity | integer | Y | 입고 중 불량 수량 |
| final_stock_after | integer | N | 입고 반영 후 재고 |
| memo | text | N | 메모 |

입고 처리 규칙:

- 입고 수량에서 불량 수량을 제외한 수량만 판매 가능 재고에 반영
- 입고 저장 시 inventory_transactions에 입고 기록 자동 생성

## 8. sales 판매 기록

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 판매 ID |
| sale_no | varchar(60) | Y | 판매번호 |
| sold_at | timestamp | Y | 판매일시 |
| sold_by | uuid | Y | 판매 담당자 |
| payment_method | varchar(30) | N | 카드, 현금, 계좌이체, 기타 |
| total_amount | integer | Y | 총 판매 금액 |
| discount_amount | integer | Y | 할인 금액 |
| memo | text | N | 메모 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

## 9. sale_items 판매 상세

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 판매 상세 ID |
| sale_id | uuid | Y | 판매 ID |
| product_id | uuid | Y | 상품 ID |
| quantity | integer | Y | 판매 수량 |
| sale_price | integer | Y | 판매 단가 |
| discount_amount | integer | Y | 개별 할인 금액 |
| final_stock_after | integer | N | 판매 반영 후 재고 |
| memo | text | N | 메모 |

판매 처리 규칙:

- 판매 등록 시 products.current_stock 자동 차감
- 판매 등록 시 inventory_transactions에 판매 기록 자동 생성
- current_stock이 0이 되면 상품 상태를 품절로 자동 변경
- current_stock이 safety_stock 이하이면 발주필요 상태 또는 발주 추천 목록에 표시

## 10. purchase_orders 발주

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 발주 ID |
| order_no | varchar(60) | Y | 발주번호 |
| supplier_id | uuid | Y | 공급처 ID |
| status | varchar(20) | Y | 발주필요, 발주완료, 입고대기, 일부입고, 입고완료, 취소 |
| ordered_by | uuid | N | 발주 담당자 |
| ordered_at | timestamp | N | 발주일 |
| expected_arrival_at | date | N | 입고 예정일 |
| received_at | timestamp | N | 최종 입고일 |
| memo | text | N | 메모 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

## 11. purchase_order_items 발주 상세

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 발주 상세 ID |
| purchase_order_id | uuid | Y | 발주 ID |
| product_id | uuid | Y | 상품 ID |
| order_quantity | integer | Y | 발주 수량 |
| received_quantity | integer | Y | 입고 완료 수량 |
| purchase_price | integer | N | 예상/확정 매입 단가 |
| memo | text | N | 메모 |

발주 추천 계산 예시:

```text
추천 발주 수량 = max(안전재고 * 2 - 현재재고, 0)
```

## 12. defects_returns 불량/교환/반품

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 불량/교환 ID |
| product_id | uuid | Y | 상품 ID |
| sale_item_id | uuid | N | 기존 판매 상세 ID |
| issue_type | varchar(30) | Y | 불량, 교환, 환불, 공급처반품 |
| symptom | text | Y | 증상 설명 |
| quantity | integer | Y | 수량 |
| status | varchar(20) | Y | 접수, 확인중, 교환완료, 환불완료, 공급처반품, 종료 |
| customer_note | text | N | 고객 관련 메모 |
| supplier_return_needed | boolean | Y | 공급처 반품 필요 여부 |
| handled_by | uuid | Y | 처리 담당자 |
| handled_at | timestamp | N | 처리일시 |
| memo | text | N | 내부 메모 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

## 13. daily_checklists 직원 일일 체크리스트

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 체크리스트 ID |
| checklist_date | date | Y | 체크 날짜 |
| checklist_type | varchar(20) | Y | 오픈, 영업중, 마감 |
| item_text | varchar(200) | Y | 체크 항목 |
| is_checked | boolean | Y | 체크 여부 |
| checked_by | uuid | N | 체크 직원 ID |
| checked_at | timestamp | N | 체크 시간 |
| memo | text | N | 메모 |
| created_at | timestamp | Y | 생성일 |

체크리스트 예시:

| 구분 | 항목 |
|---|---|
| 오픈 | POS/카드단말기 정상 작동 확인 |
| 오픈 | 인기 케이블 진열 수량 확인 |
| 오픈 | C타입 1m/2m 재고 확인 |
| 영업중 | 진열대 정리 및 가격표 확인 |
| 영업중 | 고객이 자주 찾은 상품 메모 |
| 마감 | POS 매출 확인 |
| 마감 | 품절/부족 상품 기록 |
| 마감 | 불량/교환 접수 건 확인 |

## 14. daily_reports 마감 보고

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 마감 보고 ID |
| report_date | date | Y | 보고 날짜 |
| staff_id | uuid | Y | 작성 직원 ID |
| total_sales_amount | integer | Y | 총 매출 |
| total_sales_quantity | integer | Y | 총 판매 수량 |
| cash_amount | integer | N | 현금 매출 |
| card_amount | integer | N | 카드 매출 |
| transfer_amount | integer | N | 계좌이체 매출 |
| best_selling_items | text | N | 많이 팔린 상품 |
| low_stock_items | text | N | 부족/품절 상품 |
| defective_items | text | N | 불량/교환 건 |
| customer_requests | text | N | 고객 문의/요청 |
| tomorrow_tasks | text | N | 내일 할 일 |
| issue_notes | text | N | 재고 이상/특이사항 |
| submitted_at | timestamp | Y | 제출 시간 |
| created_at | timestamp | Y | 생성일 |
| updated_at | timestamp | Y | 수정일 |

마감 보고 입력 양식:

```text
날짜:
근무자:
총 매출:
판매 수량:
가장 많이 팔린 상품:
품절/부족 상품:
불량/교환 건:
고객 문의가 많았던 상품:
재고 이상 여부:
내일 해야 할 일:
특이사항:
```

## 15. stock_adjustments 재고 조정

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 재고 조정 ID |
| product_id | uuid | Y | 상품 ID |
| before_quantity | integer | Y | 조정 전 재고 |
| after_quantity | integer | Y | 조정 후 재고 |
| adjustment_quantity | integer | Y | 조정 수량 |
| reason | varchar(100) | Y | 분실, 오입력, 실사조정, 파손 등 |
| approved_by | uuid | N | 승인 관리자 ID |
| adjusted_by | uuid | Y | 조정 직원 ID |
| adjusted_at | timestamp | Y | 조정일시 |
| memo | text | N | 메모 |

## 16. pos_imports POS/CSV 업로드 이력

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 업로드 ID |
| file_name | varchar(200) | Y | 파일명 |
| imported_by | uuid | Y | 업로드 직원 ID |
| imported_at | timestamp | Y | 업로드 시간 |
| total_rows | integer | Y | 전체 행 수 |
| success_rows | integer | Y | 성공 행 수 |
| failed_rows | integer | Y | 실패 행 수 |
| status | varchar(20) | Y | 대기, 처리완료, 실패 |
| error_log | text | N | 오류 내용 |

## 17. app_settings 운영 설정

| 컬럼명 | 타입 | 필수 | 설명 |
|---|---:|:---:|---|
| id | uuid | Y | 설정 ID |
| setting_key | varchar(100) | Y | 설정 키 |
| setting_value | text | N | 설정 값 |
| description | text | N | 설명 |
| updated_by | uuid | N | 수정 직원 ID |
| updated_at | timestamp | Y | 수정일 |

설정 예시:

| setting_key | 예시 값 | 설명 |
|---|---|---|
| store_name | 케이블샵 | 매장명 |
| default_safety_stock | 5 | 기본 안전재고 |
| low_stock_multiplier | 2 | 발주 추천 배수 |
| currency | KRW | 통화 |

## 관계 요약

| 기준 테이블 | 관계 | 연결 테이블 |
|---|---|---|
| users | 1:N | sales, stock_receipts, daily_reports, daily_checklists |
| suppliers | 1:N | products, stock_receipts, purchase_orders |
| product_categories | 1:N | products |
| products | 1:N | sale_items, stock_receipt_items, inventory_transactions, defects_returns |
| sales | 1:N | sale_items |
| stock_receipts | 1:N | stock_receipt_items |
| purchase_orders | 1:N | purchase_order_items |

## 우선 구현 순서

| 순서 | 기능 | 관련 테이블 |
|---:|---|---|
| 1 | 직원 로그인/권한 | users |
| 2 | 상품 등록/수정 | products, product_categories, suppliers |
| 3 | 현재 재고 조회 | products |
| 4 | 입고 등록 | stock_receipts, stock_receipt_items, inventory_transactions |
| 5 | 판매 등록 | sales, sale_items, inventory_transactions |
| 6 | 안전재고/발주필요 표시 | products, purchase_orders, purchase_order_items |
| 7 | 불량/교환 기록 | defects_returns, inventory_transactions |
| 8 | 직원 체크리스트 | daily_checklists |
| 9 | 마감 보고 | daily_reports |
| 10 | POS CSV 업로드 | pos_imports, sales, sale_items |

## 1차 MVP에서 꼭 필요한 테이블

처음 개발할 때는 아래 9개만 먼저 구현해도 운영 가능합니다.

1. users
2. suppliers
3. product_categories
4. products
5. inventory_transactions
6. stock_receipts
7. stock_receipt_items
8. sales
9. sale_items
10. daily_reports

## 관리자 대시보드 주요 쿼리 기준

| 화면 지표 | 기준 |
|---|---|
| 오늘 매출 | sales.sold_at이 오늘인 total_amount 합계 |
| 오늘 판매 수량 | sale_items.quantity 합계 |
| 품절 상품 | products.current_stock = 0 |
| 발주 필요 상품 | products.current_stock <= products.safety_stock |
| 베스트 상품 | 최근 7일 sale_items.quantity 합계 상위 |
| 장기 미판매 상품 | 최근 30일 판매 이력이 없는 상품 |
| 불량 많은 상품 | defects_returns 기준 상품별 건수 상위 |

## 추후 확장 기능

- 바코드/QR 스캔 입출고
- POS CSV 자동 매칭
- 공급처별 발주서 PDF/엑셀 생성
- 월간 판매 리포트
- 상품별 마진율 분석
- 카카오/문자 발주 알림
- 온라인몰 연동
- 직원별 업무 수행률 리포트
