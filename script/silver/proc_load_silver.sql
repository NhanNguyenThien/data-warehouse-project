/*
===============================================================================
Stored Procedure: silver.load_silver  (Bronze -> Silver)
===============================================================================
Mục đích:
    Thực hiện quy trình ETL nạp dữ liệu từ tầng Bronze vào tầng Silver.

Hành động:
    - Xóa toàn bộ dữ liệu hiện có trong các bảng Silver
    - Chèn dữ liệu đã được làm sạch và chuẩn hóa từ Bronze sang Silver

Các phép biến đổi được áp dụng:
    - Loại bỏ bản ghi trùng primary key, chỉ giữ bản ghi mới nhất
    - Xóa khoảng trắng thừa ở các cột chuỗi
    - Chuẩn hóa mã viết tắt sang giá trị thân thiện (M/F -> Male/Female)
    - Thay giá trị thiếu bằng 'n/a'
    - Tách prd_key thành cat_id và prd_key
    - Tái tạo prd_end_dt từ prd_start_dt của bản ghi kế tiếp (LEAD)
    - Ép kiểu ngày từ INT sang DATE, loại bỏ giá trị không hợp lệ
    - Áp dụng quy tắc nghiệp vụ: sales = quantity * price

Tham số:
    Không có tham số đầu vào và không trả về giá trị.

Cách sử dụng:
    EXEC silver.load_silver;

Ghi chú về nền tảng (Microsoft Fabric):
    - Fabric Warehouse không hỗ trợ TRUNCATE TABLE, dùng DELETE FROM thay thế
    - Fabric Warehouse không hỗ trợ ràng buộc DEFAULT, cột dwh_create_date
      được gán GETDATE() trực tiếp trong câu INSERT
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    DECLARE @start_time  DATETIME2(6),
            @end_time    DATETIME2(6),
            @batch_start DATETIME2(6),
            @batch_end   DATETIME2(6);

    BEGIN TRY
        SET @batch_start = GETDATE();

        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        PRINT '';
        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        -- =====================================================
        -- 1. silver.crm_cust_info
        -- =====================================================
        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: silver.crm_cust_info';
        DELETE FROM silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date, dwh_create_date
        )
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,
            CASE UPPER(TRIM(cst_marital_status))
                 WHEN 'S' THEN 'Single'
                 WHEN 'M' THEN 'Married'
                 ELSE 'n/a'
            END AS cst_marital_status,
            CASE UPPER(TRIM(cst_gndr))
                 WHEN 'F' THEN 'Female'
                 WHEN 'M' THEN 'Male'
                 ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date,
            GETDATE()
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY cst_id
                       ORDER BY cst_create_date DESC
                   ) AS flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) t
        WHERE flag_last = 1;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
              + ' seconds';
        PRINT '------------------';

        -- =====================================================
        -- 2. silver.crm_prd_info
        -- =====================================================
        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: silver.crm_prd_info';
        DELETE FROM silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id, cat_id, prd_key, prd_nm, prd_cost,
            prd_line, prd_start_dt, prd_end_dt, dwh_create_date
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
            SUBSTRING(prd_key, 7, LEN(prd_key))         AS prd_key,
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                 WHEN 'M' THEN 'Mountain'
                 WHEN 'R' THEN 'Road'
                 WHEN 'S' THEN 'Other Sales'
                 WHEN 'T' THEN 'Touring'
                 ELSE 'n/a'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) AS prd_start_dt,
            CAST(
                DATEADD(DAY, -1,
                    LEAD(prd_start_dt) OVER (
                        PARTITION BY prd_key
                        ORDER BY prd_start_dt
                    )
                ) AS DATE
            ) AS prd_end_dt,
            GETDATE()
        FROM bronze.crm_prd_info;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
              + ' seconds';
        PRINT '------------------';

        -- =====================================================
        -- 3. silver.crm_sales_details
        -- =====================================================
        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: silver.crm_sales_details';
        DELETE FROM silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id,
            sls_order_dt, sls_ship_dt, sls_due_dt,
            sls_sales, sls_quantity, sls_price, dwh_create_date
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                 ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            CASE WHEN sls_sales IS NULL
                       OR sls_sales <= 0
                       OR sls_sales != sls_quantity * ABS(sls_price)
                 THEN sls_quantity * ABS(sls_price)
                 ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE WHEN sls_price IS NULL OR sls_price <= 0
                 THEN sls_sales / NULLIF(sls_quantity, 0)
                 ELSE sls_price
            END AS sls_price,
            GETDATE()
        FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
              + ' seconds';
        PRINT '------------------';

        PRINT '';
        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';

        -- =====================================================
        -- 4. silver.erp_cust_az12
        -- =====================================================
        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: silver.erp_cust_az12';
        DELETE FROM silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid, bdate, gen, dwh_create_date
        )
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                 ELSE cid
            END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL
                 ELSE bdate
            END AS bdate,
            CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                 WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                 ELSE 'n/a'
            END AS gen,
            GETDATE()
        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
              + ' seconds';
        PRINT '------------------';

        -- =====================================================
        -- 5. silver.erp_loc_a101
        -- =====================================================
        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: silver.erp_loc_a101';
        DELETE FROM silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid, cntry, dwh_create_date
        )
        SELECT
            REPLACE(cid, '-', '') AS cid,
            CASE WHEN TRIM(cntry) = 'DE' THEN 'Germany'
                 WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                 WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                 ELSE TRIM(cntry)
            END AS cntry,
            GETDATE()
        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
              + ' seconds';
        PRINT '------------------';

        -- =====================================================
        -- 6. silver.erp_px_cat_g1v2
        -- =====================================================
        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: silver.erp_px_cat_g1v2';
        DELETE FROM silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id, cat, subcat, maintenance, dwh_create_date
        )
        SELECT
            id,
            cat,
            subcat,
            maintenance,
            GETDATE()
        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR)
              + ' seconds';
        PRINT '------------------';

        -- =====================================================
        -- Kết thúc
        -- =====================================================
        SET @batch_end = GETDATE();
        PRINT '';
        PRINT '================================================';
        PRINT 'Loading Silver Layer Completed';
        PRINT 'Total Duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, @batch_end) AS VARCHAR)
              + ' seconds';
        PRINT '================================================';

    END TRY
    BEGIN CATCH
        PRINT '';
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: '  + CAST(ERROR_NUMBER() AS VARCHAR);
        PRINT 'Error State: '   + CAST(ERROR_STATE() AS VARCHAR);
        PRINT '================================================';
    END CATCH
END;
