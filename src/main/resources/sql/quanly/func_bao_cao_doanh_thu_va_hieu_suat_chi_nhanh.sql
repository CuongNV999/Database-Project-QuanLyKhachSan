-- Function: Báo cáo doanh thu và hiệu suất sử dụng phòng của chi nhánh theo tháng/năm
CREATE OR REPLACE FUNCTION quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh(
    p_id_cn INT,
    p_thang INT,
    p_nam INT
)
RETURNS TABLE (
    tong_doanh_thu MONEY,
    so_hoa_don_thanh_toan INT,
    so_luot_phong_thue INT,
    hieu_suat_phong_percent NUMERIC(5,2)
) AS $$
DECLARE
    v_tong_doanh_thu MONEY := 0::money;
    v_so_hd INT := 0;
    v_so_phong_thue INT := 0;
    v_tong_so_phong INT := 0;
    v_ngay_trong_thang INT;
    v_hieu_suat NUMERIC(5,2) := 0.00;
BEGIN
    -- 1. Đếm tổng số phòng của chi nhánh này
    SELECT COUNT(*) INTO v_tong_so_phong
    FROM phong p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn;

    -- 2. Tính số ngày trong tháng đó
    v_ngay_trong_thang := EXTRACT(DAY FROM (DATE_TRUNC('month', MAKE_DATE(p_nam, p_thang, 1)) + INTERVAL '1 month' - INTERVAL '1 day'))::INT;

    -- 3. Tính doanh thu phòng và dịch vụ cho chi nhánh trong tháng/năm đó từ các hóa đơn đã thanh toán
    SELECT COALESCE(SUM(htp.tong_tien), 0::money), COUNT(DISTINCT h.id_hd)
    INTO v_tong_doanh_thu, v_so_hd
    FROM hoadon h
    JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN phong p ON htp.id_p = p.id_p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai = 'Đã thanh toán'
      AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
      AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    -- Tính thêm doanh thu dịch vụ cho các hóa đơn thuộc chi nhánh trong tháng/năm đó
    DECLARE
        v_tien_dv MONEY := 0::money;
    BEGIN
        SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
        INTO v_tien_dv
        FROM hoadon h
        JOIN hoadon_sudung_dichvu hsd ON h.id_hd = hsd.id_hd
        JOIN dichvu dv ON hsd.id_dv = dv.id_dv
        WHERE EXISTS (
            SELECT 1 FROM hoadon_thue_phong htp
            JOIN phong p ON htp.id_p = p.id_p
            JOIN loaiphong lp ON p.id_lp = lp.id_lp
            WHERE htp.id_hd = h.id_hd AND lp.id_cn = p_id_cn
        )
        AND h.trang_thai = 'Đã thanh toán'
        AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
        AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

        v_tong_doanh_thu := v_tong_doanh_thu + v_tien_dv;
    END;

    -- 4. Tính số lượt phòng đã được thuê trong tháng
    SELECT COUNT(*) INTO v_so_phong_thue
    FROM hoadon_thue_phong htp
    JOIN phong p ON htp.id_p = p.id_p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND (
          (EXTRACT(MONTH FROM htp.ngaynhan) = p_thang AND EXTRACT(YEAR FROM htp.ngaynhan) = p_nam)
          OR
          (EXTRACT(MONTH FROM htp.ngaytra) = p_thang AND EXTRACT(YEAR FROM htp.ngaytra) = p_nam)
      );

    -- 5. Tính hiệu suất phòng (%)
    DECLARE
        v_tong_so_ngay_thue INT := 0;
    BEGIN
        SELECT COALESCE(SUM(
            EXTRACT(DAY FROM (
                LEAST(htp.ngaytra, MAKE_DATE(p_nam, p_thang, v_ngay_trong_thang) + TIME '23:59:59') - 
                GREATEST(htp.ngaynhan, MAKE_DATE(p_nam, p_thang, 1))
            ))::INT
        ), 0) INTO v_tong_so_ngay_thue
        FROM hoadon_thue_phong htp
        JOIN phong p ON htp.id_p = p.id_p
        JOIN loaiphong lp ON p.id_lp = lp.id_lp
        JOIN hoadon h ON htp.id_hd = h.id_hd
        WHERE lp.id_cn = p_id_cn
          AND h.trang_thai != 'Đã hủy'
          AND htp.ngaynhan <= (MAKE_DATE(p_nam, p_thang, v_ngay_trong_thang) + TIME '23:59:59')
          AND htp.ngaytra >= MAKE_DATE(p_nam, p_thang, 1);

        IF v_tong_so_ngay_thue < 0 THEN
            v_tong_so_ngay_thue := 0;
        END IF;

        IF v_tong_so_phong > 0 AND v_ngay_trong_thang > 0 THEN
            v_hieu_suat := (v_tong_so_ngay_thue::numeric / (v_tong_so_phong * v_ngay_trong_thang)) * 100;
            IF v_hieu_suat > 100.00 THEN
                v_hieu_suat := 100.00;
            END IF;
        ELSE
            v_hieu_suat := 0.00;
        END IF;
    END;

    RETURN QUERY SELECT v_tong_doanh_thu, v_so_hd, v_so_phong_thue, v_hieu_suat;
END;
$$ LANGUAGE plpgsql;
