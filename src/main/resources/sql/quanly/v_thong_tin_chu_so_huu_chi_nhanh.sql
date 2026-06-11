-- View: Thông tin chủ sở hữu của từng chi nhánh cùng thông tin liên hệ
-- Câu lệnh định nghĩa view:

CREATE OR REPLACE VIEW v_thong_tin_chu_so_huu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    cn.dia_chi AS dia_chi_chi_nhanh,
    csh.id_csh,
    csh.ten_csh AS ten_chu_so_huu,
    csh.email AS email_chu_so_huu,
    csh.sdt AS sdt_chu_so_huu
FROM chinhanh cn
JOIN chinhanh_chusohuu cc ON cn.id_cn = cc.id_cn
JOIN chusohuu csh ON cc.id_csh = csh.id_csh;

-- Thử truy vấn: SELECT * FROM v_thong_tin_chu_so_huu_chi_nhanh;
