-- Query: Top dịch vụ được sử dụng nhiều nhất và tổng doanh thu mang lại
-- Tham số: 
-- 1. Số lượng dịch vụ muốn lấy (LIMIT) (Ví dụ: 5)

SELECT 
    dv.id_dv,
    dv.ten_dv,
    dv.loai_dv,
    dv.gia::numeric AS gia_don_vi,
    SUM(hsd.so_luong) AS tong_so_luot_su_dung,
    SUM(hsd.so_luong * dv.gia)::numeric AS tong_doanh_thu_dich_vu
FROM dichvu dv
JOIN hoadon_sudung_dichvu hsd ON dv.id_dv = hsd.id_dv
JOIN hoadon h ON hsd.id_hd = h.id_hd
WHERE h.trang_thai = 'Đã thanh toán'
GROUP BY dv.id_dv, dv.ten_dv, dv.loai_dv, dv.gia
ORDER BY tong_so_luot_su_dung DESC, tong_doanh_thu_dich_vu DESC
LIMIT ?;
