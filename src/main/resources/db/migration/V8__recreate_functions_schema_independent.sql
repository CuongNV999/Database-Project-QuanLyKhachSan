-- 1. Redefine trigger and helper functions without hardcoded public schema prefixes

-- hoadon.func_cap_nhat_diem_tich_luy
CREATE OR REPLACE FUNCTION hoadon.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_diem_tich_luy_cong INT;
    v_tong_tien_phong MONEY;
BEGIN
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        -- Tìm xem khách hàng này có phải hội viên không
        SELECT id_hv INTO v_id_hv
        FROM khachhang
        WHERE id_kh = NEW.id_kh;

        IF v_id_hv IS NOT NULL THEN
            -- Tính tổng tiền của hóa đơn
            SELECT COALESCE(SUM(tong_tien), 0::money)
            INTO v_tong_tien_phong
            FROM hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;

            -- Mỗi 100,000 VND tiền phòng = 1 điểm tích lũy
            v_diem_tich_luy_cong := (v_tong_tien_phong::numeric / 100000)::INT;

            IF v_diem_tich_luy_cong > 0 THEN
                UPDATE hoivien
                SET diem_tich_luy = diem_tich_luy + v_diem_tich_luy_cong
                WHERE id_hv = v_id_hv;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- hoadon.func_tinh_tien_phong
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_gia_tien MONEY;
    v_tien_coc MONEY;
    v_phu_thu MONEY;
    v_so_ngay INT;
    v_tong_tien MONEY;
BEGIN
    -- Lấy thông tin ngày nhận, ngày trả, tiền cọc, phụ thu
    SELECT ngaynhan, ngaytra, tien_coc, phu_thu
    INTO v_ngaynhan, v_ngaytra, v_tien_coc, v_phu_thu
    FROM hoadon_thue_phong
    WHERE id_hd = id_hd_input AND id_p = id_p_input;

    -- Lấy giá tiền phòng
    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM phong p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    -- Tính số ngày thuê (tối thiểu 1 ngày)
    v_so_ngay := EXTRACT(DAY FROM (v_ngaytra - v_ngaynhan))::INT;
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    -- Tính tổng tiền = (số ngày * giá phòng) + phụ thu - tiền cọc
    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0::money)) + COALESCE(v_phu_thu, 0::money) - COALESCE(v_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- hoadon.func_dat_phong_auto_update_status
CREATE OR REPLACE FUNCTION hoadon.func_dat_phong_auto_update_status()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE phong
        SET trang_thai = 'Đã đặt'
        WHERE id_p = NEW.id_p;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = OLD.id_p;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- hoadon.func_check_booking_overlap
CREATE OR REPLACE FUNCTION hoadon.func_check_booking_overlap()
RETURNS TRIGGER AS $$
DECLARE
    v_overlap_count INT;
BEGIN
    -- A. Đảm bảo ngày nhận phải trước ngày trả
    IF NEW.ngaynhan >= NEW.ngaytra THEN
        RAISE EXCEPTION 'Ngày nhận phòng (%) phải đứng trước ngày trả phòng (%)!', NEW.ngaynhan, NEW.ngaytra;
    END IF;

    -- B. Đảm bảo phòng không bị trùng lịch thuê với giao dịch khác chưa bị hủy
    SELECT COUNT(*) INTO v_overlap_count
    FROM hoadon_thue_phong htp
    JOIN hoadon h ON htp.id_hd = h.id_hd
    WHERE htp.id_p = NEW.id_p
      AND h.trang_thai != 'Đã hủy'
      -- Nếu là cập nhật, bỏ qua kiểm tra chính dòng đang sửa
      AND (TG_OP = 'INSERT' OR (htp.id_hd != NEW.id_hd OR htp.id_p != NEW.id_p))
      -- Điều kiện giao thoa ngày nhận/trả
      AND htp.ngaynhan < NEW.ngaytra
      AND htp.ngaytra > NEW.ngaynhan;

    IF v_overlap_count > 0 THEN
        RAISE EXCEPTION 'LỖI ĐẶT PHÒNG: Phòng (ID: %) đã được thuê/đặt bởi hóa đơn khác trong khoảng thời gian từ % đến %!', 
            NEW.id_p, NEW.ngaynhan, NEW.ngaytra;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- hoadon.func_prevent_paid_invoice_edit
CREATE OR REPLACE FUNCTION hoadon.func_prevent_paid_invoice_edit()
RETURNS TRIGGER AS $$
DECLARE
    v_trang_thai VARCHAR(100);
BEGIN
    -- Kiểm tra nếu thao tác trên hóa đơn thuê phòng cũ đã thanh toán
    IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
        SELECT trang_thai INTO v_trang_thai
        FROM hoadon
        WHERE id_hd = OLD.id_hd;

        IF v_trang_thai = 'Đã thanh toán' THEN
            RAISE EXCEPTION 'BẢO MẬT GIAO DỊCH: Không thể chỉnh sửa hoặc xóa chi tiết thuê phòng của hóa đơn đã thanh toán (Mã HĐ: %)!', OLD.id_hd;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- khachhang.func_check_child_age
CREATE OR REPLACE FUNCTION khachhang.func_check_child_age()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tuoi >= 18 THEN
        RAISE EXCEPTION 'RÀNG BUỘC ĐỘ TUỔI: Khách hàng trẻ em phải dưới 18 tuổi. Tuổi truyền vào (%) không hợp lệ!', NEW.tuoi;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 2. Define the three new transactional functions

-- hoadon.func_tinh_tong_tien_hoa_don
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_phong MONEY := 0::money;
    v_tien_dich_vu MONEY := 0::money;
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_tong_tien MONEY := 0::money;
BEGIN
    -- 1. Tính tổng tiền thuê các phòng của hóa đơn
    SELECT COALESCE(SUM(tong_tien), 0::money)
    INTO v_tien_phong
    FROM hoadon_thue_phong
    WHERE id_hd = p_id_hd;

    -- 2. Tính tổng tiền sử dụng dịch vụ của hóa đơn
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dich_vu
    FROM hoadon_sudung_dichvu hsd
    JOIN dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;

    -- 3. Lấy mức giảm giá hội viên của khách hàng liên kết với hóa đơn (dùng LEFT JOIN đề phòng không phải hội viên)
    SELECT COALESCE(hhv.muc_giam_gia, 0.00)
    INTO v_giam_gia_percent
    FROM hoadon h
    JOIN khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN hanghoivien hhv ON hv.hang = hhv.hang
    WHERE h.id_hd = p_id_hd;

    -- Đảm bảo không bị NULL nếu câu truy vấn không trả về dòng nào
    v_giam_gia_percent := COALESCE(v_giam_gia_percent, 0.00);

    -- 4. Tính toán tổng tiền sau giảm giá
    v_tong_tien := (v_tien_phong + v_tien_dich_vu) * (1 - v_giam_gia_percent / 100);

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- hoadon.func_thanh_toan_hoa_don
CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(
    p_id_hd INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS MONEY AS $$
DECLARE
    v_tong_thanh_toan MONEY;
    r RECORD;
BEGIN
    -- 1. Tính tổng tiền cuối cùng cần thanh toán
    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);

    -- 2. Cập nhật thông tin thanh toán cho hóa đơn
    UPDATE hoadon
    SET trang_thai = 'Đã thanh toán',
        ngaythanhtoan = CURRENT_DATE,
        phuongthuc = p_phuongthuc
    WHERE id_hd = p_id_hd;

    -- 3. Cập nhật trạng thái các phòng trong hóa đơn này sang 'Đang dọn dẹp'
    FOR r IN 
        SELECT id_p FROM hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = r.id_p;
    END LOOP;

    RETURN v_tong_thanh_toan;
END;
$$ LANGUAGE plpgsql;

-- hoadon.func_chuyen_phong
CREATE OR REPLACE FUNCTION hoadon.func_chuyen_phong(
    p_id_hd INT,
    p_id_p_cu INT,
    p_id_p_moi INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_trang_thai_moi VARCHAR(100);
    v_exists BOOLEAN;
BEGIN
    -- 1. Kiểm tra xem phòng mới có trống không
    SELECT trang_thai INTO v_trang_thai_moi
    FROM phong
    WHERE id_p = p_id_p_moi;

    IF v_trang_thai_moi != 'Còn trống' THEN
        RAISE NOTICE 'Phòng mới (ID: %) không ở trạng thái trống! Không thể chuyển.', p_id_p_moi;
        RETURN FALSE;
    END IF;

    -- 2. Kiểm tra xem phòng cũ có thuộc hóa đơn này không
    SELECT EXISTS(
        SELECT 1 FROM hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p_cu
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE NOTICE 'Phòng cũ (ID: %) không được đăng ký trong hóa đơn (ID: %)!', p_id_p_cu, p_id_hd;
        RETURN FALSE;
    END IF;

    -- 3. Cập nhật phòng mới vào chi tiết hóa đơn thuê phòng
    UPDATE hoadon_thue_phong
    SET id_p = p_id_p_moi
    WHERE id_hd = p_id_hd AND id_p = p_id_p_cu;

    -- 4. Cập nhật trạng thái phòng cũ sang 'Đang dọn dẹp'
    UPDATE phong
    SET trang_thai = 'Đang dọn dẹp'
    WHERE id_p = p_id_p_cu;

    -- 5. Cập nhật trạng thái phòng mới sang 'Đã đặt'
    UPDATE phong
    SET trang_thai = 'Đã đặt'
    WHERE id_p = p_id_p_moi;

    RAISE NOTICE 'Chuyển phòng thành công từ % sang % cho hóa đơn %.', p_id_p_cu, p_id_p_moi, p_id_hd;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
