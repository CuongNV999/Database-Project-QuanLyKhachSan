-- ============================================================
-- File: 08_create_roles.sql
-- Mục đích: Tạo roles và phân quyền cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V35
-- LƯU Ý: Chạy bằng tài khoản superuser (postgres)
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- 1. TẠO ROLES
-- ============================================================

-- 1.1. Role Admin (hệ thống)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'admin') THEN
        CREATE ROLE admin WITH LOGIN PASSWORD 'AdminSystem@2026';
    END IF;
END
$$;

-- 1.2. Role Chủ Homestay
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'chu_homestay') THEN
        CREATE ROLE chu_homestay WITH LOGIN PASSWORD 'ChuHomestay@2026';
    END IF;
END
$$;

-- 1.3. Role Nhân viên
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nhan_vien') THEN
        CREATE ROLE nhan_vien WITH LOGIN PASSWORD 'NhanVien@2026';
    END IF;
END
$$;


-- ============================================================
-- 2. PHÂN QUYỀN ADMIN (Toàn quyền)
-- ============================================================

GRANT USAGE, CREATE ON SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;

-- Tự động cấp quyền cho các đối tượng tương lai
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON TABLES TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON SEQUENCES TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON FUNCTIONS TO admin;


-- ============================================================
-- 3. PHÂN QUYỀN CHỦ HOMESTAY (Gần toàn quyền, hạn chế bảng đa chi nhánh)
-- ============================================================

GRANT USAGE, CREATE ON SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;

-- Tự động cấp quyền cho các đối tượng tương lai
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON TABLES TO chu_homestay;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON SEQUENCES TO chu_homestay;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON FUNCTIONS TO chu_homestay;

-- Thu hồi quyền ghi trên các bảng đa chi nhánh (chỉ admin mới quản lý)
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE quanly.chinhanh FROM chu_homestay;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE quanly.chusohuu FROM chu_homestay;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE quanly.chinhanh_chusohuu FROM chu_homestay;


-- ============================================================
-- 4. PHÂN QUYỀN NHÂN VIÊN (Hạn chế, chỉ thao tác nghiệp vụ hàng ngày)
-- ============================================================

-- 4.1. Quyền truy cập schemas
GRANT USAGE ON SCHEMA public, quanly, nhansu, khachhang, hoadon TO nhan_vien;

-- 4.2. Dữ liệu khách hàng: Xem, thêm, sửa
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA khachhang TO nhan_vien;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA khachhang TO nhan_vien;

-- 4.3. Dữ liệu hóa đơn: Xem, thêm, sửa
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA hoadon TO nhan_vien;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA hoadon TO nhan_vien;

-- 4.4. Quản lý phòng/chi nhánh: Chỉ xem, có thể cập nhật trạng thái phòng
GRANT SELECT ON ALL TABLES IN SCHEMA quanly TO nhan_vien;
GRANT UPDATE (trang_thai) ON quanly.phong TO nhan_vien;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA quanly TO nhan_vien;

-- 4.5. Nhân sự: Chỉ xem
GRANT SELECT ON nhansu.nhanvien TO nhan_vien;

-- 4.6. Chạy functions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO nhan_vien;
