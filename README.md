# Modern Data Warehouse on Microsoft Fabric

Dự án xây dựng data warehouse hiện đại trên Microsoft Fabric, hợp nhất dữ liệu bán hàng từ hai hệ thống nguồn (CRM và ERP) thành một mô hình dữ liệu sẵn sàng cho phân tích và báo cáo.

---

## Mục tiêu

Xây dựng một warehouse theo kiến trúc Medallion, thực hiện toàn bộ vòng đời ETL: từ nạp dữ liệu thô, làm sạch, chuẩn hóa, cho đến tích hợp thành star schema phục vụ BI.

## Kiến trúc

Dự án áp dụng **Medallion Architecture** với ba tầng, tuân thủ nguyên tắc *separation of concerns* — mỗi tầng có một trách nhiệm duy nhất, không chồng lấn.

| Tầng | Mục đích | Đối tượng | Phương thức nạp | Transformation |
|---|---|---|---|---|
| **Bronze** | Lưu dữ liệu thô nguyên trạng từ nguồn, phục vụ truy vết và debug | Table | Full load (delete & insert) | Không |
| **Silver** | Dữ liệu đã làm sạch, chuẩn hóa | Table | Full load (delete & insert) | Cleansing, standardization, derived columns, enrichment |
| **Gold** | Dữ liệu sẵn sàng cho nghiệp vụ | View | Không (virtual) | Business logic, data integration, star schema |

**Luồng dữ liệu:**
> Sơ đồ chi tiết: xem `docs/data_architecture.png` và `docs/data_flow.png`

## Tech Stack

- **Microsoft Fabric** — Lakehouse (lưu file nguồn), Warehouse (3 tầng bronze/silver/gold)
- **T-SQL** — toàn bộ logic ETL và transformation
- **Data Pipeline** — điều phối và lập lịch chạy ETL
- **Power BI** — tầng tiêu thụ
- **Draw.io** — vẽ kiến trúc, data flow, data model

## Nguồn dữ liệu

Hai hệ thống nguồn, cung cấp dưới dạng file CSV:

| Nguồn | Bảng | Mô tả |
|---|---|---|
| CRM | `cust_info` | Thông tin khách hàng |
| CRM | `prd_info` | Thông tin sản phẩm (có lịch sử giá) |
| CRM | `sales_details` | Giao dịch bán hàng |
| ERP | `CUST_AZ12` | Ngày sinh, giới tính khách hàng |
| ERP | `LOC_A101` | Quốc gia khách hàng |
| ERP | `PX_CAT_G1V2` | Danh mục sản phẩm |

## Data Model (Gold Layer)

Star schema gồm một fact table và hai dimension:
dim_customers
          |
          | 1
          |
          | *
    fact_sales
          | *
          |
          | 1
    dim_products
- `fact_sales` — giao dịch bán hàng, chứa surrogate key từ hai dimension
- `dim_customers` — tích hợp từ 3 bảng nguồn (CRM + 2 bảng ERP)
- `dim_products` — tích hợp từ 2 bảng nguồn, chỉ giữ dữ liệu hiện tại (lọc bỏ lịch sử)

Surrogate key được sinh bằng `ROW_NUMBER()` do Fabric Warehouse không hỗ trợ `IDENTITY`.

> Chi tiết từng cột: xem `docs/data_catalog.md`

## Các transformation đã thực hiện

**Data cleansing**
- Loại bỏ bản ghi trùng theo primary key (`ROW_NUMBER` + lọc bản mới nhất)
- Xóa khoảng trắng thừa (`TRIM`)
- Xử lý giá trị thiếu (`NULL` → `n/a`)
- Xử lý giá trị không hợp lệ (ngày sinh trong tương lai, giá âm)
- Ép kiểu dữ liệu (integer → date)

**Data standardization**
- Chuẩn hóa mã sang giá trị thân thiện: `M`/`F` → `Male`/`Female`, `DE` → `Germany`
- Thống nhất các biến thể cùng nghĩa: `US`/`USA`/`United States` → `United States`

**Derived columns & enrichment**
- Tách `prd_key` thành `cat_id` và `prd_key` để join với bảng danh mục
- Tái tạo `prd_end_dt` từ `prd_start_dt` bằng `LEAD()` để loại bỏ overlap trong lịch sử giá

**Business rules**
- Tính lại `sales_amount` khi vi phạm quy tắc `sales = quantity × price`
- Suy ra `price` từ `sales / quantity` khi giá trị gốc không hợp lệ

**Data integration**
- Hợp nhất thông tin giới tính từ CRM (master) và ERP (bổ sung khi CRM thiếu)

## Cấu trúc repository
## Cách chạy

1. Tạo workspace trên Fabric (cần gán capacity)
2. Tạo **Lakehouse**, upload các file trong `datasets/` vào phần Files
3. Tạo **Warehouse**, chạy `scripts/init_warehouse.sql` để tạo 3 schema
4. Chạy DDL cho bronze và silver
5. Nạp dữ liệu:
```sql
   EXEC bronze.load_bronze;
   EXEC silver.load_silver;
```
6. Chạy `scripts/gold/ddl_gold.sql` để tạo các view
7. (Tùy chọn) Tạo Data Pipeline để tự động hóa bước 5

## Điểm khác biệt so với triển khai trên SQL Server

Dự án được port sang Fabric, một số điều chỉnh cần thiết:

| SQL Server | Fabric Warehouse |
|---|---|
| `BULK INSERT` từ đường dẫn local | `COPY INTO` từ OneLake/Blob |
| `TRUNCATE TABLE` | `DELETE FROM` (chưa hỗ trợ TRUNCATE) |
| `IDENTITY` cho surrogate key | `ROW_NUMBER()` |

Phần lớn logic transformation (window functions, `CASE WHEN`, các hàm chuỗi) giữ nguyên.

## Data Quality

Các script trong `tests/` kiểm tra:
- Tính duy nhất và không NULL của primary key / surrogate key
- Không còn khoảng trắng thừa
- Tính nhất quán của các cột low-cardinality
- Thứ tự hợp lệ của các cột ngày
- Tính toàn vẹn khi join fact với dimension

Nên chạy sau mỗi lần ETL như một quality gate.

## Ghi nhận

Dự án dựa trên khóa học *SQL Data Warehouse from Scratch* của **Baraa Khatib Salkini** (Data With Baraa), được điều chỉnh để triển khai trên Microsoft Fabric.

## License

MIT

## Về tôi

<Tên bạn> — <một dòng giới thiệu>

- LinkedIn: <link>
- Email: <email>
