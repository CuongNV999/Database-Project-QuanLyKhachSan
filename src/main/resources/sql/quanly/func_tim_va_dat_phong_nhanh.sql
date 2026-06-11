-- Function: Tìm phòng trống và thực hiện tạo hóa đơn đặt phòng nhanh
CREATE OR REPLACE FUNCTION quanly.func_tim_va_dat_phong_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    p_tien_coc MONEY DEFAULT 0::money,
    p_phu_thu MONEY DEFAULT 0::money
)
RETURNS INT AS $$
DECLARE
    v_id_p INT;
    v_id_hd INT;
    v_gia_tien MONEY;
    v_tong_tien_phong MONEY;
BEGIN
    -- 1. Tìm phòng trống của chi nhánh và loại phòng phù hợp không trùng lịch
    SELECT p.id_p, lp.gia_tien INTO v_id_p, v_gia_tien
    FROM phong p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND lp.chat_luong = p_chat_luong
      AND lp.loai_giuong = p_loai_giuong
      AND p.trang_thai = 'Còn trống'
      AND NOT EXISTS (
          -- Kiểm tra trùng lịch với bất kỳ đặt phòng nào chưa hủy
          SELECT 1 
          FROM hoadon_thue_phong htp
          JOIN hoadon h ON htp.id_hd = h.id_hd
          WHERE htp.id_p = p.id_p
            AND h.trang_thai != 'Đã hủy'
            AND htp.ngaynhan < p_ngaytra
            AND htp.ngaytra > p_ngaynhan
      )
    LIMIT 1;

    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, loại giường % trong khoảng thời gian từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, p_ngaynhan, p_ngaytra;
    END IF;

    -- 2. Tạo hóa đơn mới
    INSERT INTO hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    -- 3. Đăng ký thuê phòng
    -- Tạm thời đặt tổng tiền = 0::money, sau đó tính bằng function và cập nhật lại
    INSERT INTO hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, tien_coc, phu_thu, tong_tien)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, p_tien_coc, p_phu_thu, 0::money);

    -- 4. Tính toán tổng tiền thực tế
    v_tong_tien_phong := hoadon.func_tinh_tien_phong(v_id_hd, v_id_p);

    -- 5. Cập nhật lại tổng tiền trong chi tiết thuê phòng
    UPDATE hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = v_id_hd AND id_p = v_id_p;

    -- 6. Trả về ID hóa đơn mới
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;
