-- Migration: V12 - Redefine v_phong_status_detail view to compute dynamic "Sắp Check-In" status for today's check-ins

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
    CASE 
        WHEN p.trang_thai = 'Đã đặt' AND EXISTS (
            SELECT 1 
            FROM hoadon.hoadon_thue_phong htp
            JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
            WHERE htp.id_p = p.id_p
              AND h.trang_thai = 'Đã đặt'
              AND CAST(htp.ngaynhan AS DATE) = CURRENT_DATE
        ) THEN 'Sắp Check-In'
        ELSE p.trang_thai
    END AS trang_thai
FROM quanly.phong p
LEFT JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
LEFT JOIN quanly.chinhanh cn ON lp.id_cn = cn.id_cn;
