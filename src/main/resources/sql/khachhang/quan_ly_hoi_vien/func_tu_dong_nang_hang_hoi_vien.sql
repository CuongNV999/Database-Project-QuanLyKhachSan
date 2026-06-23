-- Trigger Function: Tự động nâng hạng hội viên dựa trên số đêm lưu trú tích lũy (tong_luu_tru)
-- Áp dụng cho: Khách hàng lẻ
-- Quy định thăng hạng:
-- Mức 0 (Basic): < 20 đêm
-- Mức 1 (Bronze): >= 20 đêm
-- Mức 2 (Silver): >= 40 đêm
-- Mức 3 (Gold): >= 80 đêm

CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
DECLARE
    v_id_mhv INT;
BEGIN
    -- Kiểm tra số đêm tích lũy (tong_luu_tru) để quyết định thăng hạng
    IF NEW.tong_luu_tru >= 80 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Gold';
    ELSIF NEW.tong_luu_tru >= 40 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Silver';
    ELSIF NEW.tong_luu_tru >= 20 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Bronze';
    ELSE
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Basic';
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
