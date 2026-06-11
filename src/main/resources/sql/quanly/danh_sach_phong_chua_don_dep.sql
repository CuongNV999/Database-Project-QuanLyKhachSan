-- Query: Danh sách phòng chưa dọn dẹp xong (Trạng thái: Đang dọn dẹp) tại một chi nhánh
-- Tham số: 
-- 1. id_cn (Mã chi nhánh, Ví dụ: 1)

SELECT 
    p.id_p,
    p.dia_chi AS ten_phong,
    lp.chat_luong,
    lp.loai_giuong,
    p.trang_thai
FROM phong p
JOIN loaiphong lp ON p.id_lp = lp.id_lp
WHERE lp.id_cn = ?
  AND p.trang_thai = 'Đang dọn dẹp'
ORDER BY p.id_p;
