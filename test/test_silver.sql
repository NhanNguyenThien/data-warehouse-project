/*
===============================================================================
Quality Checks: Tầng Silver
===============================================================================
Mục đích:
    Kiểm tra tính toàn vẹn, nhất quán và chính xác của dữ liệu trong tầng
    Silver. Bao gồm các kiểm tra:
      - Primary key: không NULL, không trùng lặp
      - Chuỗi: không còn khoảng trắng thừa
      - Cột low-cardinality: giá trị đã được chuẩn hóa
      - Ngày tháng: nằm trong khoảng hợp lệ và đúng thứ tự
      - Quy tắc nghiệp vụ: tính nhất quán giữa các cột liên quan
      - Khả năng kết nối key giữa các bảng

Cách sử dụng:
    Chạy script sau mỗi lần thực thi silver.load_silver.
    Kết quả mong đợi: các query trả về RỖNG, trừ các query DISTINCT
    (dùng để xem giá trị đã chuẩn hóa).
===============================================================================
*/

-- =============================================================================
-- silver.crm_cust_info
-- =============================================================================

-- Kiểm tra NULL hoặc trùng lặp ở primary key
-- Kỳ vọng: không có kết quả
SELECT cst_id, COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Kiểm tra khoảng trắng thừa
-- Kỳ vọng: không có kết quả
SELECT cst_firstname FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_lastname FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- Kiểm tra chuẩn hóa dữ liệu
-- Kỳ vọng: chỉ có Male / Female / n/a và Single / Married / n/a
SELECT DISTINCT cst_gndr FROM silver.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM silver.crm_cust_info;

-- =============================================================================
-- silver.crm_prd_info
-- =============================================================================

-- Kiểm tra NULL hoặc trùng lặp ở primary key
-- Kỳ vọng: không có kết quả
SELECT prd_id, COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Kiểm tra khoảng trắng thừa
-- Kỳ vọng: không có kết quả
SELECT prd_nm FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- Kiểm tra chi phí NULL hoặc âm
-- Kỳ vọng: không có kết quả
SELECT prd_cost FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Kiểm tra chuẩn hóa dữ liệu
-- Kỳ vọng: Mountain / Road / Other Sales / Touring / n/a
SELECT DISTINCT prd_line FROM silver.crm_prd_info;

-- Kiểm tra thứ tự ngày không hợp lệ
-- Kỳ vọng: không có kết quả
SELECT * FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- =============================================================================
-- silver.crm_sales_details
-- =============================================================================

-- Kiểm tra thứ tự ngày không hợp lệ
-- Kỳ vọng: không có kết quả
SELECT * FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
   OR sls_order_dt > sls_due_dt;

-- Kiểm tra tính nhất quán: sales = quantity * price
-- Các giá trị không được NULL, âm hoặc bằng 0
-- Kỳ vọng: không có kết quả
SELECT DISTINCT sls_sales, sls_quantity, sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL
   OR sls_quantity IS NULL
   OR sls_price IS NULL
   OR sls_sales <= 0
   OR sls_quantity <= 0
   OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- =============================================================================
-- silver.erp_cust_az12
-- =============================================================================

-- Kiểm tra ngày sinh nằm ngoài khoảng hợp lệ
-- Kỳ vọng: không có ngày sinh trong tương lai
SELECT DISTINCT bdate FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- Kiểm tra chuẩn hóa dữ liệu
-- Kỳ vọng: Male / Female / n/a
SELECT DISTINCT gen FROM silver.erp_cust_az12;

-- Kiểm tra khả năng kết nối với bảng khách hàng CRM
-- Kỳ vọng: không có kết quả
SELECT cid FROM silver.erp_cust_az12
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- =============================================================================
-- silver.erp_loc_a101
-- =============================================================================

-- Kiểm tra chuẩn hóa dữ liệu
-- Kỳ vọng: tên quốc gia đầy đủ, không còn mã viết tắt
SELECT DISTINCT cntry FROM silver.erp_loc_a101
ORDER BY cntry;

-- Kiểm tra khả năng kết nối với bảng khách hàng CRM
-- Kỳ vọng: không có kết quả
SELECT cid FROM silver.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- =============================================================================
-- silver.erp_px_cat_g1v2
-- =============================================================================

-- Kiểm tra khoảng trắng thừa
-- Kỳ vọng: không có kết quả
SELECT * FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);

-- Kiểm tra chuẩn hóa dữ liệu
SELECT DISTINCT cat FROM silver.erp_px_cat_g1v2;
SELECT DISTINCT subcat FROM silver.erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2;

-- Kiểm tra khả năng kết nối với bảng sản phẩm CRM
-- Kỳ vọng: không có kết quả
SELECT id FROM silver.erp_px_cat_g1v2
WHERE id NOT IN (SELECT cat_id FROM silver.crm_prd_info);
