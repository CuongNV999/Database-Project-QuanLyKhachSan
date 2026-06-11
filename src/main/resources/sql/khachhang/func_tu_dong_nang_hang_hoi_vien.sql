-- Trigger Function: Tự động nâng hạng hội viên dựa trên điểm tích lũy
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
BEGIN
    -- Xác định hạng hội viên dựa trên điểm tích lũy:
    -- < 100 điểm: Hạng NULL (hoặc không đổi / hạ về Bronze nếu cần)
    -- Từ 100 đến 299 điểm: Bronze
    -- Từ 300 đến 799 điểm: Silver
    -- Từ 800 điểm trở lên: Gold
    IF NEW.diem_tich_luy >= 800 THEN
        NEW.hang := 'Gold';
    ELSIF NEW.diem_tich_luy >= 300 THEN
        NEW.hang := 'Silver';
    ELSIF NEW.diem_tich_luy >= 100 THEN
        NEW.hang := 'Bronze';
    ELSE
        NEW.hang := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
