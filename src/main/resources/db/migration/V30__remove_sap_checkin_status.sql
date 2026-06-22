-- Migration: V30 - Redefine v_phong_status_detail view to remove dynamic "Sắp Check-In" status, returning database status directly
DROP VIEW IF EXISTS quanly.v_phong_status_detail CASCADE;

CREATE VIEW quanly.v_phong_status_detail AS
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
