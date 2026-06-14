-- Query: Danh sách cơ sở vật chất bị hao mòn, hư hỏng hoặc cần thay mới ở các phòng
-- Tham số: Không có

SELECT 
    p.id_p,
    p.dia_chi AS ten_phong,
    cn.ten_cn,
    lp.id_cn AS id_cn,
    csvc.ten_csvc,
    pt.so_luong,
    pt.tinh_trang
FROM phong_trangbi_csvc pt
JOIN phong p ON pt.id_p = p.id_p
JOIN loaiphong lp ON p.id_lp = lp.id_lp
JOIN chinhanh cn ON lp.id_cn = cn.id_cn
JOIN cosovatchat csvc ON pt.id_csvc = csvc.id_csvc
WHERE pt.tinh_trang NOT IN ('Mới', 'Tốt')
ORDER BY cn.ten_cn, p.id_p;
