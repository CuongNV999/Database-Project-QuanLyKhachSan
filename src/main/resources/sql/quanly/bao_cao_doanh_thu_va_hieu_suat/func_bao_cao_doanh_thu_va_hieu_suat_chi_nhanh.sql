-- Function: Báo cáo doanh thu và hiệu suất sử dụng phòng của chi nhánh theo tháng/năm
-- Đầu vào:
--   p_id_cn: Mã chi nhánh
--   p_thang: Tháng
--   p_nam: Năm
-- Trả về: Bảng kết quả gồm 4 cột báo cáo tổng hợp

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

    -- 2. Tính số ngày trong tháng đó bằng helper function
    v_ngay_trong_thang := quanly.func_lay_so_ngay_trong_thang(p_thang, p_nam);

    -- 3. Tính doanh thu phòng cho chi nhánh trong tháng/năm đó từ các hóa đơn đã thanh toán
    SELECT COALESCE(SUM(hoadon.func_tinh_tien_phong(h.id_hd, htp.id_p)), 0::money), COUNT(DISTINCT h.id_hd)
    INTO v_tong_doanh_thu, v_so_hd
    FROM hoadon h
    JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN phong p ON htp.id_p = p.id_p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai = 'Đã thanh toán'
      AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
      AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    -- Cộng thêm doanh thu dịch vụ cho các hóa đơn thuộc chi nhánh trong tháng/năm đó bằng helper function
    v_tong_doanh_thu := v_tong_doanh_thu + quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(p_id_cn, p_thang, p_nam);

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

    -- 5. Tính hiệu suất phòng (%) bằng helper function
    v_hieu_suat := quanly.func_tinh_hieu_suat_phong(p_id_cn, p_thang, p_nam, v_ngay_trong_thang, v_tong_so_phong);

    RETURN QUERY SELECT v_tong_doanh_thu, v_so_hd, v_so_phong_thue, v_hieu_suat;
END;
$$ LANGUAGE plpgsql;
