-- Migration: V35 - Add new database admin role and restrict chu_homestay role on system-wide multi-branch tables

-- 1. Create admin role if it does not exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'admin') THEN
        CREATE ROLE admin WITH LOGIN PASSWORD 'AdminSystem@2026';
    END IF;
END
$$;

-- 2. Grant full privileges to admin role on all schemas
GRANT USAGE, CREATE ON SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public, quanly, nhansu, khachhang, hoadon TO admin;

-- Ensure admin gets privileges on future tables/sequences/functions automatically
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON TABLES TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON SEQUENCES TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public, quanly, nhansu, khachhang, hoadon GRANT ALL ON FUNCTIONS TO admin;

-- 3. Revoke write privileges (INSERT, UPDATE, DELETE, TRUNCATE) on multi-branch tables from chu_homestay
-- chu_homestay can still SELECT (read) from these tables for reporting and reference.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE quanly.chinhanh FROM chu_homestay;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE quanly.chusohuu FROM chu_homestay;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLE quanly.chinhanh_chusohuu FROM chu_homestay;
