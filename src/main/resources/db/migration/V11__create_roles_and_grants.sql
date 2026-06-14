-- Migration: V11 - Create database roles for Homestay Owner and Employee and grant permissions

-- 1. Create Roles if they do not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'chu_homestay') THEN
        CREATE ROLE chu_homestay WITH LOGIN PASSWORD 'ChuHomestay@2026';
    END IF;
    
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'nhan_vien') THEN
        CREATE ROLE nhan_vien WITH LOGIN PASSWORD 'NhanVien@2026';
    END IF;
END
$$;

-- 2. Grant permissions to Owner (chu_homestay)
-- Full privileges on all schemas
GRANT USAGE, CREATE ON SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO chu_homestay;

-- Ensure owner gets privileges on future tables/sequences/functions automatically
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON TABLES TO chu_homestay;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON SEQUENCES TO chu_homestay;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON FUNCTIONS TO chu_homestay;

-- 3. Grant permissions to Employee (nhan_vien)
-- Employee needs USAGE on schemas to run queries and call functions
GRANT USAGE ON SCHEMA public, quanly, nhansu, khachhang, hoadon TO nhan_vien;

-- Operational data (khachhang schema): Can SELECT, INSERT, UPDATE khách hàng, hội viên, đoàn khách
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA khachhang TO nhan_vien;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA khachhang TO nhan_vien;

-- Billing data (hoadon schema): Can SELECT, INSERT, UPDATE hóa đơn, hóa đơn thuê phòng, hóa đơn dịch vụ
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA hoadon TO nhan_vien;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA hoadon TO nhan_vien;

-- Facility management (quanly schema): Can SELECT details of rooms, branches, and facilities. Can also UPDATE room status (phong.trang_thai) and facility maintenance.
GRANT SELECT ON ALL TABLES IN SCHEMA quanly TO nhan_vien;
GRANT UPDATE (trang_thai) ON quanly.phong TO nhan_vien;
GRANT INSERT, UPDATE, DELETE ON quanly.cosovatchat_duoc_baotri TO nhan_vien;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA quanly TO nhan_vien;

-- HR data (nhansu schema): Can only SELECT employee info (name, job title), cannot modify HR data
GRANT SELECT ON nhansu.nhanvien TO nhan_vien;
GRANT SELECT ON nhansu.chucvu TO nhan_vien;

-- Grant EXECUTE on all functions in schemas
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO nhan_vien;
