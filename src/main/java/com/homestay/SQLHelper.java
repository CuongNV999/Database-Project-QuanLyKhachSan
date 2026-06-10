package com.homestay;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.stream.Collectors;

public class SQLHelper {
    /**
     * Đọc nội dung tệp SQL từ classpath (thư mục tài nguyên src/main/resources/sql/)
     * @param fileName Tên tệp tin SQL (ví dụ: "tim_phong_trong.sql")
     * @return Chuỗi chứa câu truy vấn SQL
     */
    public static String readQuery(String fileName) throws Exception {
        try (InputStream is = SQLHelper.class.getClassLoader().getResourceAsStream("sql/" + fileName)) {
            if (is == null) {
                throw new IllegalArgumentException("Không tìm thấy tệp SQL: sql/" + fileName);
            }
            try (BufferedReader reader = new BufferedReader(new InputStreamReader(is, "UTF-8"))) {
                return reader.lines().collect(Collectors.joining("\n"));
            }
        }
    }
}
