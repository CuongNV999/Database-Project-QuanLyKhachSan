-- Query: Thống kê doanh thu phòng của từng chi nhánh theo từng tháng trong năm
-- Tham số: 
-- 1. Năm cần thống kê (Ví dụ: 2026)

SELECT 
    cn.id_cn,
    cn.ten_cn,
    EXTRACT(MONTH FROM h.ngaythanhtoan) AS thang,
    COALESCE(SUM(htp.tong_tien), 0::money)::numeric AS doanh_thu_thang,
    COUNT(DISTINCT h.id_hd) AS so_luot_thanh_toan
FROM chinhanh cn
JOIN loaiphong lp ON cn.id_cn = lp.id_cn
JOIN phong p ON lp.id_lp = p.id_lp
JOIN hoadon_thue_phong htp ON p.id_p = htp.id_p
JOIN hoadon h ON htp.id_hd = h.id_hd
WHERE h.trang_thai = 'Đã thanh toán'
  AND EXTRACT(YEAR FROM h.ngaythanhtoan) = ?
GROUP BY cn.id_cn, cn.ten_cn, thang
ORDER BY cn.id_cn ASC, thang ASC;
