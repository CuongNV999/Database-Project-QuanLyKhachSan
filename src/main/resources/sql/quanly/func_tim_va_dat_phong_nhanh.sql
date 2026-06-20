-- Function: Tìm phòng trống và thực hiện tạo hóa đơn đặt phòng nhanh (Có bộ lọc mở rộng: diện tích, tầm nhìn, đối tượng sử dụng)
-- Đầu vào:
--   p_id_kh: Mã khách hàng
--   p_id_nv: Mã nhân viên lập đơn
--   p_id_cn: Mã chi nhánh homestay
--   p_chat_luong: Chất lượng (tiêu chuẩn, cao cấp)
--   p_loai_giuong: Loại giường (đơn, đôi)
--   p_ngaynhan: Ngày nhận phòng dự kiến
--   p_ngaytra: Ngày trả phòng dự kiến
--   p_tien_coc: Tiền đặt cọc (mặc định 0 VNĐ)
--   p_phu_thu: Phụ thu ban đầu (mặc định 0 VNĐ)
--   p_dien_tich: Diện tích phòng (nhỏ, vừa, lớn - mặc định NULL để chọn bất kỳ)
--   p_view: Tầm nhìn (biển, núi, thành phố - mặc định NULL để chọn bất kỳ)
--   p_doi_tuong: Đối tượng sử dụng (cá nhân, cặp đôi, gia đình, nhóm - mặc định NULL để chọn bất kỳ)
-- Trả về: INT (Mã hóa đơn vừa đặt)

CREATE OR REPLACE FUNCTION quanly.func_tim_va_dat_phong_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    p_tien_coc MONEY DEFAULT 0::money,
    p_phu_thu MONEY DEFAULT 0::money,
    p_dien_tich VARCHAR(50) DEFAULT NULL,
    p_view VARCHAR(100) DEFAULT NULL,
    p_doi_tuong VARCHAR(100) DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_id_p INT;
    v_id_hd INT;
    v_gia_tien MONEY;
    v_tong_tien_phong MONEY;
    v_so_ngay_luu_tru INT;
BEGIN
    -- 1. Tìm phòng trống của chi nhánh và loại phòng phù hợp các tiêu chí (bao gồm cả lọc diện tích, view, đối tượng sử dụng) và không bị trùng lịch đặt trước
    SELECT p.id_p, lp.gia_tien INTO v_id_p, v_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND lp.chat_luong = p_chat_luong
      AND lp.loai_giuong = p_loai_giuong
      AND (p_dien_tich IS NULL OR lp.dien_tich = p_dien_tich)
      AND (p_view IS NULL OR lp.view = p_view)
      AND (p_doi_tuong IS NULL OR lp.doi_tuong = p_doi_tuong)
      AND p.trang_thai = 'Còn trống'
      AND NOT EXISTS (
          -- Kiểm tra trùng lịch với bất kỳ đặt phòng nào khác của phòng này chưa hủy
          SELECT 1 
          FROM hoadon.hoadon_thue_phong htp
          JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
          WHERE htp.id_p = p.id_p
            AND h.trang_thai != 'Đã hủy'
            AND htp.ngaynhan < p_ngaytra
            AND htp.ngaytra > p_ngaynhan
      )
    LIMIT 1;

    -- Nếu không tìm thấy phòng phù hợp, báo lỗi để dừng giao dịch
    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, giường %, diện tích %, view %, đối tượng % từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, COALESCE(p_dien_tich, 'Bất kỳ'), COALESCE(p_view, 'Bất kỳ'), COALESCE(p_doi_tuong, 'Bất kỳ'), p_ngaynhan, p_ngaytra;
    END IF;

    -- 2. Tạo hóa đơn mới ở trạng thái "Đã đặt"
    INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    -- Tính toán số ngày lưu trú từ dự kiến ban đầu
    v_so_ngay_luu_tru := EXTRACT(DAY FROM (p_ngaytra - p_ngaynhan))::INT;
    IF v_so_ngay_luu_tru <= 0 THEN
        v_so_ngay_luu_tru := 1;
    END IF;

    -- 3. Tạo bản ghi chi tiết thuê phòng (tạm thời để tổng tiền là 0)
    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru, tien_coc, phu_thu, tong_tien)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, v_so_ngay_luu_tru, p_tien_coc, p_phu_thu, 0::money);

    -- 4. Tính toán lại tổng tiền phòng thực tế dựa trên công thức nghiệp vụ
    v_tong_tien_phong := hoadon.func_tinh_tien_phong(v_id_hd, v_id_p);

    -- 5. Cập nhật lại tổng tiền phòng chính xác vào chi tiết hóa đơn
    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = v_id_hd AND id_p = v_id_p;

    -- 6. Trả về ID của hóa đơn mới được lập
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;
