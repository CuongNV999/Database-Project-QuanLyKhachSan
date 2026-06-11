package com.homestay.controller;

import com.homestay.SQLHelper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.sql.Timestamp;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/demo")
public class DemoController {

    private final JdbcTemplate jdbcTemplate;

    @Autowired
    public DemoController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/doanh-thu-chi-nhanh")
    public List<Map<String, Object>> getDoanhThuChiNhanh() {
        String sql = "SELECT * FROM v_doanh_thu_chi_nhanh";
        return jdbcTemplate.queryForList(sql);
    }

    @GetMapping("/phong-trong")
    public List<Map<String, Object>> getPhongTrong(
            @RequestParam(defaultValue = "1") int chiNhanhId,
            @RequestParam(defaultValue = "2026-06-15 14:00:00") String checkIn,
            @RequestParam(defaultValue = "2026-06-20 12:00:00") String checkOut) throws Exception {
        
        String timPhongSql = SQLHelper.readQuery("quanly/tim_phong_trong.sql");
        return jdbcTemplate.queryForList(
                timPhongSql,
                chiNhanhId,
                Timestamp.valueOf(checkOut),
                Timestamp.valueOf(checkIn)
        );
    }
}
