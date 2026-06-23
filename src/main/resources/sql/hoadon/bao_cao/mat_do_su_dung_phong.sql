-- Query: Thống kê tổng số ngày được đặt của từng phòng trong một khoảng thời gian
-- Tham số: 
-- 1. Ngày bắt đầu khoảng thời gian (Ví dụ: '2026-06-01')
-- 2. Ngày kết thúc khoảng thời gian (Ví dụ: '2026-06-30')
-- 3. Ngày bắt đầu (trùng tham số 1 dùng cho điều kiện WHERE overlap)
-- 4. Ngày kết thúc (trùng tham số 2 dùng cho điều kiện WHERE overlap)

SELECT 
    p.id_p,
    p.dia_chi AS ten_phong,
    lp.chat_luong,
    cn.ten_cn,
    COALESCE(SUM(
        EXTRACT(DAY FROM (LEAST(htp.ngaytra, ?::timestamp) - GREATEST(htp.ngaynhan, ?::timestamp)))
    ), 0) AS tong_so_ngay_thue
FROM phong p
JOIN loaiphong lp ON p.id_lp = lp.id_lp
JOIN chinhanh cn ON lp.id_cn = cn.id_cn
LEFT JOIN hoadon_thue_phong htp ON p.id_p = htp.id_p
LEFT JOIN hoadon h ON htp.id_hd = h.id_hd AND h.trang_thai != 'Đã hủy'
  AND htp.ngaynhan < ?::timestamp AND htp.ngaytra > ?::timestamp
GROUP BY p.id_p, p.dia_chi, lp.chat_luong, cn.ten_cn
ORDER BY tong_so_ngay_thue DESC, p.id_p;
