-- Query: Lịch sử đặt phòng chi tiết của một khách hàng
-- Tham số: 
-- 1. id_kh (Mã khách hàng, Ví dụ: 101)

SELECT 
    h.id_hd,
    h.ngaylap,
    h.trang_thai AS trang_thai_hoa_don,
    p.dia_chi AS ten_phong,
    cn.ten_cn AS ten_chi_nhanh,
    htp.ngaynhan,
    htp.ngaytra,
    hoadon.func_tinh_tien_phong(h.id_hd, htp.id_p)::numeric AS tien_phong
FROM hoadon h
JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
JOIN phong p ON htp.id_p = p.id_p
JOIN loaiphong lp ON p.id_lp = lp.id_lp
JOIN chinhanh cn ON lp.id_cn = cn.id_cn
WHERE h.id_kh = ?
ORDER BY htp.ngaynhan DESC;
