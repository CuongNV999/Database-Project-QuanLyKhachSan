-- ============================================================
-- File: 05_create_views.sql
-- Mục đích: Tạo tất cả views cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- SCHEMA: quanly
-- ============================================================

-- 1. View xem chi tiết phòng đầy đủ (phiên bản V31 - trả về trạng thái trực tiếp từ database)
CREATE OR REPLACE VIEW quanly.v_phong_status_detail AS
SELECT 
    p.id_p,
    cn.ten_cn,
    p.dia_chi,
    lp.chat_luong,
    lp.loai_giuong,
    lp.view,
    lp.dien_tich,
    lp.gia_tien::numeric AS gia_tien,
    p.trang_thai
FROM quanly.phong p
LEFT JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
LEFT JOIN quanly.chinhanh cn ON lp.id_cn = cn.id_cn;

-- 2. View thông tin chủ sở hữu của từng chi nhánh
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


-- ============================================================
-- SCHEMA: hoadon
-- ============================================================

-- 3. View tổng hợp doanh thu theo từng chi nhánh (phiên bản V25 - dùng func_tinh_tien_phong động)
CREATE OR REPLACE VIEW hoadon.v_doanh_thu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    COALESCE(SUM(hoadon.func_tinh_tien_phong(h.id_hd, htp.id_p)), 0::money)::numeric AS tong_doanh_thu_thue_phong,
    COUNT(DISTINCT h.id_hd) AS so_hoa_don
FROM quanly.chinhanh cn
LEFT JOIN quanly.loaiphong lp ON cn.id_cn = lp.id_cn
LEFT JOIN quanly.phong p ON lp.id_lp = p.id_lp
LEFT JOIN hoadon.hoadon_thue_phong htp ON p.id_p = htp.id_p
LEFT JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd AND h.trang_thai = 'Đã thanh toán'
GROUP BY cn.id_cn, cn.ten_cn;

-- 4. View chi tiết hóa đơn thuê phòng (phiên bản V36 - dùng bảng phu_thu_phong normalized)
CREATE OR REPLACE VIEW hoadon.v_chi_tiet_hoa_don_thue_phong AS
SELECT 
    htp.id_hd,
    htp.id_p,
    htp.ngaynhan,
    htp.ngaytra,
    htp.so_ngay_luu_tru,
    COALESCE((SELECT SUM(so_tien) FROM hoadon.phu_thu_phong pt WHERE pt.id_hd = htp.id_hd AND pt.id_p = htp.id_p AND pt.loai_phu_thu = 'Tiêu hao'), 0::money) AS phu_thu_tieu_hao,
    COALESCE((SELECT SUM(so_tien) FROM hoadon.phu_thu_phong pt WHERE pt.id_hd = htp.id_hd AND pt.id_p = htp.id_p AND pt.loai_phu_thu = 'Hỏng hóc'), 0::money) AS phu_thu_hong_hoc,
    hoadon.func_tinh_tien_coc(htp.id_hd) AS tong_tien_coc_hoa_don,
    (htp.so_ngay_luu_tru * lp.gia_tien * 0.5) AS tien_coc_phong,
    hoadon.func_tinh_tien_phong(htp.id_hd, htp.id_p) AS tong_tien_phong
FROM hoadon.hoadon_thue_phong htp
JOIN quanly.phong p ON htp.id_p = p.id_p
JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp;
