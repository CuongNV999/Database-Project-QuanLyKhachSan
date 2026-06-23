-- Migration: V33 - Add existing checkout/payment records to history
INSERT INTO hoadon.lich_su_thao_tac (thao_tac, id_hd, id_kh, ho_ten_kh, id_nv, ten_nv, id_p, thoi_gian)
SELECT 
    'Thanh toán (Check-out)'::varchar,
    h.id_hd,
    h.id_kh,
    kh.ho_ten,
    h.id_nv,
    nv.ten_nv,
    htp.id_p,
    COALESCE(h.ngaythanhtoan::timestamp, h.ngaylap::timestamp + interval '1 day')
FROM hoadon.hoadon h
JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
LEFT JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
LEFT JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv
WHERE h.trang_thai = 'Đã thanh toán';
