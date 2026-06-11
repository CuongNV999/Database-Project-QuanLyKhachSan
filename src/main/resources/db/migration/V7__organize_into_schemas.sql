-- 1. Create schemas
CREATE SCHEMA IF NOT EXISTS quanly;
CREATE SCHEMA IF NOT EXISTS nhansu;
CREATE SCHEMA IF NOT EXISTS khachhang;
CREATE SCHEMA IF NOT EXISTS hoadon;

-- 2. Configure default search path for database and current session
ALTER DATABASE quanlykhachsan SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;
SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- 3. Move tables to their schemas (PostgreSQL automatically moves owned sequences)
ALTER TABLE public.chinhanh SET SCHEMA quanly;
ALTER TABLE public.chusohuu SET SCHEMA quanly;
ALTER TABLE public.chinhanh_chusohuu SET SCHEMA quanly;
ALTER TABLE public.loaiphong SET SCHEMA quanly;
ALTER TABLE public.phong SET SCHEMA quanly;
ALTER TABLE public.cosovatchat SET SCHEMA quanly;
ALTER TABLE public.phong_trangbi_csvc SET SCHEMA quanly;

ALTER TABLE public.chucvu SET SCHEMA nhansu;
ALTER TABLE public.nhanvien SET SCHEMA nhansu;

ALTER TABLE public.hanghoivien SET SCHEMA khachhang;
ALTER TABLE public.hoivien SET SCHEMA khachhang;
ALTER TABLE public.doankhach SET SCHEMA khachhang;
ALTER TABLE public.khachhang SET SCHEMA khachhang;
ALTER TABLE public.khachhang_treem SET SCHEMA khachhang;
ALTER TABLE public.truongdoan SET SCHEMA khachhang;

ALTER TABLE public.dichvu SET SCHEMA hoadon;
ALTER TABLE public.hoadon SET SCHEMA hoadon;
ALTER TABLE public.hoadon_thue_phong SET SCHEMA hoadon;
ALTER TABLE public.hoadon_sudung_dichvu SET SCHEMA hoadon;

-- 4. Move views to their schemas
ALTER VIEW public.v_phong_status_detail SET SCHEMA quanly;
ALTER VIEW public.v_thong_tin_chu_so_huu_chi_nhanh SET SCHEMA quanly;
ALTER VIEW public.v_doanh_thu_chi_nhanh SET SCHEMA hoadon;

-- 5. Move functions to their schemas
ALTER FUNCTION public.func_tinh_tien_phong(integer, integer) SET SCHEMA hoadon;
ALTER FUNCTION public.func_cap_nhat_diem_tich_luy() SET SCHEMA hoadon;
ALTER FUNCTION public.func_dat_phong_auto_update_status() SET SCHEMA hoadon;
ALTER FUNCTION public.func_check_booking_overlap() SET SCHEMA hoadon;
ALTER FUNCTION public.func_prevent_paid_invoice_edit() SET SCHEMA hoadon;
ALTER FUNCTION public.func_check_child_age() SET SCHEMA khachhang;
ALTER FUNCTION public.func_them_hoa_don_nhanh(integer, integer, character varying) SET SCHEMA hoadon;
