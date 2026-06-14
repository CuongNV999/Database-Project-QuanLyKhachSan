-- Query: Lấy danh sách các phòng chuẩn bị check-in (nhận phòng) trong một ngày cụ thể
-- Tham số truyền vào:
-- 1. Ngày cần kiểm tra (định dạng DATE, ví dụ: '2026-06-15')

SELECT 
    htp.id_hd,
    p.id_p,
    p.dia_chi AS dia_chi_phong,
    kh.ho_ten,
    kh.id_kh,
    htp.ngaynhan,
    'Sắp Check-In' AS trang_thai,
    lp.id_cn AS id_cn
FROM hoadon_thue_phong htp
JOIN hoadon h ON htp.id_hd = h.id_hd
JOIN khachhang kh ON h.id_kh = kh.id_kh
JOIN phong p ON htp.id_p = p.id_p
JOIN loaiphong lp ON p.id_lp = lp.id_lp
WHERE h.trang_thai = 'Đã đặt'
  AND CAST(htp.ngaynhan AS DATE) = ?
ORDER BY htp.ngaynhan ASC;
