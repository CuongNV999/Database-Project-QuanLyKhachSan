-- -------------------------------------------------------------
-- 1. Trigger ngăn chặn đặt trùng phòng (Booking Overlap Prevention)
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.func_check_booking_overlap()
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
    FROM public.hoadon_thue_phong htp
    JOIN public.hoadon h ON htp.id_hd = h.id_hd
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

CREATE OR REPLACE TRIGGER trg_truoc_khi_dat_phong
BEFORE INSERT OR UPDATE ON public.hoadon_thue_phong
FOR EACH ROW
EXECUTE FUNCTION public.func_check_booking_overlap();


-- -------------------------------------------------------------
-- 2. Trigger khóa hóa đơn đã thanh toán (Prevent modifying paid bills)
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.func_prevent_paid_invoice_edit()
RETURNS TRIGGER AS $$
DECLARE
    v_trang_thai VARCHAR(100);
BEGIN
    -- Kiểm tra nếu thao tác trên hóa đơn thuê phòng cũ đã thanh toán
    IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
        SELECT trang_thai INTO v_trang_thai
        FROM public.hoadon
        WHERE id_hd = OLD.id_hd;

        IF v_trang_thai = 'Đã thanh toán' THEN
            RAISE EXCEPTION 'BẢO MẬT GIAO DỊCH: Không thể chỉnh sửa hoặc xóa chi tiết thuê phòng của hóa đơn đã thanh toán (Mã HĐ: %)!', OLD.id_hd;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_khoa_chi_tiet_hoa_don_da_thanh_toan
BEFORE UPDATE OR DELETE ON public.hoadon_thue_phong
FOR EACH ROW
EXECUTE FUNCTION public.func_prevent_paid_invoice_edit();


-- -------------------------------------------------------------
-- 3. Trigger kiểm soát tuổi của trẻ em
-- -------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.func_check_child_age()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tuoi >= 18 THEN
        RAISE EXCEPTION 'RÀNG BUỘC ĐỘ TUỔI: Khách hàng trẻ em phải dưới 18 tuổi. Tuổi truyền vào (%) không hợp lệ!', NEW.tuoi;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_kiem_tra_tuoi_tre_em
BEFORE INSERT OR UPDATE ON public.khachhang_treem
FOR EACH ROW
EXECUTE FUNCTION public.func_check_child_age();
