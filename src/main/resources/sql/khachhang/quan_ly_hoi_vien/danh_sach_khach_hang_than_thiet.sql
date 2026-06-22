-- Query: Lấy danh sách Top khách hàng thân thiết chi tiêu nhiều nhất cho thuê phòng
-- Tham số truyền vào:
-- 1. Số lượng khách hàng muốn lấy (LIMIT) (Ví dụ: 10)

SELECT 
    kh.id_kh,
    kh.ho_ten,
    kh.sdt,
    kh.quoc_tich,
    mhv.hang AS hang_hoi_vien,
    hv.tong_luu_tru,
    COUNT(DISTINCT h.id_hd) AS so_lan_dat,
    SUM(hoadon.func_tinh_tien_phong(h.id_hd, htp.id_p))::numeric AS tong_chi_tieu
FROM khachhang kh
LEFT JOIN hoivien hv ON kh.id_hv = hv.id_hv
LEFT JOIN muchoivien mhv ON hv.id_mhv = mhv.id_mhv
JOIN hoadon h ON kh.id_kh = h.id_kh
JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
WHERE h.trang_thai = 'Đã thanh toán'
GROUP BY kh.id_kh, kh.ho_ten, kh.sdt, kh.quoc_tich, mhv.hang, hv.tong_luu_tru
ORDER BY tong_chi_tieu DESC
LIMIT ?;
