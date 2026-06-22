-- Function: Tìm phòng trống và thực hiện tạo hóa đơn đặt phòng nhanh (Có bộ lọc mở rộng: diện tích, tầm nhìn, đối tượng sử dụng)
-- Đầu vào:
--   p_id_kh: Mã khách hàng
--   p_id_nv: Mã nhân viên lập đơn
--   p_id_cn: Mã chi nhánh homestay
--   p_chat_luong: Chất lượng (tiêu chuẩn, cao cấp)
--   p_loai_giuong: Loại giường (đơn, đôi)
--   p_ngaynhan: Ngày nhận phòng dự kiến
--   p_ngaytra: Ngày trả phòng dự kiến
--   p_tien_coc: Tiền đặt cọc (mặc định 0 VNĐ - không lưu trực tiếp vào bảng nữa)
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
    v_so_ngay_luu_tru INT;
BEGIN
    -- 1. Tìm phòng trống bằng helper function
    SELECT * INTO v_id_p, v_gia_tien
    FROM quanly.func_tim_phong_trong_phu_hop(
        p_id_cn, p_chat_luong, p_loai_giuong,
        p_dien_tich, p_view, p_doi_tuong,
        p_ngaynhan, p_ngaytra
    );

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

    -- 3. Tạo bản ghi chi tiết thuê phòng (đã loại bỏ cột tien_coc, tong_tien)
    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru, phu_thu_tieu_hao)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, v_so_ngay_luu_tru, p_phu_thu);

    -- 4. Trả về ID của hóa đơn mới được lập
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;
