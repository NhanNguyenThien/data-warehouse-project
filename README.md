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
