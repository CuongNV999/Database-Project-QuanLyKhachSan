-- ============================================================
-- File: 03_create_indexes.sql
-- Mục đích: Tạo tất cả indexes cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- SCHEMA: quanly
-- ============================================================

-- chinhanh_chusohuu
CREATE INDEX idx_cn_csh_id_csh ON quanly.chinhanh_chusohuu USING btree (id_csh);

-- phong
CREATE INDEX idx_phong_id_lp ON quanly.phong USING btree (id_lp);
CREATE INDEX idx_phong_trang_thai ON quanly.phong USING btree (trang_thai);
CREATE INDEX IF NOT EXISTS idx_phong_id_cn ON quanly.phong (id_cn);

-- phong_trangbi_csvc
CREATE INDEX idx_phong_csvc_id_csvc ON quanly.phong_trangbi_csvc USING btree (id_csvc);


-- ============================================================
-- SCHEMA: nhansu
-- ============================================================

-- nhanvien
CREATE INDEX idx_nhanvien_chuc_vu ON nhansu.nhanvien USING btree (chuc_vu);
CREATE INDEX idx_nhanvien_id_cn ON nhansu.nhanvien USING btree (id_cn);


-- ============================================================
-- SCHEMA: khachhang
-- ============================================================

-- hoivien
CREATE INDEX idx_hoivien_id_mhv ON khachhang.hoivien USING btree (id_mhv);

-- khachhang
CREATE INDEX idx_khachhang_hoten ON khachhang.khachhang USING btree (ho_ten);
CREATE INDEX idx_khachhang_id_doan ON khachhang.khachhang USING btree (id_doan);
CREATE INDEX idx_khachhang_id_hv ON khachhang.khachhang USING btree (id_hv);
CREATE INDEX idx_khachhang_sdt ON khachhang.khachhang USING btree (sdt);


-- ============================================================
-- SCHEMA: hoadon
-- ============================================================

-- hoadon
CREATE INDEX idx_hoadon_id_kh ON hoadon.hoadon USING btree (id_kh);
CREATE INDEX idx_hoadon_id_nv ON hoadon.hoadon USING btree (id_nv);
CREATE INDEX idx_hoadon_ngay_lap ON hoadon.hoadon USING btree (ngaylap);

-- hoadon_thue_phong
CREATE INDEX idx_hd_thue_phong_id_p ON hoadon.hoadon_thue_phong USING btree (id_p);

-- hoadon_sudung_dichvu
CREATE INDEX idx_hd_sd_dv_id_dv ON hoadon.hoadon_sudung_dichvu USING btree (id_dv);
