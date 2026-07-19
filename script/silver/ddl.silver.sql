/*
===============================================================================
DDL Script: Tạo bảng cho tầng Silver
===============================================================================
Mục đích:
    Script này tạo các bảng trong schema 'silver'. Nếu bảng đã tồn tại,
    bảng sẽ bị xóa và tạo lại từ đầu.
    Chạy script này để định nghĩa lại cấu trúc DDL của tầng Silver.

Cảnh báo:
    Script sẽ XÓA toàn bộ bảng hiện có trong schema 'silver' cùng với
    dữ liệu bên trong. Hãy chắc chắn trước khi chạy trên môi trường có
    dữ liệu quan trọng.

Ghi chú về cấu trúc:
    Cấu trúc bảng Silver gần như giống hệt tầng Bronze, ngoại trừ:
      - Thêm cột metadata 'dwh_create_date' ghi lại thời điểm nạp dữ liệu
      - crm_prd_info: bổ sung cột 'cat_id' được tách ra từ 'prd_key'
      - crm_prd_info: prd_start_dt / prd_end_dt đổi từ DATETIME2 sang DATE
      - crm_sales_details: 3 cột ngày đổi từ INT sang DATE
===============================================================================
*/

-- =============================================================================
-- CRM Source System
-- =============================================================================

DROP TABLE IF EXISTS silver.crm_cust_info;
CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),
    cst_gndr            VARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date     DATETIME2(6)
);
GO

DROP TABLE IF EXISTS silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
    prd_id              INT,
    cat_id              VARCHAR(50),
    prd_key             VARCHAR(50),
    prd_nm              VARCHAR(50),
    prd_cost            INT,
    prd_line            VARCHAR(50),
    prd_start_dt        DATE,
    prd_end_dt          DATE,
    dwh_create_date     DATETIME2(6)
);
GO

DROP TABLE IF EXISTS silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num         VARCHAR(50),
    sls_prd_key         VARCHAR(50),
    sls_cust_id         INT,
    sls_order_dt        DATE,
    sls_ship_dt         DATE,
    sls_due_dt          DATE,
    sls_sales           INT,
    sls_quantity        INT,
    sls_price           INT,
    dwh_create_date     DATETIME2(6)
);
GO

-- =============================================================================
-- ERP Source System
-- =============================================================================

DROP TABLE IF EXISTS silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 (
    cid                 VARCHAR(50),
    bdate               DATE,
    gen                 VARCHAR(50),
    dwh_create_date     DATETIME2(6)
);
GO

DROP TABLE IF EXISTS silver.erp_loc_a101;
CREATE TABLE silver.erp_loc_a101 (
    cid                 VARCHAR(50),
    cntry               VARCHAR(50),
    dwh_create_date     DATETIME2(6)
);
GO

DROP TABLE IF EXISTS silver.erp_px_cat_g1v2;
CREATE TABLE silver.erp_px_cat_g1v2 (
    id                  VARCHAR(50),
    cat                 VARCHAR(50),
    subcat              VARCHAR(50),
    maintenance         VARCHAR(50),
    dwh_create_date     DATETIME2(6)
);
GO
