-- -------------------------------------------------------------
-- Views
-- -------------------------------------------------------------

-- 1. View xem chi tiết phòng đầy đủ
CREATE OR REPLACE VIEW public.v_phong_status_detail AS
SELECT 
    p.id_p,
    cn.ten_cn,
    p.dia_chi,
    lp.chat_luong,
    lp.loai_giuong,
    lp.view,
    lp.dien_tich,
    lp.gia_tien,
    p.trang_thai
FROM public.phong p
LEFT JOIN public.loaiphong lp ON p.id_lp = lp.id_lp
LEFT JOIN public.chinhanh cn ON lp.id_cn = cn.id_cn;

-- 2. View tổng hợp doanh thu theo từng chi nhánh
CREATE OR REPLACE VIEW public.v_doanh_thu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    COALESCE(SUM(htp.tong_tien), 0) AS tong_doanh_thu_thue_phong,
    COUNT(DISTINCT h.id_hd) AS so_hoa_don
FROM public.chinhanh cn
LEFT JOIN public.loaiphong lp ON cn.id_cn = lp.id_cn
LEFT JOIN public.phong p ON lp.id_lp = p.id_lp
LEFT JOIN public.hoadon_thue_phong htp ON p.id_p = htp.id_p
LEFT JOIN public.hoadon h ON htp.id_hd = h.id_hd AND h.trang_thai = 'Đã thanh toán'
GROUP BY cn.id_cn, cn.ten_cn;

-- 3. View thông tin chủ sở hữu của từng chi nhánh
CREATE OR REPLACE VIEW public.v_thong_tin_chu_so_huu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    cn.dia_chi AS dia_chi_chi_nhanh,
    csh.id_csh,
    csh.ten_csh AS ten_chu_so_huu,
    csh.email AS email_chu_so_huu,
    csh.sdt AS sdt_chu_so_huu
FROM public.chinhanh cn
JOIN public.chinhanh_chusohuu cc ON cn.id_cn = cc.id_cn
JOIN public.chusohuu csh ON cc.id_csh = csh.id_csh;


-- -------------------------------------------------------------
-- Functions
-- -------------------------------------------------------------

-- 1. Hàm tính tiền phòng thuê
CREATE OR REPLACE FUNCTION public.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS NUMERIC AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_gia_tien NUMERIC(15,2);
    v_tien_coc NUMERIC(15,2);
    v_phu_thu NUMERIC(15,2);
    v_so_ngay INT;
    v_tong_tien NUMERIC(15,2);
BEGIN
    -- Lấy thông tin ngày nhận, ngày trả, tiền cọc, phụ thu
    SELECT ngaynhan, ngaytra, tien_coc, phu_thu
    INTO v_ngaynhan, v_ngaytra, v_tien_coc, v_phu_thu
    FROM public.hoadon_thue_phong
    WHERE id_hd = id_hd_input AND id_p = id_p_input;

    -- Lấy giá tiền phòng
    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM public.phong p
    JOIN public.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    -- Tính số ngày thuê (tối thiểu 1 ngày)
    v_so_ngay := EXTRACT(DAY FROM (v_ngaytra - v_ngaynhan))::INT;
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    -- Tính tổng tiền = (số ngày * giá phòng) + phụ thu - tiền cọc
    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0)) + COALESCE(v_phu_thu, 0) - COALESCE(v_tien_coc, 0);
    
    IF v_tong_tien < 0 THEN
        v_tong_tien := 0;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- 2. Hàm trigger tự động cập nhật điểm tích lũy cho hội viên khi hóa đơn được thanh toán
CREATE OR REPLACE FUNCTION public.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_diem_tich_luy_cong INT;
    v_tong_tien_phong NUMERIC(15,2);
BEGIN
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        -- Tìm xem khách hàng này có phải hội viên không
        SELECT id_hv INTO v_id_hv
        FROM public.khachhang
        WHERE id_kh = NEW.id_kh;

        IF v_id_hv IS NOT NULL THEN
            -- Tính tổng tiền của hóa đơn
            SELECT COALESCE(SUM(tong_tien), 0)
            INTO v_tong_tien_phong
            FROM public.hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;

            -- Mỗi 100,000 VND tiền phòng = 1 điểm tích lũy
            v_diem_tich_luy_cong := (v_tong_tien_phong / 100000)::INT;

            IF v_diem_tich_luy_cong > 0 THEN
                UPDATE public.hoivien
                SET diem_tich_luy = diem_tich_luy + v_diem_tich_luy_cong
                WHERE id_hv = v_id_hv;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Hàm trigger tự động cập nhật trạng thái phòng khi đặt phòng hoặc trả phòng
CREATE OR REPLACE FUNCTION public.func_dat_phong_auto_update_status()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.phong
        SET trang_thai = 'Đã đặt'
        WHERE id_p = NEW.id_p;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.phong
        SET trang_thai = 'Trống'
        WHERE id_p = OLD.id_p;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- -------------------------------------------------------------
-- Triggers
-- -------------------------------------------------------------

-- 1. Trigger tích điểm khi thanh toán hóa đơn
CREATE OR REPLACE TRIGGER trg_sau_khi_thanh_toan_hoadon
AFTER UPDATE OF trang_thai ON public.hoadon
FOR EACH ROW
EXECUTE FUNCTION public.func_cap_nhat_diem_tich_luy();

-- 2. Trigger tự cập nhật trạng thái phòng
CREATE OR REPLACE TRIGGER trg_dat_phong_auto_update_status
AFTER INSERT OR DELETE ON public.hoadon_thue_phong
FOR EACH ROW
EXECUTE FUNCTION public.func_dat_phong_auto_update_status();
