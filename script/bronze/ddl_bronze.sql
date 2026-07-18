CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    DECLARE @start_time DATETIME2(6), @end_time DATETIME2(6);
    DECLARE @batch_start DATETIME2(6), @batch_end DATETIME2(6);

    BEGIN TRY
        SET @batch_start = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '>> Deleting Table: bronze.crm_cust_info';
        DELETE FROM bronze.crm_cust_info;
        PRINT '>> Inserting Data Into: bronze.crm_cust_info';
        INSERT INTO bronze.crm_cust_info
        SELECT * FROM lh_source_files.dbo.cust_info;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: '
              + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + ' seconds';
        PRINT '------------------';

        SET @batch_end = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer Completed';
        PRINT 'Total Duration: '
              + CAST(DATEDIFF(SECOND, @batch_start, @batch_end) AS VARCHAR) + ' seconds';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR);
        PRINT '================================================';
    END CATCH
END;


exec bronze.load_bronze
