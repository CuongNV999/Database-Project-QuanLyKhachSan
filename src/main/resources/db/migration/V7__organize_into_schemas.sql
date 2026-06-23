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
CREATE OR REPLACE VIEW quanly.v_thong_tin_chu_so_huu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    cn.dia_chi AS dia_chi_chi_nhanh,
    csh.id_csh,
    csh.ten_csh AS ten_chu_so_huu,
    csh.email AS email_chu_so_huu,
    csh.sdt AS sdt_chu_so_huu
FROM quanly.chinhanh cn
JOIN quanly.chinhanh_chusohuu cc ON cn.id_cn = cc.id_cn
JOIN quanly.chusohuu csh ON cc.id_csh = csh.id_csh;
ALTER VIEW public.v_doanh_thu_chi_nhanh SET SCHEMA hoadon;

-- 5. Move functions to their schemas
ALTER FUNCTION public.func_tinh_tien_phong(integer, integer) SET SCHEMA hoadon;
ALTER FUNCTION public.func_cap_nhat_diem_tich_luy() SET SCHEMA hoadon;
ALTER FUNCTION public.func_dat_phong_auto_update_status() SET SCHEMA hoadon;
ALTER FUNCTION public.func_check_booking_overlap() SET SCHEMA hoadon;
ALTER FUNCTION public.func_prevent_paid_invoice_edit() SET SCHEMA hoadon;
ALTER FUNCTION public.func_check_child_age() SET SCHEMA khachhang;
CREATE OR REPLACE FUNCTION public.func_them_hoa_don_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS INT AS $$
DECLARE
    v_id_hd INT;
BEGIN
    INSERT INTO hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, p_phuongthuc, p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;
    
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

ALTER FUNCTION public.func_them_hoa_don_nhanh(integer, integer, character varying) SET SCHEMA hoadon;
