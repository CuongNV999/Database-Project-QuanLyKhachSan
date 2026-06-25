# 🏨 Hệ thống Quản lý Khách sạn & Homestay (Homestay Management)

Chào mừng bạn đến với dự án **Hệ thống Quản lý Khách sạn & Homestay**. Đây là một ứng dụng Spring Boot kết hợp với cơ sở dữ liệu PostgreSQL mạnh mẽ để quản lý các hoạt động vận hành của khách sạn/homestay, bao gồm quản lý chi nhánh, phòng, khách hàng, nhân sự, hóa đơn dịch vụ và báo cáo doanh thu.

---

## 🛠️ Công nghệ sử dụng
- **Backend:** Java 17, Spring Boot 3.2.5 (Spring Boot Starter Web, Spring Boot Starter JDBC)
- **Database:** PostgreSQL (với thiết lập đa schema: `quanly`, `nhansu`, `khachhang`, `hoadon`)
- **Database Migration:** Flyway 10.x
- **Build Tool:** Apache Maven
- **Frontend:** Giao diện Single Page Application (HTML, CSS/Tailwind, Vanilla JS) được tích hợp trực tiếp tại `src/main/resources/static/index.html`.

---

## 📋 Yêu cầu hệ thống (Prerequisites)
Trước khi cài đặt và chạy dự án, hãy đảm bảo máy tính của bạn đã được cài đặt các công cụ sau:
1. **Java Development Kit (JDK) 17** hoặc mới hơn.
2. **Apache Maven 3.8+** (đã được cấu hình trong biến môi trường `PATH`).
3. **PostgreSQL 15+** (đang chạy ở cổng mặc định `5432`).
4. **Git** để clone mã nguồn.

---

## 🚀 Các bước cài đặt và chạy ứng dụng

### Bước 1: Clone mã nguồn từ GitHub
Mở terminal/command prompt và chạy lệnh sau để tải mã nguồn về máy:
```bash
git clone https://github.com/CuongNV999/Database-Project-QuanLyKhachSan.git
cd Database-Project-QuanLyKhachSan
```

### Bước 2: Thiết lập Cơ sở dữ liệu PostgreSQL
Ứng dụng sử dụng cơ sở dữ liệu PostgreSQL với tên mặc định là `quanlykhachsan`. Do hệ thống sử dụng kiểu dữ liệu `MONEY` để quản lý tiền tệ Việt Nam Đồng (VND), bạn cần cấu hình locale tiền tệ sang `vi-VN`.

1. **Kết nối tới PostgreSQL** bằng tài khoản Superuser (`postgres`) thông qua pgAdmin hoặc công cụ dòng lệnh `psql`.
2. **Tạo Database với cấu hình Locale Việt Nam**:
   - *Nếu hệ điều hành của bạn hỗ trợ locale `vi-VN`:*
     ```sql
     CREATE DATABASE quanlykhachsan
         WITH ENCODING = 'UTF8'
         LC_COLLATE = 'vi-VN'
         LC_CTYPE = 'vi-VN';
     ```
   - *Nếu hệ thống báo lỗi không hỗ trợ locale `vi-VN` (ví dụ trên Windows chưa cài gói ngôn ngữ tương ứng), hãy tạo database mặc định trước:*
     ```sql
     CREATE DATABASE quanlykhachsan;
     ```
3. **Cấu hình định dạng tiền tệ (Bắt buộc)**:
   Kết nối vào database `quanlykhachsan` vừa tạo và chạy lệnh cấu hình định dạng tiền tệ VND:
   ```sql
   ALTER DATABASE quanlykhachsan SET lc_monetary TO 'vi-VN';
   ```

---

### Bước 3: Cấu hình kết nối ứng dụng
Mở file cấu hình dự án tại [application.properties](file:///d:/Database-Project/QuanLyKhachSan/src/main/resources/application.properties) và điều chỉnh lại thông tin đăng nhập PostgreSQL của bạn nếu khác với mặc định:
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/quanlykhachsan
spring.datasource.username=postgres
spring.datasource.password=admin  # Thay đổi mật khẩu PostgreSQL của bạn tại đây
```

---

### Bước 4: Khởi tạo dữ liệu và Chạy ứng dụng

Bạn có thể chạy dự án bằng **công cụ tự động (Khuyên dùng)** hoặc **chạy thủ công bằng lệnh Terminal**.

#### Cách 1: Sử dụng File Tiện ích tự động `run.bat` (Dành cho Windows)
Tại thư mục gốc của dự án, nhấp đúp hoặc chạy file [run.bat](file:///d:/Database-Project/QuanLyKhachSan/run.bat) qua CMD:
```cmd
run.bat
```
Giao diện dòng lệnh sẽ xuất hiện với 3 lựa chọn:
- **Lựa chọn `[1]`**: Biên dịch và chạy ứng dụng Spring Boot. Ở lần đầu chạy, **Flyway** sẽ tự động thực hiện 36 lượt migrations (`V1` đến `V36`) để khởi tạo toàn bộ cấu trúc bảng, views, triggers và functions.
- **Lựa chọn `[2]`**: Nạp dữ liệu mẫu (Import seed data từ file `src/main/resources/db/data_seed.sql` với các dữ liệu phong phú về chi nhánh, phòng, khách hàng, nhân viên, hóa đơn,...). *Lưu ý: Bạn cần có lệnh `psql` trong biến môi trường để tùy chọn này hoạt động.*
- **Lựa chọn `[3]`**: Thoát menu.

#### Cách 2: Chạy thủ công bằng dòng lệnh Terminal
Nếu không sử dụng Windows hoặc muốn chạy thủ công, bạn thực hiện theo các bước sau:

1. **Biên dịch và khởi chạy Spring Boot:**
   ```bash
   mvn spring-boot:run
   ```
   *Lưu ý:* Khi ứng dụng khởi chạy thành công, Flyway sẽ tự động đồng bộ cấu trúc database.
   
2. **Nạp dữ liệu mẫu (Seed Data):**
   Mở một cửa sổ terminal mới và chạy lệnh import dữ liệu mẫu (thay thế mật khẩu `admin` nếu cần):
   ```bash
   psql "postgresql://postgres:admin@localhost:5432/quanlykhachsan" -1 -q -f "src/main/resources/db/data_seed.sql"
   ```

---

### 💡 Cách thiết lập Database độc lập (Không qua Spring Boot/Flyway)
Nếu bạn chỉ muốn tạo cơ sở dữ liệu PostgreSQL để học tập hoặc chạy script độc lập mà không cần khởi động ứng dụng Spring Boot, bạn có thể thực hiện chạy tuần tự 9 file SQL hợp nhất tại thư mục [src/main/resources/db/create/](file:///d:/Database-Project/QuanLyKhachSan/src/main/resources/db/create/):
1. `01_create_database.sql` (Chạy bằng tài khoản superuser postgres)
2. `02_create_tables.sql` (Từ bước này, hãy kết nối vào database `quanlykhachsan` vừa tạo)
3. `03_create_indexes.sql`
4. `04_create_foreign_keys.sql`
5. `05_create_views.sql`
6. `06_create_functions.sql`
7. `07_create_triggers.sql`
8. `08_create_roles.sql`
9. `09_seed_data.sql`

---

## 🖥️ Trải nghiệm giao diện Web
Sau khi ứng dụng Spring Boot đã khởi chạy thành công (cổng mặc định `8080`), bạn hãy mở trình duyệt web và truy cập vào địa chỉ:
```
http://localhost:8080/index.html
```

Tại đây, bạn sẽ có thể tương tác trực tiếp với hệ thống quản lý qua giao diện trực quan, bao gồm:
- Xem danh sách chi nhánh, quản lý phòng và tình trạng phòng trống.
- Đăng ký hội viên và quản lý thông tin khách hàng.
- Tạo hóa đơn, thêm dịch vụ sử dụng và thực hiện thanh toán tự động tính toán phụ thu / giảm giá hội viên.
- Xem báo cáo doanh thu và hiệu suất phòng bằng các biểu đồ thống kê.

---

## 📂 Cấu trúc thư mục dự án quan trọng
- `src/main/java/com/homestay/App.java`: File khởi chạy chính của dự án Spring Boot, chứa đoạn code demo truy vấn dữ liệu mẫu khi start-up.
- `src/main/java/com/homestay/controller/DemoController.java`: Nơi xử lý toàn bộ các API Endpoints giao tiếp giữa giao diện Web Frontend và Database.
- `src/main/resources/static/index.html`: Mã nguồn của giao diện web SPA.
- `src/main/resources/db/migration/`: Chứa 36 tệp migration của Flyway lưu vết lịch sử thay đổi Database.
- `src/main/resources/db/create/`: Chứa 9 file SQL hợp nhất cấu trúc database ở trạng thái mới nhất.
- `src/main/resources/db/data_seed.sql`: File chứa script nạp lượng lớn dữ liệu giả lập chất lượng cao.
