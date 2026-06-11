-- Query: Danh sách nhân viên và mức lương của họ tại một chi nhánh cụ thể
-- Tham số: 
-- 1. id_cn (Mã chi nhánh, Ví dụ: 1)

SELECT 
    nv.id_nv,
    nv.ten_nv,
    nv.chuc_vu,
    cv.luong::numeric AS luong_nhan_vien
FROM nhanvien nv
LEFT JOIN chucvu cv ON nv.chuc_vu = cv.chuc_vu
WHERE nv.id_cn = ?
ORDER BY cv.luong DESC, nv.id_nv ASC;
