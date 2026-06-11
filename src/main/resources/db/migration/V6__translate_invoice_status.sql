-- 1. Translate invoice statuses from English to Vietnamese
UPDATE public.hoadon SET trang_thai = 'Đã thanh toán' WHERE trang_thai = 'Paid';
UPDATE public.hoadon SET trang_thai = 'Đã đặt' WHERE trang_thai = 'Unpaid';

-- 2. Recreate v_doanh_thu_chi_nhanh to only sum paid invoices
CREATE OR REPLACE VIEW public.v_doanh_thu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    COALESCE(SUM(CASE WHEN h.id_hd IS NOT NULL THEN htp.tong_tien ELSE 0::money END), 0::money)::numeric AS tong_doanh_thu_thue_phong,
    COUNT(DISTINCT h.id_hd) AS so_hoa_don
FROM public.chinhanh cn
LEFT JOIN public.loaiphong lp ON cn.id_cn = lp.id_cn
LEFT JOIN public.phong p ON lp.id_lp = p.id_lp
LEFT JOIN public.hoadon_thue_phong htp ON p.id_p = htp.id_p
LEFT JOIN public.hoadon h ON htp.id_hd = h.id_hd AND h.trang_thai = 'Đã thanh toán'
GROUP BY cn.id_cn, cn.ten_cn;
