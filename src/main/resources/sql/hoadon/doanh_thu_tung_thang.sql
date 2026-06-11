-- Query: Thống kê doanh thu tiền phòng theo từng tháng trong một năm cụ thể
-- Tham số truyền vào: 
-- 1. Năm cần thống kê (ví dụ: 2026)

SELECT 
    EXTRACT(MONTH FROM h.ngaythanhtoan) AS thang,
    COUNT(DISTINCT h.id_hd) AS so_luot_thue,
    SUM(htp.tong_tien)::numeric AS doanh_thu_phong
FROM hoadon h
JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
WHERE h.trang_thai = 'Đã thanh toán'
  AND EXTRACT(YEAR FROM h.ngaythanhtoan) = ?
GROUP BY thang
ORDER BY thang ASC;
