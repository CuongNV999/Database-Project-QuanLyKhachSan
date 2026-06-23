-- Helper Function: Tính số ngày của tháng/năm bất kỳ
-- Đầu vào: p_thang (Tháng), p_nam (Năm)
-- Trả về: INT (Số ngày trong tháng)

CREATE OR REPLACE FUNCTION quanly.func_lay_so_ngay_trong_thang(p_thang INT, p_nam INT)
RETURNS INT AS $$
BEGIN
    RETURN EXTRACT(DAY FROM (DATE_TRUNC('month', MAKE_DATE(p_nam, p_thang, 1)) + INTERVAL '1 month' - INTERVAL '1 day'))::INT;
END;
$$ LANGUAGE plpgsql;
