-- Helper Function: Tính hiệu suất phòng (%) của chi nhánh trong tháng
-- Đầu vào:
--   p_id_cn: Mã chi nhánh
--   p_thang: Tháng
--   p_nam: Năm
--   p_ngay_trong_thang: Số ngày trong tháng
--   p_tong_so_phong: Tổng số phòng của chi nhánh
-- Trả về: NUMERIC(5,2) (Tỷ lệ phần trăm hiệu suất sử dụng phòng)

CREATE OR REPLACE FUNCTION quanly.func_tinh_hieu_suat_phong(
    p_id_cn INT,
    p_thang INT,
    p_nam INT,
    p_ngay_trong_thang INT,
    p_tong_so_phong INT
)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    v_tong_so_ngay_thue INT := 0;
    v_hieu_suat NUMERIC(5,2) := 0.00;
BEGIN
    SELECT COALESCE(SUM(
        EXTRACT(DAY FROM (
            LEAST(htp.ngaytra, MAKE_DATE(p_nam, p_thang, p_ngay_trong_thang) + TIME '23:59:59') - 
            GREATEST(htp.ngaynhan, MAKE_DATE(p_nam, p_thang, 1))
        ))::INT
    ), 0) INTO v_tong_so_ngay_thue
    FROM hoadon_thue_phong htp
    JOIN phong p ON htp.id_p = p.id_p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND htp.ngaynhan <= (MAKE_DATE(p_nam, p_thang, p_ngay_trong_thang) + TIME '23:59:59')
      AND htp.ngaytra >= MAKE_DATE(p_nam, p_thang, 1);

    IF v_tong_so_ngay_thue < 0 THEN
        v_tong_so_ngay_thue := 0;
    END IF;

    IF p_tong_so_phong > 0 AND p_ngay_trong_thang > 0 THEN
        v_hieu_suat := (v_tong_so_ngay_thue::numeric / (p_tong_so_phong * p_ngay_trong_thang)) * 100;
        IF v_hieu_suat > 100.00 THEN
            v_hieu_suat := 100.00;
        END IF;
    ELSE
        v_hieu_suat := 0.00;
    END IF;

    RETURN v_hieu_suat;
END;
$$ LANGUAGE plpgsql;
