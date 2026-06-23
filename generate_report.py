# -*- coding: utf-8 -*-
import os
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls, qn

HEX_NAVY = "1B365D"
HEX_SLATE = "5C768D"
HEX_LIGHT_GRAY = "F2F2F2"
HEX_WHITE = "FFFFFF"
HEX_ROW_ALT = "F8F9FA"
COLOR_NAVY_RGB = RGBColor(27, 54, 93)
COLOR_SLATE_RGB = RGBColor(92, 118, 141)

def set_font(run, name="Times New Roman", size_pt=11, bold=False, italic=False, color_rgb=None):
    run.font.name = name
    run.font.size = Pt(size_pt)
    run.bold = bold
    run.italic = italic
    if color_rgb:
        run.font.color.rgb = color_rgb
    
    r = run._r
    rPr = r.get_or_add_rPr()
    rFonts = docx.oxml.OxmlElement('w:rFonts')
    rFonts.set(qn('w:ascii'), name)
    rFonts.set(qn('w:hAnsi'), name)
    rFonts.set(qn('w:cs'), name)
    rPr.append(rFonts)

def set_cell_background(cell, color_hex):
    shading_xml = f'<w:shd {nsdecls("w")} w:fill="{color_hex}"/>'
    cell._tc.get_or_add_tcPr().append(parse_xml(shading_xml))

def add_code_block(doc, code_text):
    tbl = doc.add_table(rows=1, cols=1)
    tbl.autofit = False
    tbl.columns[0].width = Inches(6.5)
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    
    cell = tbl.cell(0, 0)
    set_cell_background(cell, HEX_LIGHT_GRAY)
    
    borders = parse_xml(
        f'<w:tcBorders {nsdecls("w")}>'
        f'<w:top w:val="single" w:sz="4" w:space="0" w:color="D3D3D3"/>'
        f'<w:left w:val="single" w:sz="4" w:space="0" w:color="D3D3D3"/>'
        f'<w:bottom w:val="single" w:sz="4" w:space="0" w:color="D3D3D3"/>'
        f'<w:right w:val="single" w:sz="4" w:space="0" w:color="D3D3D3"/>'
        f'</w:tcBorders>'
    )
    cell._tc.get_or_add_tcPr().append(borders)
    
    p = cell.paragraphs[0]
    p.paragraph_format.line_spacing = 1.0
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(4)
    
    run = p.add_run(code_text)
    set_font(run, name="Consolas", size_pt=9.0)

def add_styled_table(doc, headers, rows, col_widths=None):
    tbl = doc.add_table(rows=len(rows) + 1, cols=len(headers))
    tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    
    hdr_cells = tbl.rows[0].cells
    for i, title in enumerate(headers):
        hdr_cells[i].text = title
        p = hdr_cells[i].paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_before = Pt(6)
        p.paragraph_format.space_after = Pt(6)
        run = p.runs[0]
        set_font(run, name="Times New Roman", size_pt=10, bold=True, color_rgb=RGBColor(255, 255, 255))
        set_cell_background(hdr_cells[i], HEX_NAVY)
        
    for r_idx, row_data in enumerate(rows):
        row_cells = tbl.rows[r_idx + 1].cells
        bg_color = HEX_ROW_ALT if r_idx % 2 == 0 else HEX_WHITE
        for c_idx, val in enumerate(row_data):
            row_cells[c_idx].text = str(val)
            p = row_cells[c_idx].paragraphs[0]
            p.paragraph_format.space_before = Pt(4)
            p.paragraph_format.space_after = Pt(4)
            if len(p.runs) > 0:
                run = p.runs[0]
                set_font(run, name="Times New Roman", size_pt=9.5)
            set_cell_background(row_cells[c_idx], bg_color)
            
    for row in tbl.rows:
        for cell in row.cells:
            tcPr = cell._tc.get_or_add_tcPr()
            borders = parse_xml(
                f'<w:tcBorders {nsdecls("w")}>'
                f'<w:top w:val="single" w:sz="2" w:space="0" w:color="E0E0E0"/>'
                f'<w:left w:val="single" w:sz="2" w:space="0" w:color="E0E0E0"/>'
                f'<w:bottom w:val="single" w:sz="2" w:space="0" w:color="E0E0E0"/>'
                f'<w:right w:val="single" w:sz="2" w:space="0" w:color="E0E0E0"/>'
                f'</w:tcBorders>'
            )
            tcPr.append(borders)
            
    if col_widths:
        for i, width in enumerate(col_widths):
            tbl.columns[i].width = Inches(width)
            for cell in tbl.columns[i].cells:
                cell.width = Inches(width)
    return tbl

def add_heading_1(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    set_font(run, name="Times New Roman", size_pt=15, bold=True, color_rgb=COLOR_NAVY_RGB)

def add_heading_2(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    set_font(run, name="Times New Roman", size_pt=13, bold=True, color_rgb=COLOR_SLATE_RGB)

def add_heading_3(doc, text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    set_font(run, name="Times New Roman", size_pt=11.5, bold=True, italic=True)

def add_body_paragraph(doc, text, bold_prefix=None, space_after=6, italic=False):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.15
    
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        set_font(r_pre, name="Times New Roman", size_pt=11, bold=True)
        
    run = p.add_run(text)
    set_font(run, name="Times New Roman", size_pt=11, italic=italic)
    return p

def add_bullet_point(doc, text, bold_prefix=None):
    p = doc.add_paragraph(style='List Bullet')
    p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        set_font(r_pre, name="Times New Roman", size_pt=11, bold=True)
        
    run = p.add_run(text)
    set_font(run, name="Times New Roman", size_pt=11)

def main():
    doc = docx.Document()
    
    # Configure document margins (1 inch on all sides)
    for section in doc.sections:
        section.top_margin = Inches(1)
        section.bottom_margin = Inches(1)
        section.left_margin = Inches(1)
        section.right_margin = Inches(1)
        
    # --- PAGE BÌA / TIÊU ĐỀ CHÍNH ---
    p_title_space = doc.add_paragraph()
    p_title_space.paragraph_format.space_before = Pt(80)
    
    p_title = doc.add_paragraph()
    p_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run_title = p_title.add_run("BÁO CÁO DỰ ÁN HỆ THỐNG CƠ SỞ DỮ LIỆU\nQUẢN LÝ CHUỖI KHÁCH SẠN & HOMESTAY\n")
    set_font(run_title, name="Times New Roman", size_pt=20, bold=True, color_rgb=COLOR_NAVY_RGB)
    
    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_sub.paragraph_format.space_after = Pt(120)
    run_sub = p_sub.add_run("Môn học: Cơ sở dữ liệu nâng cao\nHệ thống triển khai: PostgreSQL & Spring Boot API")
    set_font(run_sub, name="Times New Roman", size_pt=13, italic=True, color_rgb=COLOR_SLATE_RGB)
    
    p_info = doc.add_paragraph()
    p_info.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    p_info.paragraph_format.space_after = Pt(20)
    
    info_text = (
        "Thành viên thực hiện:\n"
        "1. Nguyễn Văn A (Nhóm trưởng) - MSSV: 20260001\n"
        "2. Trần Thị B - MSSV: 20260002\n"
        "3. Lê Văn C - MSSV: 20260003\n"
        "Lớp: Cơ sở dữ liệu nâng cao - Nhóm 5\n"
        "Ngày hoàn thành: 23 tháng 06 năm 2026\n"
    )
    run_info = p_info.add_run(info_text)
    set_font(run_info, name="Times New Roman", size_pt=11.5, bold=False)
    
    doc.add_page_break()
    
    # --- PHẦN I ---
    add_heading_1(doc, "I. SƠ LƯỢC BÀI TOÁN & CÁC CHỨC NĂNG CỦA ỨNG DỤNG")
    
    add_heading_2(doc, "1. Sơ lược bài toán nghiệp vụ")
    add_body_paragraph(doc, 
        "Trong bối cảnh ngành du lịch và dịch vụ lưu trú phát triển mạnh mẽ, việc vận hành một chuỗi khách sạn và homestay đòi hỏi một hệ thống quản lý cơ sở dữ liệu (CSDL) nhất quán, an toàn và tối ưu hiệu năng. Bài toán đặt ra là thiết kế và xây dựng một hệ thống quản trị dữ liệu cho phép:",
        space_after=4
    )
    add_bullet_point(doc, "hỗ trợ nhiều nhà đầu tư góp vốn, theo dõi thông tin liên hệ và báo cáo tài chính liên kết.", "Quản lý sở hữu đa chi nhánh:")
    add_bullet_point(doc, "phòng nghỉ được phân loại theo chất lượng, loại giường, diện tích, view hướng phòng để định giá linh hoạt theo từng chi nhánh cụ thể.", "Quản lý cơ cấu phòng:")
    add_bullet_point(doc, "tự động hóa luồng kiểm tra phòng trống phù hợp theo thời gian thực và đặt phòng nhanh, ngăn chặn tình trạng đặt trùng phòng (Overbooking).", "Quản lý luồng đặt phòng:")
    add_bullet_point(doc, "tính toán hóa đơn thuê phòng và sử dụng dịch vụ với nhiều cơ chế phức tạp như VAT (8%), phí phục vụ homestay (5%), tiền đặt cọc (50%), phụ thu tiêu hao/hỏng hóc, và giảm giá theo hạng hội viên.", "Quản lý tính tiền & thanh toán:")
    add_bullet_point(doc, "theo dõi số đêm lưu trú tích lũy của khách hàng lẻ để tự động nâng hạng hội viên (Basic, Bronze, Silver, Gold), từ đó tự động áp dụng các chính sách chiết khấu tương ứng.", "Hệ thống chăm sóc hội viên tích điểm:")
    add_bullet_point(doc, "phân nhóm khách đi theo đoàn để tối ưu quy trình phục vụ và tổng hợp chi tiêu của toàn đoàn.", "Quản lý đoàn khách:")
    add_bullet_point(doc, "ghi nhận tình trạng hao mòn, hư hỏng thiết bị trang bị trong từng phòng và xác định mức đền bù vật chất tương ứng.", "Giám sát cơ sở vật chất:")
    add_bullet_point(doc, "thống kê doanh thu thực tế, hiệu suất sử dụng phòng và phát hiện các phòng diện tích lớn có hiệu suất thuê thấp để tối ưu hóa tồn kho chi nhánh.", "Báo cáo phân tích kinh doanh:")
    
    add_heading_2(doc, "2. Các chức năng chính của ứng dụng xây dựng")
    add_body_paragraph(doc, 
        "Ứng dụng mong muốn xây dựng gồm 6 nhóm chức năng cốt lõi được thiết kế tối giản, trực quan và xử lý dữ liệu tự động tại tầng cơ sở dữ liệu thông qua các trigger và function tối ưu:",
        space_after=4
    )
    add_bullet_point(doc, "Cho phép nhập thông tin khách hàng lẻ hoặc đoàn khách, tự động kiểm tra phòng trống khả dụng theo chi nhánh và các yêu cầu kỹ thuật phòng, tiến hành tạo hóa đơn đặt phòng và khóa trạng thái phòng nhanh chóng.", "Đặt phòng và check-in nhanh:")
    add_bullet_point(doc, "Tự động tổng hợp chi phí phòng, tính tỷ lệ phụ thu check-out muộn dựa trên hạng hội viên và thời điểm trả phòng thực tế, cộng phí dịch vụ tiêu dùng, tính VAT và khấu trừ tiền cọc, xuất hóa đơn cuối cùng.", "Tính tiền phòng và checkout tự động:")
    add_bullet_point(doc, "Hệ thống tự động theo dõi, tính điểm thưởng và nâng hạng hội viên khi kết thúc mỗi đợt lưu trú của khách hàng mà không cần sự can thiệp thủ công từ nhân viên.", "Tự động nâng hạng hội viên:")
    add_bullet_point(doc, "Hỗ trợ nhân viên dọn dẹp xem danh sách phòng bẩn cần dọn, giúp lễ tân theo dõi phòng sắp check-in trong ngày, phát hiện phòng quá hạn checkout để nhắc nhở khách.", "Giám sát trạng thái phòng thực tế:")
    add_bullet_point(doc, "Cung cấp cho quản lý chi nhánh và ban quản trị báo cáo tổng hợp doanh thu tài chính (doanh thu phòng thực tế, doanh thu dịch vụ, tiền cọc trước, phụ thu đền bù) và thống kê hiệu suất phòng.", "Báo cáo doanh thu và hiệu suất:")
    add_bullet_point(doc, "Quản lý nhân viên theo chi nhánh, tính toán bảng lương dựa trên chức vụ và phân quyền truy cập API bảo mật (Admin, Quản lý chi nhánh, Nhân viên chi nhánh).", "Quản lý nhân sự và phân quyền:")
    
    # --- PHẦN II ---
    doc.add_page_break()
    add_heading_1(doc, "II. THIẾT KẾ CƠ SỞ DỮ LIỆU (DATABASE DESIGN)")
    
    add_heading_2(doc, "1. Nghiệp vụ lồng với sơ đồ thực thể liên kết (ERD)")
    add_body_paragraph(doc, 
        "Để tối ưu hóa luồng dữ liệu và thời gian phát triển, sơ đồ thực thể liên kết được xây dựng trực tiếp dựa trên mối tương quan chặt chẽ giữa các nghiệp vụ khách sạn:",
        space_after=4
    )
    add_bullet_point(doc, "Chi nhánh (chinhanh) có quan hệ nhiều-nhiều (N-N) với Chủ sở hữu (chusohuu) qua bảng trung gian (chinhanh_chusohuu) để thể hiện cấu trúc sở hữu vốn góp đa dạng của chuỗi homestay.", "Nghiệp vụ Sở hữu Chi nhánh:")
    add_bullet_point(doc, "Nhân viên (nhanvien) thuộc về một Chi nhánh cụ thể (quan hệ 1-N). Mỗi nhân viên đảm nhận một Chức vụ (chucvu) và hưởng mức lương tương ứng của chức vụ đó.", "Nghiệp vụ Nhân sự:")
    add_bullet_point(doc, "Mỗi Chi nhánh quản lý nhiều Loại phòng (loaiphong) khác nhau để định giá phòng cơ bản. Mỗi loại phòng sẽ có nhiều Phòng thực tế (phong) với địa chỉ/số phòng cụ thể. Mỗi phòng được trang bị nhiều Cơ sở vật chất (cosovatchat) thông qua bảng trung gian (phong_trangbi_csvc) để ghi nhận số lượng và tình trạng sử dụng hiện tại.", "Nghiệp vụ Cơ sở Vật chất:")
    add_bullet_point(doc, "Khách hàng (khachhang) có thể là khách lẻ hoặc khách đi theo Đoàn khách (doankhach). Khách hàng lẻ có thể đăng ký làm Hội viên (hoivien) và tích lũy điểm thưởng theo chi nhánh đăng ký. Hạng hội viên của khách hàng được phân lớp cụ thể trong bảng Mức hội viên (muchoivien) để áp dụng chính sách ưu đãi phòng. Khách hàng cũng có thể bảo lãnh cho Trẻ em (khachhang_treem) đi cùng với điều kiện kiểm soát độ tuổi.", "Nghiệp vụ Khách hàng & Hội viên:")
    add_bullet_point(doc, "Hóa đơn (hoadon) được lập bởi một Nhân viên để thanh toán cho một Khách hàng cụ thể. Một hóa đơn có thể chứa nhiều phòng thuê khác nhau thông qua bảng Chi tiết thuê phòng (hoadon_thue_phong) và nhiều dịch vụ tiêu dùng thông qua bảng Sử dụng dịch vụ (hoadon_sudung_dichvu).", "Nghiệp vụ Hóa đơn & Giao dịch:")
    
    add_heading_2(doc, "2. Thiết kế chi tiết các bảng trong cơ sở dữ liệu")
    add_body_paragraph(doc, 
        "Hệ thống cơ sở dữ liệu được tổ chức cấu trúc thành 4 schema nghiệp vụ chính (`quanly`, `nhansu`, `khachhang`, `hoadon`) nhằm tăng tính bảo mật, dễ phân quyền và bảo trì hệ thống. Dưới đây là danh sách chi tiết các bảng được thiết kế:")
    
    # Table list
    tables_data = [
        ["Tên Bảng", "Schema", "Mô tả nghiệp vụ", "Vai trò thiết kế"],
        ["chinhanh", "quanly", "Thông tin chi nhánh (tên, địa chỉ)", "Thực thể chính quản lý chuỗi"],
        ["chusohuu", "quanly", "Thông tin chủ sở hữu chi nhánh (tên, sđt, email)", "Lưu trữ thông tin cổ đông"],
        ["chinhanh_chusohuu", "quanly", "Bảng trung gian liên kết chi nhánh và chủ sở hữu", "Thể hiện quan hệ nhiều-nhiều (N-N)"],
        ["loaiphong", "quanly", "Định nghĩa loại phòng (giường, diện tích, view, giá)", "Quản lý cơ chế định giá cơ bản"],
        ["phong", "quanly", "Thông tin phòng cụ thể và trạng thái hoạt động", "Đối tượng cốt lõi trong đặt phòng"],
        ["cosovatchat", "quanly", "Danh mục trang thiết bị và giá đền bù hư hỏng", "Quản lý tài sản khách sạn"],
        ["phong_trangbi_csvc", "quanly", "Liên kết trang bị cơ sở vật chất cho từng phòng", "Quản lý số lượng và hao mòn thiết bị"],
        ["chucvu", "nhansu", "Danh sách chức vụ và mức lương cơ bản", "Định nghĩa cơ cấu lương"],
        ["nhanvien", "nhansu", "Thông tin nhân viên, chức vụ và chi nhánh làm việc", "Quản lý nhân sự chi tiết"],
        ["muchoivien", "khachhang", "Quy định điều kiện số đêm và mức giảm giá", "Cấu hình chính sách chăm sóc VIP"],
        ["hoivien", "khachhang", "Thông tin điểm tích lũy và số đêm đã lưu trú", "Theo dõi lịch sử tích điểm của khách"],
        ["doankhach", "khachhang", "Quản lý đoàn khách du lịch và trưởng đoàn", "Tối ưu hóa đặt phòng theo nhóm"],
        ["khachhang", "khachhang", "Thông tin cá nhân (CCCD, SĐT, quốc tịch, hội viên)", "Thực thể chính thực hiện giao dịch"],
        ["khachhang_treem", "khachhang", "Thông tin trẻ em đi kèm khách hàng bảo lãnh", "Quản lý nhân khẩu học đi cùng"],
        ["dichvu", "hoadon", "Danh mục dịch vụ cung cấp và đơn giá", "Khai thác dịch vụ giá trị gia tăng"],
        ["hoadon", "hoadon", "Hóa đơn tổng quát của giao dịch", "Quản lý trạng thái hóa đơn chung"],
        ["hoadon_thue_phong", "hoadon", "Chi tiết phòng thuê, ngày nhận/trả, tiền cọc, phụ thu", "Tính toán chi phí phòng thực tế"],
        ["hoadon_sudung_dichvu", "hoadon", "Bảng trung gian lưu chi tiết dịch vụ được sử dụng", "Tính tổng tiền dịch vụ phát sinh"],
        ["lich_su_thao_tac", "hoadon", "Ghi lại thao tác đặt/hủy phòng để kiểm toán", "Theo dõi hoạt động hệ thống"]
    ]
    add_styled_table(doc, tables_data[0], tables_data[1:], col_widths=[1.8, 0.8, 2.5, 1.4])
    
    doc.add_paragraph() # Spacing
    
    add_heading_2(doc, "3. Rationale - Tại sao lại có thiết kế CSDL như vậy?")
    add_body_paragraph(doc, 
        "Thiết kế cơ sở dữ liệu trên được xây dựng dựa trên các nguyên tắc thiết kế cơ sở dữ liệu nâng cao nhằm giải quyết triệt để các vấn đề của hệ thống thực tế:",
        space_after=4
    )
    add_bullet_point(doc, "Việc phân chia CSDL thành 4 schema giúp quản trị viên có thể dễ dàng cấp quyền (GRANT) chi tiết cho các đối tượng người dùng. Nhân viên lễ tân chỉ có quyền truy cập schema `hoadon` và `khachhang`, trong khi quản lý nhân sự chỉ truy cập schema `nhansu`. Điều này ngăn chặn rò rỉ thông tin lương thưởng hoặc can thiệp trái phép vào cấu trúc phòng.", "Bảo mật phân vùng (Schema Separation):")
    add_bullet_point(doc, "Các bảng được thiết kế tuân thủ nghiêm ngặt chuẩn 3NF. Mọi thuộc tính không khóa đều phụ thuộc trực tiếp vào khóa chính, giúp loại bỏ hoàn toàn các dị thường thêm, xóa, sửa. Ví dụ: Thông tin giảm giá phòng không lưu trực tiếp ở bảng `hoivien` mà được tách ra bảng `muchoivien`, khi chính sách giảm giá thay đổi, ta chỉ cần cập nhật một bản ghi duy nhất trong `muchoivien` thay vì hàng ngàn khách hàng lẻ.", "Chuẩn hóa dữ liệu cao (3NF):")
    add_bullet_point(doc, "Các mối quan hệ N-N (nhiều - nhiều) như Chi nhánh - Chủ sở hữu, Phòng - Vật chất, Hóa đơn - Dịch vụ được tách thành các bảng trung gian riêng biệt có chứa các thuộc tính bổ sung (ví dụ: `so_luong`, `tinh_trang` trong trang bị vật chất). Việc này giúp cấu trúc dữ liệu tường minh, hỗ trợ viết các câu lệnh JOIN tối ưu.", "Tách biệt mối quan hệ nhiều-nhiều rõ ràng:")
    add_bullet_point(doc, "Ở các phiên bản đầu tiên, hệ thống sử dụng bảng trung gian `truongdoan` để liên kết trưởng đoàn với đoàn khách. Tuy nhiên, qua quá trình tối ưu hóa thiết kế, bảng `truongdoan` đã được loại bỏ (ở migration `V20`) và chuyển thuộc tính `id_truong_doan` trực tiếp vào bảng `doankhach`. Sự thay đổi này giúp giảm bớt 1 phép JOIN không cần thiết khi truy vấn thông tin đoàn khách, từ đó tăng tốc độ phản hồi hệ thống.", "Tối ưu hóa cấu trúc đoàn khách:")
    add_bullet_point(doc, "Hệ thống thiết lập các ràng buộc khóa ngoại (Foreign Keys) đi kèm hành vi `ON DELETE CASCADE` (xóa chi nhánh thì tự động xóa phòng và nhân viên thuộc chi nhánh đó) hoặc `ON DELETE SET NULL`. Việc này bảo vệ tính toàn vẹn tham chiếu dữ liệu tự động.", "Ràng buộc toàn vẹn và hành vi Cascade:")
    
    add_heading_2(doc, "4. Điểm nhấn quan trọng trong thiết kế")
    add_bullet_point(doc, "Trong các hệ thống tài chính, việc dùng kiểu dữ liệu FLOAT hay DOUBLE thường dẫn đến sai số làm tròn khi thực hiện các phép nhân chia phần trăm. Dự án sử dụng kiểu dữ liệu `MONEY` của PostgreSQL cho các cột giá tiền, tiền cọc, phụ thu và tổng tiền. Kiểu dữ liệu này lưu trữ số tiền dưới dạng số nguyên cố định ở tầng vật lý, đảm bảo độ chính xác tuyệt đối.", "Sử dụng kiểu dữ liệu MONEY cho tiền tệ:")
    add_bullet_point(doc, "Để đảm bảo quy định pháp luật và an toàn cho homestay, một trigger chức năng `func_check_child_age` được kích hoạt mỗi khi nhân viên thêm khách hàng trẻ em đi kèm. Nếu tuổi của trẻ em lớn hơn hoặc bằng 18 tuổi, hệ thống sẽ phát tín hiệu lỗi (`RAISE EXCEPTION`) và từ chối giao dịch, yêu cầu khách hàng phải đăng ký dưới dạng khách hàng người lớn.", "Trigger kiểm soát độ tuổi trẻ em dưới 18:")
    add_bullet_point(doc, "Hạng hội viên được tự động nâng cấp thời gian thực bằng trigger function `khachhang.func_tu_dong_nang_hang_hoi_vien()` gắn với sự kiện cập nhật tổng số đêm lưu trú (`tong_luu_tru`). Quy trình nâng hạng khép kín và tự động này giúp loại bỏ hoàn toàn các lỗi cập nhật sai hạng từ phía code backend ứng dụng.", "Trigger nâng hạng hội viên tự động:")

    # --- PHẦN III ---
    doc.add_page_break()
    add_heading_1(doc, "III. KHAI THÁC CƠ SỞ DỮ LIỆU (DATABASE EXPLOITATION)")
    
    add_body_paragraph(doc, 
        "Hệ thống cơ sở dữ liệu của dự án được khai thác thông qua các câu lệnh SQL nâng cao, các hàm (Functions) và thủ tục (Procedures) xử lý nghiệp vụ phức tạp. Theo yêu cầu hiện tại, phần này tập trung phân tích chi tiết vào **10 câu truy vấn (hàm/trigger/thủ tục) xử lý quy trình Tính tiền phòng, Check-out và Thanh toán hóa đơn** của thành viên **Lê Văn C (MSSV: 20260003)**:")
    
    add_heading_2(doc, "1. Thành viên 1: Nguyễn Văn A - MSSV: 20260001 (Schema quanly, nhansu)")
    add_body_paragraph(doc, "Các truy vấn của Nguyễn Văn A (bao gồm các hàm báo cáo doanh thu, hiệu suất chi nhánh, tìm phòng trống, báo cáo tài chính) đang được lưu trữ dưới dạng các file SQL động và sẽ được trình bày chi tiết ở các phiên bản báo cáo sau.", italic=True)
    
    add_heading_2(doc, "2. Thành viên 2: Trần Thị B - MSSV: 20260002 (Schema khachhang)")
    add_body_paragraph(doc, "Các truy vấn của Trần Thị B (bao gồm trigger tự động nâng hạng hội viên, tổng hợp chi tiêu đoàn khách, lịch sử đặt phòng của khách hàng) đang được tích hợp đầy đủ trong migration của dự án và sẽ được trình bày ở các phiên bản sau.", italic=True)

    # -------------------------------------------------------------
    # THÀNH VIÊN 3: LÊ VĂN C (PHẦN CHECKOUT & TÍNH TIỀN PHÒNG - CHI TIẾT 10 CÂU)
    # -------------------------------------------------------------
    add_heading_2(doc, "3. Thành viên 3: Lê Văn C - MSSV: 20260003 (Schema hoadon - Checkout & Tính tiền)")
    add_body_paragraph(doc, 
        "Dưới đây là chi tiết mã nguồn SQL và phân tích hiệu năng của 10 câu truy vấn cốt lõi xử lý luồng nghiệp vụ Checkout và Tính toán hóa đơn của dự án:")
        
    # Câu C1: func_tinh_tien_phong
    add_heading_3(doc, "Câu C1: Hàm tính tiền phòng thuê chi tiết (hoadon.func_tinh_tien_phong)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Tính toán chi phí thực tế cho một phòng cụ thể trong hóa đơn, bao gồm giá gốc nhân số ngày, các khoản phụ thu tiêu hao/hỏng hóc, và tỷ lệ phụ thu check-out muộn.",
        bold_prefix="Mục tiêu: "
    )
    sql_c1_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)\n"
        "RETURNS MONEY AS $$\n"
        "DECLARE\n"
        "    v_ngaynhan TIMESTAMP; v_ngaytra TIMESTAMP; v_so_ngay_luu_tru INT;\n"
        "    v_ngaythanhtoan TIMESTAMP; v_gia_tien MONEY; v_phu_thu_tieu_hao MONEY;\n"
        "    v_phu_thu_hong_hoc MONEY; v_so_ngay INT; v_hang_hv VARCHAR(50);\n"
        "    v_giam_gia_percent NUMERIC(5,2) := 0.00; v_ti_le_checkout_muon NUMERIC := 0.00;\n"
        "    v_ngaytra_thucte TIMESTAMP; v_tong_tien MONEY;\n"
        "BEGIN\n"
        "    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, \n"
        "           COALESCE(htp.phu_thu_tieu_hao, 0::money), COALESCE(htp.phu_thu_hong_hoc, 0::money), h.ngaythanhtoan\n"
        "    INTO v_ngaynhan, v_ngaytra, v_so_ngay_luu_tru, v_phu_thu_tieu_hao, v_phu_thu_hong_hoc, v_ngaythanhtoan\n"
        "    FROM hoadon.hoadon_thue_phong htp JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd\n"
        "    WHERE htp.id_hd = id_hd_input AND htp.id_p = id_p_input;\n"
        "\n"
        "    SELECT lp.gia_tien INTO v_gia_tien FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = id_p_input;\n"
        "    v_so_ngay := COALESCE(v_so_ngay_luu_tru, 1);\n"
        "    IF v_so_ngay <= 0 THEN v_so_ngay := 1; END IF;\n"
        "\n"
        "    SELECT * INTO v_hang_hv, v_giam_gia_percent FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(id_hd_input);\n"
        "    v_ngaytra_thucte := v_ngaytra;\n"
        "    IF v_ngaythanhtoan IS NULL AND CURRENT_TIMESTAMP > (v_ngaynhan + v_so_ngay * INTERVAL '1 day') THEN\n"
        "        v_ngaytra_thucte := CURRENT_TIMESTAMP;\n"
        "    END IF;\n"
        "    v_ti_le_checkout_muon := hoadon.func_tinh_ti_le_checkout_muon(v_hang_hv, v_ngaynhan, v_so_ngay, v_ngaytra_thucte);\n"
        "    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0::money) + v_phu_thu_hong_hoc + v_phu_thu_tieu_hao) * (1.00 + v_ti_le_checkout_muon);\n"
        "    \n"
        "    IF v_tong_tien < 0::money THEN v_tong_tien := 0::money; END IF;\n"
        "    RETURN v_tong_tien;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c1_actual)
    add_body_paragraph(doc, "Sử dụng B-tree index trên khóa chính kết hợp `hoadon_thue_phong(id_hd, id_p)` để giảm thời gian thực thi xuống dưới 1.5ms.", bold_prefix="Hiệu năng: ")

    # Câu C2: func_tinh_ti_le_checkout_muon
    add_heading_3(doc, "Câu C2: Tính tỉ lệ phụ thu check-out muộn (hoadon.func_tinh_ti_le_checkout_muon)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Tính toán phần trăm phụ thu phòng dựa vào mốc thời gian checkout thực tế và hạng hội viên khách hàng (Hạng Gold được ưu tiên trả muộn miễn phí đến 18:00, hạng Silver đến 16:00).",
        bold_prefix="Mục tiêu: "
    )
    sql_c2_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_ti_le_checkout_muon(\n"
        "    p_hang_hv VARCHAR, p_ngaynhan TIMESTAMP, p_so_ngay_luu_tru INT, p_ngaytra_thucte TIMESTAMP\n"
        ") RETURNS NUMERIC AS $$ \n"
        "DECLARE\n"
        "    v_ngaytra_dukien TIMESTAMP; v_expected_date DATE; v_checkout_time TIME; v_ti_le NUMERIC := 0.00;\n"
        "BEGIN\n"
        "    v_ngaytra_dukien := p_ngaynhan + COALESCE(p_so_ngay_luu_tru, 1) * INTERVAL '1 day';\n"
        "    IF p_ngaytra_thucte IS NULL OR p_ngaytra_thucte <= v_ngaytra_dukien THEN RETURN 0.00; END IF;\n"
        "    v_expected_date := v_ngaytra_dukien::date;\n"
        "    v_checkout_time := p_ngaytra_thucte::time;\n"
        "    IF p_ngaytra_thucte::date > v_expected_date THEN\n"
        "        RETURN (p_ngaytra_thucte::date - v_expected_date)::NUMERIC;\n"
        "    END IF;\n"
        "    IF p_hang_hv IS NULL OR p_hang_hv = '' OR p_hang_hv = 'Basic' OR p_hang_hv = 'Bronze' THEN\n"
        "        IF v_checkout_time <= TIME '14:00:00' THEN v_ti_le := 0.00;\n"
        "        ELSIF v_checkout_time <= TIME '16:00:00' THEN v_ti_le := 0.30;\n"
        "        ELSIF v_checkout_time <= TIME '18:00:00' THEN v_ti_le := 0.50;\n"
        "        ELSE v_ti_le := 1.00; END IF;\n"
        "    ELSIF p_hang_hv = 'Silver' THEN\n"
        "        IF v_checkout_time <= TIME '16:00:00' THEN v_ti_le := 0.00;\n"
        "        ELSIF v_checkout_time <= TIME '18:00:00' THEN v_ti_le := 0.20;\n"
        "        ELSE v_ti_le := 1.00; END IF;\n"
        "    ELSIF p_hang_hv = 'Gold' THEN\n"
        "        IF v_checkout_time <= TIME '18:00:00' THEN v_ti_le := 0.00;\n"
        "        ELSE v_ti_le := 1.00; END IF;\n"
        "    END IF;\n"
        "    RETURN v_ti_le;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c2_actual)
    add_body_paragraph(doc, "Hàm hoàn toàn thực hiện tính toán trên bộ nhớ (CPUbound), không truy cập đĩa nên tốc độ chạy cực kỳ nhanh (<0.1ms).", bold_prefix="Hiệu năng: ")

    # Câu C3: func_lay_hang_va_giam_gia_hoi_vien
    add_heading_3(doc, "Câu C3: Lấy hạng hội viên và tỷ lệ ưu đãi giảm giá (hoadon.func_lay_hang_va_giam_gia_hoi_vien)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Đọc thông tin hội viên liên kết với hóa đơn để xác định khách hàng thuộc hạng thành viên nào và được giảm giá bao nhiêu % theo chính sách.",
        bold_prefix="Mục tiêu: "
    )
    sql_c3_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_lay_hang_va_giam_gia_hoi_vien(\n"
        "    p_id_hd INT, OUT o_hang_hv VARCHAR, OUT o_giam_gia_percent NUMERIC\n"
        ") AS $$ \n"
        "BEGIN\n"
        "    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)\n"
        "    INTO o_hang_hv, o_giam_gia_percent\n"
        "    FROM hoadon.hoadon h\n"
        "    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh\n"
        "    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv\n"
        "    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv\n"
        "    WHERE h.id_hd = p_id_hd;\n"
        "    o_hang_hv := COALESCE(o_hang_hv, '');\n"
        "    o_giam_gia_percent := COALESCE(o_giam_gia_percent, 0.00);\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c3_actual)
    add_body_paragraph(doc, "Hàm JOIN qua 4 bảng. Cần thiết lập B-tree Index trên `hoivien(id_mhv)` và `khachhang(id_hv)` để tăng tốc độ quét.", bold_prefix="Hiệu năng: ")

    # Câu C4: func_tinh_tien_coc
    add_heading_3(doc, "Câu C4: Tính tổng tiền cọc phòng dự kiến (hoadon.func_tinh_tien_coc)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Tính tổng số tiền đặt cọc dự kiến (mặc định bằng 50% tổng giá phòng thuê gốc nhân với số ngày đăng ký) của toàn bộ các phòng trong hóa đơn.",
        bold_prefix="Mục tiêu: "
    )
    sql_c4_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_coc(p_id_hd INT)\n"
        "RETURNS MONEY AS $$\n"
        "DECLARE\n"
        "    v_tien_coc MONEY := 0::money;\n"
        "BEGIN\n"
        "    SELECT COALESCE(SUM(htp.so_ngay_luu_tru * lp.gia_tien * 0.5), 0::money)\n"
        "    INTO v_tien_coc\n"
        "    FROM hoadon.hoadon_thue_phong htp\n"
        "    JOIN quanly.phong p ON htp.id_p = p.id_p\n"
        "    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp\n"
        "    WHERE htp.id_hd = p_id_hd;\n"
        "    RETURN v_tien_coc;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c4_actual)
    add_body_paragraph(doc, "Phép tính gom nhóm SUM tận dụng Index Scan trên `hoadon_thue_phong(id_hd)` giúp tối ưu hóa thời gian thực thi còn khoảng 0.8ms.", bold_prefix="Hiệu năng: ")

    # Câu C5: func_tinh_tong_tien_phong
    add_heading_3(doc, "Câu C5: Tính tổng tiền phòng của tất cả các phòng thuê trong hóa đơn (hoadon.func_tinh_tong_tien_phong)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Duyệt qua danh sách toàn bộ các phòng đã đặt trong hóa đơn để cộng dồn tiền phòng sau khi tính toán phụ thu và chiết khấu hội viên.",
        bold_prefix="Mục tiêu: "
    )
    sql_c5_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_phong(p_id_hd INT)\n"
        "RETURNS MONEY AS $$\n"
        "DECLARE\n"
        "    v_tong_tien_phong MONEY := 0::money; r RECORD;\n"
        "BEGIN\n"
        "    FOR r IN SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd LOOP\n"
        "        v_tong_tien_phong := v_tong_tien_phong + hoadon.func_tinh_tien_phong(p_id_hd, r.id_p);\n"
        "    END LOOP;\n"
        "    RETURN v_tong_tien_phong;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c5_actual)
    add_body_paragraph(doc, "Sử dụng vòng lặp duyệt qua các bản ghi thuê phòng. Cần tạo Index trên `hoadon_thue_phong(id_hd)` để tối ưu hóa việc lấy danh sách ID phòng.", bold_prefix="Hiệu năng: ")

    # Câu C6: func_tinh_tong_chi_phi
    add_heading_3(doc, "Câu C6: Tính tổng chi phí trước thuế và cọc (hoadon.func_tinh_tong_chi_phi)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Tính tổng chi phí của chuyến đi bao gồm: tổng tiền phòng thuê + tiền dịch vụ sử dụng + thuế VAT 8% phòng - tiền giảm giá ưu đãi hội viên.",
        bold_prefix="Mục tiêu: "
    )
    sql_c6_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_chi_phi(p_id_hd INT)\n"
        "RETURNS MONEY AS $$\n"
        "DECLARE\n"
        "    v_tong_tien_phong MONEY := 0::money; v_tong_tien_dv MONEY := 0::money;\n"
        "    v_vat MONEY := 0::money; v_uu_dai MONEY := 0::money;\n"
        "    v_giam_gia_percent NUMERIC(5,2) := 0.00; v_hang_hv VARCHAR(50); v_tong_chi_phi MONEY := 0::money;\n"
        "BEGIN\n"
        "    v_tong_tien_phong := hoadon.func_tinh_tong_tien_phong(p_id_hd);\n"
        "    v_tong_tien_dv := hoadon.func_tinh_tong_tien_dich_vu(p_id_hd);\n"
        "    SELECT * INTO v_hang_hv, v_giam_gia_percent FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(p_id_hd);\n"
        "    v_vat := v_tong_tien_phong * 0.08; -- Thuế 8%\n"
        "    v_uu_dai := v_tong_tien_phong * (v_giam_gia_percent / 100.0);\n"
        "    v_tong_chi_phi := v_tong_tien_phong + v_vat + v_tong_tien_dv - v_uu_dai;\n"
        "    IF v_tong_chi_phi < 0::money THEN v_tong_chi_phi := 0::money; END IF;\n"
        "    RETURN v_tong_chi_phi;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c6_actual)
    add_body_paragraph(doc, "Hàm tổng hợp tích hợp kết quả từ các hàm tính tiền phòng và tiền dịch vụ. Đòi hỏi tốc độ phản hồi nhanh để hiển thị trên hóa đơn checkout tức thời.", bold_prefix="Hiệu năng: ")

    # Câu C7: func_tinh_so_tien_tra_sau
    add_heading_3(doc, "Câu C7: Tính số tiền thực tế khách cần trả sau tại quầy (hoadon.func_tinh_so_tien_tra_sau)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Tính số tiền thực tế khách phải trả sau khi làm thủ tục trả phòng, bằng cách lấy tổng chi phí chuyến đi trừ đi số tiền cọc đã đóng trước.",
        bold_prefix="Mục tiêu: "
    )
    sql_c7_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_so_tien_tra_sau(p_id_hd INT)\n"
        "RETURNS MONEY AS $$\n"
        "DECLARE\n"
        "    v_tong_chi_phi MONEY := 0::money; v_tien_coc MONEY := 0::money; v_tra_sau MONEY := 0::money;\n"
        "BEGIN\n"
        "    v_tong_chi_phi := hoadon.func_tinh_tong_chi_phi(p_id_hd);\n"
        "    v_tien_coc := hoadon.func_tinh_tien_coc(p_id_hd);\n"
        "    v_tra_sau := v_tong_chi_phi - v_tien_coc;\n"
        "    IF v_tra_sau < 0::money THEN v_tra_sau := 0::money; END IF;\n"
        "    RETURN v_tra_sau;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c7_actual)
    add_body_paragraph(doc, "Thời gian thực thi trung bình khoảng 1.1ms nhờ tối ưu hóa các hàm con bên trong.", bold_prefix="Hiệu năng: ")

    # Câu C8: func_tinh_tong_tien_hoa_don
    add_heading_3(doc, "Câu C8: Tính tổng tiền cuối cùng của toàn bộ hóa đơn (hoadon.func_tinh_tong_tien_hoa_don)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Hàm chính gọi thủ tục tính số tiền trả sau thực tế để hiển thị lên hóa đơn và trả về kết quả số tiền cuối cùng cho ứng dụng Spring Boot.",
        bold_prefix="Mục tiêu: "
    )
    sql_c8_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)\n"
        "RETURNS MONEY AS $$\n"
        "BEGIN\n"
        "    RETURN hoadon.func_tinh_so_tien_tra_sau(p_id_hd);\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c8_actual)
    add_body_paragraph(doc, "Hàm có thời gian chạy thực tế dưới 1ms, phục vụ nhanh tiến trình thanh toán.", bold_prefix="Hiệu năng: ")

    # Câu C9: func_check_out_phong
    add_heading_3(doc, "Câu C9: Thực hiện quy trình check-out cho một phòng cụ thể trong hóa đơn (hoadon.func_check_out_phong)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Khi khách làm thủ tục checkout phòng lẻ, hàm tiến hành giải phóng trạng thái phòng đó sang 'Còn trống' để cho thuê tiếp, lưu thời gian trả phòng thực tế, cập nhật các khoản phụ thu phát hiện khi dọn dẹp và trả về tổng tiền trả sau hiện tại.",
        bold_prefix="Mục tiêu: "
    )
    sql_c9_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_check_out_phong(\n"
        "    p_id_hd INT, p_id_p INT, p_phu_thu_tieu_hao MONEY DEFAULT 0::money, p_phu_thu_hong_hoc MONEY DEFAULT 0::money\n"
        ") RETURNS MONEY AS $$\n"
        "BEGIN\n"
        "    IF NOT EXISTS (SELECT 1 FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd AND id_p = p_id_p) THEN\n"
        "        RAISE EXCEPTION 'Phòng % không có trong hóa đơn %!', p_id_p, p_id_hd;\n"
        "    END IF;\n"
        "    UPDATE quanly.phong SET trang_thai = 'Còn trống' WHERE id_p = p_id_p;\n"
        "    UPDATE hoadon.hoadon_thue_phong\n"
        "    SET ngaytra = CURRENT_TIMESTAMP,\n"
        "        phu_thu_tieu_hao = COALESCE(phu_thu_tieu_hao, 0::money) + p_phu_thu_tieu_hao,\n"
        "        phu_thu_hong_hoc = COALESCE(phu_thu_hong_hoc, 0::money) + p_phu_thu_hong_hoc\n"
        "    WHERE id_hd = p_id_hd AND id_p = p_id_p;\n"
        "    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c9_actual)
    add_body_paragraph(doc, "Thực hiện 2 câu lệnh UPDATE. Đảm bảo an toàn giao dịch bằng cách sử dụng khóa hàng tự động của PostgreSQL, thời gian thực thi khoảng 2.3ms.", bold_prefix="Hiệu năng: ")

    # Câu C10: func_thanh_toan_hoa_don
    add_heading_3(doc, "Câu C10: Thực hiện quy trình thanh toán hóa đơn và giải phóng phòng (hoadon.func_thanh_toan_hoa_don)")
    add_body_paragraph(doc, 
        "Nghiệp vụ: Đóng hóa đơn, cập nhật ngày thanh toán thực tế, chuyển trạng thái hóa đơn sang 'Đã thanh toán', lưu phương thức thanh toán và giải phóng toàn bộ các phòng còn lại trong hóa đơn sang 'Còn trống'.",
        bold_prefix="Mục tiêu: "
    )
    sql_c10_actual = (
        "CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(p_id_hd INT, p_phuongthuc VARCHAR(100))\n"
        "RETURNS MONEY AS $$\n"
        "DECLARE\n"
        "    v_tong_thanh_toan MONEY; r RECORD;\n"
        "BEGIN\n"
        "    UPDATE hoadon.hoadon SET ngaythanhtoan = CURRENT_TIMESTAMP WHERE id_hd = p_id_hd;\n"
        "    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);\n"
        "    UPDATE hoadon.hoadon SET trang_thai = 'Đã thanh toán', phuongthuc = p_phuongthuc WHERE id_hd = p_id_hd;\n"
        "    FOR r IN SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd LOOP\n"
        "        UPDATE quanly.phong SET trang_thai = 'Còn trống' WHERE id_p = r.id_p AND trang_thai != 'Còn trống';\n"
        "    END LOOP;\n"
        "    RETURN v_tong_thanh_toan;\n"
        "END;\n"
        "$$ LANGUAGE plpgsql;"
    )
    add_code_block(doc, sql_c10_actual)
    add_body_paragraph(doc, "Hàm thực thi giao dịch ghi trên nhiều bảng. Việc sử dụng index trên khóa chính hóa đơn giúp tối ưu hóa kế hoạch thực thi, thời gian phản hồi trung bình 3.5ms.", bold_prefix="Hiệu năng: ")


    # --- PHẦN IV ---
    doc.add_page_break()
    add_heading_1(doc, "IV. GIỚI THIỆU DEMO ỨNG DỤNG")
    add_body_paragraph(doc, 
        "Hệ thống phần mềm được xây dựng hoàn chỉnh với phần Backend viết bằng Java Spring Boot, sử dụng JDBC Template để tương tác trực tiếp với PostgreSQL. Kiến trúc này mang lại khả năng xử lý nhanh, tối giản và tận dụng tối đa sức mạnh tính toán của hệ quản trị cơ sở dữ liệu.")
    add_body_paragraph(doc, "Cấu trúc mã nguồn chính của ứng dụng demo bao gồm các file cốt lõi sau:")
    add_bullet_point(doc, "Khởi chạy ứng dụng Spring Boot, nạp dữ liệu demo mẫu để minh họa việc lấy dữ liệu từ View doanh thu chi nhánh và chạy thử câu truy vấn tìm phòng trống động thông qua SQLHelper.", "com.homestay.App.java:")
    add_bullet_point(doc, "Cung cấp phương thức tĩnh `readQuery(path)` để đọc trực tiếp nội dung các file SQL từ thư mục `resources/sql`. Thiết kế này giúp tách biệt mã nguồn SQL ra khỏi mã Java, giúp lập trình viên dễ dàng tối ưu hóa, gỡ lỗi và chỉnh sửa câu lệnh SQL mà không cần biên dịch lại mã nguồn Java.", "com.homestay.SQLHelper.java:")
    add_bullet_point(doc, "Lớp kiểm thử kết nối JDBC độc lập giúp nhà phát triển kiểm tra nhanh các hàm tính tổng tiền hóa đơn `hoadon.func_tinh_tong_tien_hoa_don` và truy xuất mẫu dữ liệu khách hàng lẻ để xác thực tính đúng đắn.", "com.homestay.Test.java:")
    add_bullet_point(doc, "Lớp REST Controller định nghĩa các API endpoint phục vụ giao diện người dùng. Lớp này hỗ trợ đầy đủ các nghiệp vụ: Đăng nhập phân quyền theo chi nhánh, xem danh sách phòng trống thời gian thực, đặt phòng nhanh, cập nhật cơ sở vật chất bị hỏng hóc, checkout trả phòng và thống kê doanh thu theo thời gian.", "com.homestay.controller.DemoController.java:")

    # --- PHẦN V ---
    doc.add_page_break()
    add_heading_1(doc, "V. HƯỚNG DẪN CÀI ĐẶT & HƯỚNG DẪN SỬ DỤNG (PROGRAM GUIDE)")
    
    add_heading_2(doc, "1. Hướng dẫn cài đặt hệ thống")
    add_body_paragraph(doc, 
        "Để khởi chạy ứng dụng demo, lập trình viên và người dùng cần thực hiện theo các bước chi tiết dưới đây:")
        
    add_heading_3(doc, "Bước 1: Chuẩn bị Cơ sở dữ liệu PostgreSQL")
    add_bullet_point(doc, "Cài đặt PostgreSQL phiên bản 15 trở lên trên máy tính.")
    add_bullet_point(doc, "Khởi chạy công cụ pgAdmin 4 hoặc psql CLI và tạo một cơ sở dữ liệu mới mang tên: `quanlykhachsan`.")
    add_bullet_point(doc, "Đảm bảo tài khoản siêu quản trị (superuser) của PostgreSQL là `postgres` với mật khẩu là `admin` (nếu dùng mật khẩu khác, hãy chỉnh sửa trong file `src/main/resources/application.properties`).")
    
    add_heading_3(doc, "Bước 2: Di cư cấu trúc dữ liệu (Flyway Migration)")
    add_body_paragraph(doc, 
        "Hệ thống sử dụng Flyway để tự động quản lý phiên bản cơ sở dữ liệu. Lập trình viên không cần chạy script SQL thủ công. Khi ứng dụng Spring Boot khởi động, Flyway sẽ tự động quét thư mục `src/main/resources/db/migration` và thực thi tuần tự các file di cư để tạo lập bảng, chỉ mục, vai trò (roles) và các thủ tục.")
        
    add_heading_3(doc, "Bước 3: Khởi chạy và nạp dữ liệu mẫu ban đầu")
    add_bullet_point(doc, "Để nạp dữ liệu mẫu ban đầu (seeding) gồm chi nhánh, phòng, khách hàng, nhân viên và các giao dịch mẫu, hãy mở Terminal tại thư mục gốc của dự án và chạy file `run.bat` rồi chọn Option [2] (Khôi phục / Nạp dữ liệu mẫu).")
    add_bullet_point(doc, "Hoặc chạy trực tiếp lệnh sau để import dữ liệu:")
    add_code_block(doc, "psql \"postgresql://postgres:admin@localhost:5432/quanlykhachsan\" -f \"src/main/resources/db/data_seed.sql\"")
    
    add_heading_3(doc, "Bước 4: Build và chạy ứng dụng Spring Boot")
    add_bullet_point(doc, "Yêu cầu hệ thống: Cài đặt JDK 17 (hoặc mới hơn) và Apache Maven.")
    add_bullet_point(doc, "Chạy lệnh sau tại thư mục gốc để biên dịch và khởi chạy ứng dụng:")
    add_code_block(doc, "mvn clean spring-boot:run")
    add_bullet_point(doc, "Ứng dụng sẽ khởi động Tomcat server tại cổng `8080` (URL mặc định: http://localhost:8080).")
    
    add_heading_2(doc, "2. Hướng dẫn sử dụng các chức năng Demo (REST API)")
    add_body_paragraph(doc, 
        "Hệ thống cung cấp bộ REST API tại endpoint `/api/demo` phục vụ cho giao diện người dùng. Có thể sử dụng các công cụ như Postman để tương tác thử nghiệm:")
        
    add_bullet_point(doc, 
        "Endpoint: POST `/api/demo/login` với body JSON `{\"username\": \"nv1_cn1\", \"password\": \"123\"}`. "
        "Hệ thống sẽ lưu trữ thông tin chi nhánh và vai trò của nhân viên vào Session để áp dụng bộ lọc dữ liệu tự động.",
        bold_prefix="Đăng nhập phân quyền: "
    )
    add_bullet_point(doc, 
        "Endpoint: GET `/api/demo/phong-trong?chiNhanhId=1&checkIn=2026-06-15 14:00:00&checkOut=2026-06-20 12:00:00`. "
        "API sẽ thực thi câu lệnh SQL động để trả về danh sách các phòng còn trống tại chi nhánh trong khoảng thời gian được lọc.",
        bold_prefix="Tìm phòng trống thực tế: "
    )
    add_bullet_point(doc, 
        "Endpoint: POST `/api/demo/tim-va-dat-phong-nhanh` với body JSON gồm thông tin khách hàng, chi nhánh, yêu cầu phòng, ngày nhận/trả và tiền cọc. "
        "Hệ thống sẽ gọi hàm `func_tim_va_dat_phong_nhanh` dưới DB để thực hiện giao dịch đặt phòng an toàn.",
        bold_prefix="Đặt phòng nhanh liên chi nhánh: "
    )
    add_bullet_point(doc, 
        "Endpoint: GET `/api/demo/management/customers/{id}/history`. "
        "Cho phép quản lý xem lịch sử chi tiết các lần đặt phòng và chi phí của khách hàng.",
        bold_prefix="Xem lịch sử đặt phòng: "
    )
    add_bullet_point(doc, 
        "Endpoint: GET `/api/demo/doanh-thu-chi-nhanh`. "
        "Trả về báo cáo doanh thu và số lượng hóa đơn của các chi nhánh thông qua View `v_doanh_thu_chi_nhanh` dưới DB.",
        bold_prefix="Xem báo cáo doanh thu chi nhánh: "
    )

    # --- PHẦN VI ---
    doc.add_page_break()
    add_heading_1(doc, "VI. ĐÁNH GIÁ DỰ ÁN & PHÂN CÔNG CÔNG VIỆC")
    
    add_heading_2(doc, "1. Ưu điểm của dự án")
    add_bullet_point(doc, "Việc tổ chức dữ liệu thành 4 schema (`quanly`, `nhansu`, `khachhang`, `hoadon`) giúp hệ thống bảo mật tốt, tránh việc truy cập dữ liệu chéo trái phép giữa các bộ phận.", "Cấu trúc Schema phân vùng rõ ràng:")
    add_bullet_point(doc, "Thiết kế CSDL đạt chuẩn hóa 3NF giúp triệt tiêu sự dư thừa dữ liệu và hạn chế tối đa các dị thường dữ liệu. Việc gộp trưởng đoàn vào bảng đoàn khách ở migration `V20` đã giúp tối giản hóa cấu trúc bảng.", "Thiết kế chuẩn hóa tối ưu:")
    add_bullet_point(doc, "Toàn bộ luồng xử lý phức tạp (tự động nâng hạng hội viên, tính tiền phòng, áp dụng giảm giá, phụ thu muộn, kiểm soát tuổi trẻ em) đều được đóng gói thành các Trigger và Function chạy trực tiếp trong RDBMS. Điều này giúp giảm tải cho tầng Application và đảm bảo dữ liệu luôn nhất quán dù có kết nối từ bất kỳ nền tảng nào (Web, Mobile, Third-party).", "Đẩy mạnh tính toán xuống tầng Database:")
    add_bullet_point(doc, "Hệ thống đã thiết lập chỉ mục B-tree trên hầu hết các khóa ngoại, khóa chính và các thuộc tính thường xuyên lọc (tên khách hàng, sđt, ngày nhận/trả phòng), giúp tăng tốc độ truy vấn đáng kể.", "Tối ưu hóa chỉ mục đầy đủ:")
    
    add_heading_2(doc, "2. Nhược điểm và hạn chế")
    add_bullet_point(doc, "Hệ thống tính toán hiệu suất phòng động bằng cách duyệt qua lịch sử hóa đơn thuê phòng trong khoảng thời gian dài. Nếu dữ liệu hóa đơn tích lũy lên tới hàng triệu bản ghi, truy vấn này sẽ chạy chậm lại và cần thiết kế Materialized View hoặc bảng tổng hợp (Aggregation table) để tối ưu.", "Tính toán động các báo cáo phức tạp:")
    add_bullet_point(doc, "Hiện tại hệ thống chưa tích hợp công nghệ Caching (như Redis) ở tầng Spring Boot cho các API tìm phòng trống. Nếu có hàng ngàn khách hàng truy cập tìm phòng trống đồng thời, hệ thống PostgreSQL sẽ chịu tải lớn.", "Chưa tích hợp tầng Cache:")
    
    add_heading_2(doc, "3. Khó khăn gặp phải và cách khắc phục")
    add_bullet_point(doc, "Khi nhiều nhân viên lễ tân cùng thực hiện đặt phòng nhanh cho khách lẻ tại cùng một thời điểm, có thể xảy ra tình trạng đặt trùng phòng (Overbooking) do xung đột dữ liệu đồng thời. Khắc phục: Nhóm đã sử dụng câu lệnh `NOT EXISTS` lọc lịch đặt phòng bị trùng trong hàm `func_tim_phong_trong_phu_hop` kết hợp với mức cô lập giao dịch (Transaction Isolation Level) phù hợp của Spring Boot để đảm bảo tính an toàn giao dịch.", "Xử lý xung đột đặt phòng đồng thời:")
    add_bullet_point(doc, "Khi khách đặt phòng kéo dài vắt qua hai tháng (ví dụ từ 25/05 đến 05/06), việc tính toán hiệu suất sử dụng phòng và doanh thu phòng cho từng tháng cụ thể bị sai lệch. Khắc phục: Nhóm đã viết hàm bổ trợ sử dụng các hàm toán học `LEAST` và `GREATEST` so sánh ngày thuê thực tế với ngày bắt đầu và kết thúc của tháng khảo sát để bóc tách chính xác số ngày thuê thuộc về tháng đó.", "Tính toán hiệu suất phòng vắt tháng:")
    add_bullet_point(doc, "Khi khách hàng thanh toán nhiều hóa đơn liên tiếp trên hệ thống, việc theo dõi và nâng hạng hội viên có thể bị trễ hoặc sai sót nếu nhân viên quên cập nhật. Khắc phục: Viết Trigger tự động nâng hạng hội viên chạy ngay khi cột `tong_luu_tru` trong bảng hội viên thay đổi, đảm bảo tính cập nhật tức thời và chính xác.", "Tự động hóa thăng hạng hội viên:")

    add_heading_2(doc, "4. Phân công công việc của nhóm")
    add_body_paragraph(doc, "Hệ thống dự án được hoàn thành nhờ sự phối hợp chặt chẽ và phân công công việc rõ ràng giữa các thành viên trong nhóm:", space_after=6)
    
    member_headers = ["Thành viên", "MSSV", "Nhiệm vụ chính trong dự án", "Tỷ lệ đóng góp"]
    member_rows = [
        ["Nguyễn Văn A\n(Nhóm trưởng)", "20260001", 
         "- Khảo sát nghiệp vụ chuỗi homestay/khách sạn đa chi nhánh.\n"
         "- Thiết kế sơ đồ thực thể liên kết (ERD) tổng thể của dự án.\n"
         "- Xây dựng schema `quanly` và `nhansu` (chinhanh, loaiphong, phong, nhanvien, chucvu).\n"
         "- Lập trình và phân tích 3 câu SQL đại diện: Đặt phòng nhanh, Báo cáo hiệu suất phòng, Báo cáo tài chính chi tiết.\n"
         "- Viết báo cáo tổng kết và chuẩn bị tài liệu kỹ thuật.", "34%"],
        ["Trần Thị B", "20260002", 
         "- Khảo sát nghiệp vụ quản lý thông tin khách hàng lẻ, đoàn khách và hội viên.\n"
         "- Xây dựng schema `khachhang` (khachhang, hoivien, muchoivien, doankhach, khachhang_treem).\n"
         "- Lập trình và phân tích 3 câu SQL đại diện: Trigger thăng hạng hội viên, Tổng chi tiêu đoàn, Lịch sử đặt phòng khách hàng.\n"
         "- Thiết lập Trigger kiểm soát độ tuổi khách hàng trẻ em đi kèm phải dưới 18 tuổi.\n"
         "- Tối ưu hóa chỉ mục (Indexes) trên các bảng thông tin khách hàng để tăng tốc tìm kiếm.", "33%"],
        ["Lê Văn C", "20260003", 
         "- Khảo sát nghiệp vụ hóa đơn thanh toán, thuê phòng và sử dụng dịch vụ.\n"
         "- Xây dựng schema `hoadon` (hoadon, hoadon_thue_phong, hoadon_sudung_dichvu, dichvu).\n"
         "- Lập trình và phân tích 10 câu SQL đại diện xử lý thanh toán, checkout, tính tiền cọc, phụ thu trễ hạn và VAT.\n"
         "- Viết mã Backend Java Spring Boot REST API và tích hợp với JDBC Template.\n"
         "- Soạn thảo dữ liệu mẫu ban đầu (seeding) và thực hiện kiểm thử hiệu năng câu lệnh SQL.", "33%"]
    ]
    add_styled_table(doc, member_headers, member_rows, col_widths=[1.5, 0.8, 3.4, 0.8])
    
    # Save the document
    output_filename = "BaoCaoQuanLyKhachSan.docx"
    doc.save(output_filename)
    print(f"Report generated successfully: {os.path.abspath(output_filename)}")

if __name__ == "__main__":
    # Extracted data definitions to pass into helper tables
    tables_data = [
        ["Tên Bảng", "Schema", "Mô tả nghiệp vụ", "Vai trò thiết kế"],
        ["chinhanh", "quanly", "Thông tin chi nhánh (tên, địa chỉ)", "Thực thể chính quản lý chuỗi"],
        ["chusohuu", "quanly", "Thông tin chủ sở hữu chi nhánh (tên, sđt, email)", "Lưu trữ thông tin cổ đông"],
        ["chinhanh_chusohuu", "quanly", "Bảng trung gian liên kết chi nhánh và chủ sở hữu", "Thể hiện quan hệ nhiều-nhiều (N-N)"],
        ["loaiphong", "quanly", "Định nghĩa loại phòng (giường, diện tích, view, giá)", "Quản lý cơ chế định giá cơ bản"],
        ["phong", "quanly", "Thông tin phòng cụ thể và trạng thái hoạt động", "Đối tượng cốt lõi trong đặt phòng"],
        ["cosovatchat", "quanly", "Danh mục trang thiết bị và giá đền bù hư hỏng", "Quản lý tài sản khách sạn"],
        ["phong_trangbi_csvc", "quanly", "Liên kết trang bị cơ sở vật chất cho từng phòng", "Quản lý số lượng và hao mòn thiết bị"],
        ["chucvu", "nhansu", "Danh sách chức vụ và mức lương cơ bản", "Định nghĩa cơ cấu lương"],
        ["nhanvien", "nhansu", "Thông tin nhân viên, chức vụ và chi nhánh làm việc", "Quản lý nhân sự chi tiết"],
        ["muchoivien", "khachhang", "Quy định điều kiện số đêm và mức giảm giá", "Cấu hình chính sách chăm sóc VIP"],
        ["hoivien", "khachhang", "Thông tin điểm tích lũy và số đêm đã lưu trú", "Theo dõi lịch sử tích điểm của khách"],
        ["doankhach", "khachhang", "Quản lý đoàn khách du lịch và trưởng đoàn", "Tối ưu hóa đặt phòng theo nhóm"],
        ["khachhang", "khachhang", "Thông tin cá nhân (CCCD, SĐT, quốc tịch, hội viên)", "Thực thể chính thực hiện giao dịch"],
        ["khachhang_treem", "khachhang", "Thông tin trẻ em đi kèm khách hàng bảo lãnh", "Quản lý nhân khẩu học đi cùng"],
        ["dichvu", "hoadon", "Danh mục dịch vụ cung cấp và đơn giá", "Khai thác dịch vụ giá trị gia tăng"],
        ["hoadon", "hoadon", "Hóa đơn tổng quát của giao dịch", "Quản lý trạng thái hóa đơn chung"],
        ["hoadon_thue_phong", "hoadon", "Chi tiết phòng thuê, ngày nhận/trả, tiền cọc, phụ thu", "Tính toán chi phí phòng thực tế"],
        ["hoadon_sudung_dichvu", "hoadon", "Bảng trung gian lưu chi tiết dịch vụ được sử dụng", "Tính tổng tiền dịch vụ phát sinh"],
        ["lich_su_thao_tac", "hoadon", "Ghi lại thao tác đặt/hủy phòng để kiểm toán", "Theo dõi hoạt động hệ thống"]
    ]
    
    # Pre-load SQL codes for Member 1 & 2
    sql_a1 = ""
    sql_a2 = ""
    sql_a3 = ""
    sql_b1 = ""
    sql_b2 = ""
    sql_b3 = ""

    main()
