-- Trigger Function: Tự động cộng số đêm lưu trú thực tế vào tài khoản hội viên của khách hàng lẻ sau khi thanh toán hóa đơn thành công
-- Giải thích:
-- Lấy khoảng thời gian của từng phòng trong hóa đơn (ngaytra - ngaynhan) để cộng dồn số đêm lưu trú.

CREATE OR REPLACE FUNCTION hoadon.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_tong_so_dem INT := 0;
BEGIN
    -- Chỉ kích hoạt khi hóa đơn chuyển trạng thái sang "Đã thanh toán"
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        -- Tìm kiếm thông tin hội viên của khách hàng
        SELECT id_hv INTO v_id_hv
        FROM khachhang.khachhang
        WHERE id_kh = NEW.id_kh;

        IF v_id_hv IS NOT NULL THEN
            -- Tính toán tổng số đêm lưu trú thực tế từ tất cả các phòng trong hóa đơn này
            SELECT COALESCE(SUM(EXTRACT(DAY FROM (ngaytra - ngaynhan))::INT), 0)
            INTO v_tong_so_dem
            FROM hoadon.hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;

            -- Đảm bảo mỗi lượt đặt tính tối thiểu 1 đêm
            IF v_tong_so_dem <= 0 THEN
                v_tong_so_dem := 1;
            END IF;

            -- Cộng dồn số đêm lưu trú thực tế vào điểm tích lũy của hội viên
            UPDATE khachhang.hoivien
            SET tong_luu_tru = tong_luu_tru + v_tong_so_dem
            WHERE id_hv = v_id_hv;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
