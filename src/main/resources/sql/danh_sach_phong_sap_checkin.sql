-- Query: Lấy danh sách các phòng chuẩn bị check-in (nhận phòng) trong một ngày cụ thể
-- Tham số truyền vào:
-- 1. Ngày cần kiểm tra (định dạng DATE, ví dụ: '2026-06-15')

SELECT 
    htp.id_hd,
    kh.ho_ten AS ten_khach_hang,
    kh.sdt AS sdt_khach,
    p.dia_chi AS ten_phong,
    htp.ngaynhan AS thoi_gian_nhan_phong,
    htp.ngaytra AS thoi_gian_tra_phong,
    htp.tien_coc
FROM public.hoadon_thue_phong htp
JOIN public.hoadon h ON htp.id_hd = h.id_hd
JOIN public.khachhang kh ON h.id_kh = kh.id_kh
JOIN public.phong p ON htp.id_p = p.id_p
WHERE h.trang_thai = 'Đã đặt'
  AND CAST(htp.ngaynhan AS DATE) = ?
ORDER BY htp.ngaynhan ASC;
