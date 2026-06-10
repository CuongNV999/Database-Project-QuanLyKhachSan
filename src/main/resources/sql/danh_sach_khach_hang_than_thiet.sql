-- Query: Lấy danh sách Top khách hàng thân thiết chi tiêu nhiều nhất cho thuê phòng
-- Tham số truyền vào:
-- 1. Số lượng khách hàng muốn lấy (LIMIT) (Ví dụ: 10)

SELECT 
    kh.id_kh,
    kh.ho_ten,
    kh.sdt,
    kh.quoc_tich,
    hv.hang AS hang_hoi_vien,
    hv.diem_tich_luy,
    COUNT(DISTINCT h.id_hd) AS so_lan_dat,
    SUM(htp.tong_tien) AS tong_chi_tieu
FROM public.khachhang kh
LEFT JOIN public.hoivien hv ON kh.id_hv = hv.id_hv
JOIN public.hoadon h ON kh.id_kh = h.id_kh
JOIN public.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
WHERE h.trang_thai = 'Đã thanh toán'
GROUP BY kh.id_kh, kh.ho_ten, kh.sdt, kh.quoc_tich, hv.hang, hv.diem_tich_luy
ORDER BY tong_chi_tieu DESC
LIMIT ?;
