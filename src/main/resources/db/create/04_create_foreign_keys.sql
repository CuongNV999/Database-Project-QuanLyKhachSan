-- ============================================================
-- File: 04_create_foreign_keys.sql
-- Mục đích: Tạo tất cả ràng buộc khóa ngoại cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- SCHEMA: quanly
-- ============================================================

-- chinhanh_chusohuu -> chinhanh
ALTER TABLE quanly.chinhanh_chusohuu
    ADD CONSTRAINT chinhanh_chusohuu_id_cn_fkey
    FOREIGN KEY (id_cn) REFERENCES quanly.chinhanh(id_cn) ON DELETE CASCADE;

-- chinhanh_chusohuu -> chusohuu
ALTER TABLE quanly.chinhanh_chusohuu
    ADD CONSTRAINT chinhanh_chusohuu_id_csh_fkey
    FOREIGN KEY (id_csh) REFERENCES quanly.chusohuu(id_csh) ON DELETE CASCADE;

-- loaiphong -> chinhanh
ALTER TABLE quanly.loaiphong
    ADD CONSTRAINT loaiphong_id_cn_fkey
    FOREIGN KEY (id_cn) REFERENCES quanly.chinhanh(id_cn) ON DELETE CASCADE;

-- phong -> loaiphong
ALTER TABLE quanly.phong
    ADD CONSTRAINT phong_id_lp_fkey
    FOREIGN KEY (id_lp) REFERENCES quanly.loaiphong(id_lp) ON DELETE SET NULL;

-- phong -> chinhanh (thêm từ V17)
ALTER TABLE quanly.phong
    ADD CONSTRAINT phong_id_cn_fkey
    FOREIGN KEY (id_cn) REFERENCES quanly.chinhanh(id_cn) ON DELETE CASCADE;

-- phong_trangbi_csvc -> phong
ALTER TABLE quanly.phong_trangbi_csvc
    ADD CONSTRAINT phong_trangbi_csvc_id_p_fkey
    FOREIGN KEY (id_p) REFERENCES quanly.phong(id_p) ON DELETE CASCADE;

-- phong_trangbi_csvc -> cosovatchat
ALTER TABLE quanly.phong_trangbi_csvc
    ADD CONSTRAINT phong_trangbi_csvc_id_csvc_fkey
    FOREIGN KEY (id_csvc) REFERENCES quanly.cosovatchat(id_csvc) ON DELETE CASCADE;


-- ============================================================
-- SCHEMA: nhansu
-- ============================================================

-- nhanvien -> chinhanh
ALTER TABLE nhansu.nhanvien
    ADD CONSTRAINT nhanvien_id_cn_fkey
    FOREIGN KEY (id_cn) REFERENCES quanly.chinhanh(id_cn) ON DELETE CASCADE;


-- ============================================================
-- SCHEMA: khachhang
-- ============================================================

-- hoivien -> muchoivien
ALTER TABLE khachhang.hoivien
    ADD CONSTRAINT hoivien_id_mhv_fkey
    FOREIGN KEY (id_mhv) REFERENCES khachhang.muchoivien(id_mhv) ON DELETE SET NULL;

-- khachhang -> hoivien
ALTER TABLE khachhang.khachhang
    ADD CONSTRAINT khachhang_id_hv_fkey
    FOREIGN KEY (id_hv) REFERENCES khachhang.hoivien(id_hv) ON DELETE SET NULL;

-- khachhang -> doankhach
ALTER TABLE khachhang.khachhang
    ADD CONSTRAINT khachhang_id_doan_fkey
    FOREIGN KEY (id_doan) REFERENCES khachhang.doankhach(id_doan) ON DELETE SET NULL;

-- doankhach -> khachhang (trưởng đoàn, thêm từ V20)
ALTER TABLE khachhang.doankhach
    ADD CONSTRAINT fk_doankhach_truongdoan
    FOREIGN KEY (id_truong_doan) REFERENCES khachhang.khachhang(id_kh) ON DELETE SET NULL;

-- khachhang_treem -> khachhang
ALTER TABLE khachhang.khachhang_treem
    ADD CONSTRAINT khachhang_treem_id_kh_fkey
    FOREIGN KEY (id_kh) REFERENCES khachhang.khachhang(id_kh) ON DELETE CASCADE;


-- ============================================================
-- SCHEMA: hoadon
-- ============================================================

-- hoadon -> khachhang
ALTER TABLE hoadon.hoadon
    ADD CONSTRAINT hoadon_id_kh_fkey
    FOREIGN KEY (id_kh) REFERENCES khachhang.khachhang(id_kh) ON DELETE SET NULL;

-- hoadon -> nhanvien
ALTER TABLE hoadon.hoadon
    ADD CONSTRAINT hoadon_id_nv_fkey
    FOREIGN KEY (id_nv) REFERENCES nhansu.nhanvien(id_nv) ON DELETE SET NULL;

-- hoadon_thue_phong -> hoadon
ALTER TABLE hoadon.hoadon_thue_phong
    ADD CONSTRAINT hoadon_thue_phong_id_hd_fkey
    FOREIGN KEY (id_hd) REFERENCES hoadon.hoadon(id_hd) ON DELETE CASCADE;

-- hoadon_thue_phong -> phong
ALTER TABLE hoadon.hoadon_thue_phong
    ADD CONSTRAINT hoadon_thue_phong_id_p_fkey
    FOREIGN KEY (id_p) REFERENCES quanly.phong(id_p) ON DELETE CASCADE;

-- hoadon_sudung_dichvu -> hoadon
ALTER TABLE hoadon.hoadon_sudung_dichvu
    ADD CONSTRAINT hoadon_sudung_dichvu_id_hd_fkey
    FOREIGN KEY (id_hd) REFERENCES hoadon.hoadon(id_hd) ON DELETE CASCADE;

-- hoadon_sudung_dichvu -> dichvu
ALTER TABLE hoadon.hoadon_sudung_dichvu
    ADD CONSTRAINT hoadon_sudung_dichvu_id_dv_fkey
    FOREIGN KEY (id_dv) REFERENCES hoadon.dichvu(id_dv) ON DELETE CASCADE;

-- phu_thu_phong -> hoadon_thue_phong (thêm từ V36)
ALTER TABLE hoadon.phu_thu_phong
    ADD CONSTRAINT phu_thu_phong_id_hd_id_p_fkey
    FOREIGN KEY (id_hd, id_p) REFERENCES hoadon.hoadon_thue_phong(id_hd, id_p) ON DELETE CASCADE;
