-- ============================================================
-- File: 01_create_database.sql
-- Mục đích: Tạo database quanlykhachsan, cấu hình locale,
--           tạo schemas và thiết lập search_path
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

-- LƯU Ý: Chạy file này bằng tài khoản superuser (postgres)
-- Kết nối vào database 'postgres' trước khi chạy lệnh CREATE DATABASE

-- 1. Tạo database
CREATE DATABASE quanlykhachsan
    WITH ENCODING = 'UTF8'
    LC_COLLATE = 'vi-VN'
    LC_CTYPE = 'vi-VN'
    TEMPLATE = template0;

-- 2. Cấu hình database-level settings
ALTER DATABASE quanlykhachsan SET lc_monetary TO 'vi-VN';

-- ============================================================
-- KẾT NỐI VÀO DATABASE quanlykhachsan TRƯỚC KHI CHẠY TIẾP
-- \c quanlykhachsan
-- ============================================================

-- 3. Cấu hình session-level settings
SET lc_monetary TO 'vi-VN';
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

-- 4. Tạo schemas
CREATE SCHEMA IF NOT EXISTS quanly;
CREATE SCHEMA IF NOT EXISTS nhansu;
CREATE SCHEMA IF NOT EXISTS khachhang;
CREATE SCHEMA IF NOT EXISTS hoadon;

-- 5. Thiết lập search_path mặc định cho database
ALTER DATABASE quanlykhachsan SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;
SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;
