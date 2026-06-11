-- Query: Tổng hợp hóa đơn, dịch vụ và tổng tiền chi tiêu của một đoàn khách
-- Tham số: 
-- 1. id_doan (Mã đoàn khách, Ví dụ: 1)

SELECT 
    dk.id_doan,
    dk.so_thanh_vien,
    kh_truong.ho_ten AS ten_truong_doan,
    COUNT(DISTINCT h.id_hd) AS tong_so_hoa_don,
    COALESCE(SUM(htp.tong_tien), 0::money)::numeric AS tong_tien_phong,
    COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)::numeric AS tong_tien_dich_vu,
    (COALESCE(SUM(htp.tong_tien), 0::money) + COALESCE(SUM(hsd.so_luong * dv.gia), 0::money))::numeric AS tong_chi_tieu_doan
FROM doankhach dk
LEFT JOIN truongdoan td ON dk.id_doan = td.id_doan
LEFT JOIN khachhang kh_truong ON td.id_kh = kh_truong.id_kh
LEFT JOIN khachhang kh_mem ON dk.id_doan = kh_mem.id_doan
LEFT JOIN hoadon h ON kh_mem.id_kh = h.id_kh AND h.trang_thai = 'Đã thanh toán'
LEFT JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
LEFT JOIN hoadon_sudung_dichvu hsd ON h.id_hd = hsd.id_hd
LEFT JOIN dichvu dv ON hsd.id_dv = dv.id_dv
WHERE dk.id_doan = ?
GROUP BY dk.id_doan, dk.so_thanh_vien, kh_truong.ho_ten;
