-- Query: Danh sách phòng đã quá hạn ngày trả phòng dự kiến nhưng chưa được checkout
-- Tham số: Không có (Sử dụng thời gian hiện tại của hệ thống)

SELECT 
    htp.id_hd,
    kh.ho_ten,
    kh.ho_ten AS ten_khach_hang,
    kh.sdt AS sdt_khach,
    p.id_p,
    p.dia_chi AS dia_chi_phong,
    p.dia_chi AS ten_phong,
    cn.ten_cn,
    lp.id_cn AS id_cn,
    htp.ngaynhan AS thoi_gian_nhan,
    htp.ngaytra AS thoi_gian_tra_du_kien,
    htp.ngaytra AS ngaytra_du_kien,
    ROUND(EXTRACT(EPOCH FROM (NOW() - htp.ngaytra))/3600) AS so_gio_tre_han
FROM hoadon_thue_phong htp
JOIN hoadon h ON htp.id_hd = h.id_hd
JOIN khachhang kh ON h.id_kh = kh.id_kh
JOIN phong p ON htp.id_p = p.id_p
JOIN loaiphong lp ON p.id_lp = lp.id_lp
JOIN chinhanh cn ON lp.id_cn = cn.id_cn
WHERE h.trang_thai = 'Đã đặt'
  AND htp.ngaytra < NOW()
ORDER BY htp.ngaytra ASC;
