-- Query: Tìm kiếm các phòng còn trống tại một chi nhánh trong khoảng thời gian nhất định
-- Tham số truyền vào:
-- 1. id_cn (Mã chi nhánh)
-- 2. Ngày trả mong muốn (ngaytra) để so sánh overlap
-- 3. Ngày nhận mong muốn (ngaynhan) để so sánh overlap

SELECT 
    p.id_p,
    p.dia_chi AS ten_phong,
    lp.chat_luong,
    lp.loai_giuong,
    lp.view,
    lp.gia_tien
FROM public.phong p
JOIN public.loaiphong lp ON p.id_lp = lp.id_lp
WHERE lp.id_cn = ?
  AND p.id_p NOT IN (
      SELECT htp.id_p 
      FROM public.hoadon_thue_phong htp
      JOIN public.hoadon h ON htp.id_hd = h.id_hd
      WHERE h.trang_thai != 'Đã hủy' -- Bỏ qua các phòng đã hủy đặt phòng
        AND htp.ngaynhan < ?         -- ngaynhan_booked < ngaytra_wanted
        AND htp.ngaytra > ?          -- ngaytra_booked > ngaynhan_wanted
  )
ORDER BY lp.gia_tien ASC;
