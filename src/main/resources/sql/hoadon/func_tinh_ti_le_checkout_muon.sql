-- Function: Tính toán tỷ lệ phụ thu check-out muộn theo hạng hội viên của khách hàng
-- Đầu vào: 
-- 1. p_hang_hv (Hạng hội viên: Basic, Bronze, Silver, Gold hoặc NULL)
-- 2. p_ngaynhan (Ngày/giờ nhận phòng thực tế)
-- 3. p_so_ngay_luu_tru (Số ngày đăng ký lưu trú)
-- 4. p_ngaytra_thucte (Ngày/giờ checkout thực tế)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_ti_le_checkout_muon(
    p_hang_hv VARCHAR,
    p_ngaynhan TIMESTAMP,
    p_so_ngay_luu_tru INT,
    p_ngaytra_thucte TIMESTAMP
)
RETURNS NUMERIC AS $$
DECLARE
    v_ngaytra_dukien TIMESTAMP;
    v_expected_date DATE;
    v_checkout_time TIME;
    v_ti_le NUMERIC := 0.00;
BEGIN
    -- Tính ngày trả dự kiến từ ngày nhận + số ngày lưu trú
    v_ngaytra_dukien := p_ngaynhan + COALESCE(p_so_ngay_luu_tru, 1) * INTERVAL '1 day';

    -- Nếu chưa check-out hoặc check-out trước/đúng giờ hẹn dự kiến, không tính phí check-out muộn
    IF p_ngaytra_thucte IS NULL OR p_ngaytra_thucte <= v_ngaytra_dukien THEN
        RETURN 0.00;
    END IF;

    v_expected_date := v_ngaytra_dukien::date;
    v_checkout_time := p_ngaytra_thucte::time;

    -- Nếu check-out sau ngày dự kiến, tự động tính vượt mức 18:00 (phụ thu 100% giá phòng)
    IF p_ngaytra_thucte::date > v_expected_date THEN
        RETURN 1.00;
    END IF;

    -- Kiểm tra điều kiện phụ thu theo từng hạng hội viên
    IF p_hang_hv IS NULL OR p_hang_hv = '' OR p_hang_hv = 'Basic' OR p_hang_hv = 'Bronze' THEN
        -- Khách lẻ vãng lai hoặc hạng Basic / Bronze:
        -- Trả phòng trước 14:00: Miễn phí
        -- Từ 14:00 đến 16:00: Phụ thu 30% giá phòng
        -- Từ 16:00 đến 18:00: Phụ thu 50% giá phòng
        -- Sau 18:00: Phụ thu 100% giá phòng
        IF v_checkout_time <= TIME '14:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.30;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.50;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Silver' THEN
        -- Hội viên hạng Silver:
        -- Trả phòng trước 16:00: Miễn phí
        -- Từ 16:00 đến 18:00: Phụ thu 20% giá phòng
        -- Sau 18:00: Phụ thu 100% giá phòng
        IF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.20;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Gold' THEN
        -- Hội viên hạng Gold:
        -- Trả phòng trước 18:00: Miễn phí
        -- Sau 18:00: Phụ thu 100% giá phòng
        IF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.00;
        ELSE
            v_ti_le := 1.00;
        END IF;
    END IF;

    RETURN v_ti_le;
END;
$$ LANGUAGE plpgsql;
