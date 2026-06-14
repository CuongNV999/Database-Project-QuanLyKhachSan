--
-- PostgreSQL database dump
--

-- \restrict HHz1HGOYESpwPy9ss7Ds8UdAX3y18htdBXblNtav2ZMpJzg6Zhu5Sp7qoeEG2Ut

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: chinhanh; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chinhanh (
    id_cn integer NOT NULL,
    ten_cn character varying(255) NOT NULL,
    dia_chi text
);


ALTER TABLE public.chinhanh OWNER TO postgres;

--
-- Name: chinhanh_chusohuu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chinhanh_chusohuu (
    id_cn integer NOT NULL,
    id_csh integer NOT NULL
);


ALTER TABLE public.chinhanh_chusohuu OWNER TO postgres;

--
-- Name: chinhanh_id_cn_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chinhanh_id_cn_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chinhanh_id_cn_seq OWNER TO postgres;

--
-- Name: chinhanh_id_cn_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chinhanh_id_cn_seq OWNED BY public.chinhanh.id_cn;


--
-- Name: chucvu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chucvu (
    chuc_vu character varying(100) NOT NULL,
    luong numeric(15,2),
    CONSTRAINT chucvu_luong_check CHECK ((luong >= (0)::numeric))
);


ALTER TABLE public.chucvu OWNER TO postgres;

--
-- Name: chusohuu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.chusohuu (
    id_csh integer NOT NULL,
    ten_csh character varying(255) NOT NULL,
    email character varying(255),
    sdt character varying(20)
);


ALTER TABLE public.chusohuu OWNER TO postgres;

--
-- Name: chusohuu_id_csh_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.chusohuu_id_csh_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.chusohuu_id_csh_seq OWNER TO postgres;

--
-- Name: chusohuu_id_csh_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.chusohuu_id_csh_seq OWNED BY public.chusohuu.id_csh;


--
-- Name: cosovatchat; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cosovatchat (
    id_csvc integer NOT NULL,
    ten_csvc character varying(255) NOT NULL,
    mo_ta text,
    loai_csvc character varying(50),
    gia_den_bu numeric(15,2) DEFAULT 0
);


ALTER TABLE public.cosovatchat OWNER TO postgres;

--
-- Name: cosovatchat_id_csvc_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cosovatchat_id_csvc_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cosovatchat_id_csvc_seq OWNER TO postgres;

--
-- Name: cosovatchat_id_csvc_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cosovatchat_id_csvc_seq OWNED BY public.cosovatchat.id_csvc;


--
-- Name: dichvu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dichvu (
    id_dv integer NOT NULL,
    ten_dv character varying(255) NOT NULL,
    gia numeric(15,2),
    loai_dv character varying(100),
    CONSTRAINT dichvu_gia_check CHECK ((gia >= (0)::numeric))
);


ALTER TABLE public.dichvu OWNER TO postgres;

--
-- Name: dichvu_id_dv_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dichvu_id_dv_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dichvu_id_dv_seq OWNER TO postgres;

--
-- Name: dichvu_id_dv_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dichvu_id_dv_seq OWNED BY public.dichvu.id_dv;


--
-- Name: doankhach; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.doankhach (
    id_doan integer NOT NULL,
    so_thanh_vien integer,
    CONSTRAINT doankhach_so_thanh_vien_check CHECK ((so_thanh_vien > 0))
);


ALTER TABLE public.doankhach OWNER TO postgres;

--
-- Name: doankhach_id_doan_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.doankhach_id_doan_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.doankhach_id_doan_seq OWNER TO postgres;

--
-- Name: doankhach_id_doan_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.doankhach_id_doan_seq OWNED BY public.doankhach.id_doan;


--
-- Name: hanghoivien; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hanghoivien (
    hang character varying(50) NOT NULL,
    dieu_kien text,
    muc_giam_gia numeric(5,2),
    CONSTRAINT hanghoivien_muc_giam_gia_check CHECK (((muc_giam_gia >= (0)::numeric) AND (muc_giam_gia <= (100)::numeric)))
);


ALTER TABLE public.hanghoivien OWNER TO postgres;

--
-- Name: hoadon; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hoadon (
    id_hd integer NOT NULL,
    trang_thai character varying(100),
    ngaylap date DEFAULT CURRENT_DATE,
    ngaythanhtoan date,
    phuongthuc character varying(100),
    id_kh integer,
    id_nv integer
);


ALTER TABLE public.hoadon OWNER TO postgres;

--
-- Name: hoadon_id_hd_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.hoadon_id_hd_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.hoadon_id_hd_seq OWNER TO postgres;

--
-- Name: hoadon_id_hd_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.hoadon_id_hd_seq OWNED BY public.hoadon.id_hd;


--
-- Name: hoadon_sudung_dichvu; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hoadon_sudung_dichvu (
    id_hd integer NOT NULL,
    id_dv integer NOT NULL,
    so_luong integer,
    CONSTRAINT hoadon_sudung_dichvu_so_luong_check CHECK ((so_luong > 0))
);


ALTER TABLE public.hoadon_sudung_dichvu OWNER TO postgres;

--
-- Name: hoadon_thue_phong; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hoadon_thue_phong (
    id_hd integer NOT NULL,
    id_p integer NOT NULL,
    so_luong integer,
    ngaynhan timestamp without time zone,
    ngaytra timestamp without time zone,
    ma_phien character varying(50),
    tien_coc numeric(15,2) DEFAULT 0,
    phu_thu numeric(15,2) DEFAULT 0,
    tong_tien numeric(15,2) DEFAULT 0,
    CONSTRAINT hoadon_thue_phong_so_luong_check CHECK ((so_luong > 0))
);


ALTER TABLE public.hoadon_thue_phong OWNER TO postgres;

--
-- Name: hoivien; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hoivien (
    id_hv integer NOT NULL,
    hang character varying(50),
    id_cn integer,
    diem_tich_luy integer DEFAULT 0
);


ALTER TABLE public.hoivien OWNER TO postgres;

--
-- Name: hoivien_id_hv_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.hoivien_id_hv_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.hoivien_id_hv_seq OWNER TO postgres;

--
-- Name: hoivien_id_hv_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.hoivien_id_hv_seq OWNED BY public.hoivien.id_hv;


--
-- Name: khachhang; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.khachhang (
    id_kh integer NOT NULL,
    cccd character varying(20),
    dia_chi text,
    ho_ten character varying(255) NOT NULL,
    sdt character varying(20),
    quoc_tich character varying(100),
    passport character varying(50),
    visa character varying(50),
    id_hv integer,
    id_doan integer
);


ALTER TABLE public.khachhang OWNER TO postgres;

--
-- Name: khachhang_id_kh_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.khachhang_id_kh_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.khachhang_id_kh_seq OWNER TO postgres;

--
-- Name: khachhang_id_kh_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.khachhang_id_kh_seq OWNED BY public.khachhang.id_kh;


--
-- Name: khachhang_treem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.khachhang_treem (
    id_kh integer NOT NULL,
    id_tre_em integer NOT NULL,
    ten_tre_em character varying(255) NOT NULL,
    tuoi integer,
    CONSTRAINT khachhang_treem_tuoi_check CHECK ((tuoi >= 0))
);


ALTER TABLE public.khachhang_treem OWNER TO postgres;

--
-- Name: khachhang_treem_id_tre_em_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.khachhang_treem_id_tre_em_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.khachhang_treem_id_tre_em_seq OWNER TO postgres;

--
-- Name: khachhang_treem_id_tre_em_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.khachhang_treem_id_tre_em_seq OWNED BY public.khachhang_treem.id_tre_em;


--
-- Name: loaiphong; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loaiphong (
    id_lp integer NOT NULL,
    chat_luong character varying(100),
    loai_giuong character varying(50),
    view character varying(100),
    dien_tich character varying(50),
    doi_tuong character varying(100),
    gia_tien numeric(15,2),
    id_cn integer
);


ALTER TABLE public.loaiphong OWNER TO postgres;

--
-- Name: loaiphong_id_lp_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loaiphong_id_lp_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loaiphong_id_lp_seq OWNER TO postgres;

--
-- Name: loaiphong_id_lp_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loaiphong_id_lp_seq OWNED BY public.loaiphong.id_lp;


--
-- Name: nhanvien; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.nhanvien (
    id_nv integer NOT NULL,
    ten_nv character varying(255) NOT NULL,
    chuc_vu character varying(100),
    id_cn integer
);


ALTER TABLE public.nhanvien OWNER TO postgres;

--
-- Name: nhanvien_id_nv_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.nhanvien_id_nv_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.nhanvien_id_nv_seq OWNER TO postgres;

--
-- Name: nhanvien_id_nv_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.nhanvien_id_nv_seq OWNED BY public.nhanvien.id_nv;


--
-- Name: phong; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.phong (
    id_p integer NOT NULL,
    dia_chi text,
    trang_thai character varying(100),
    id_lp integer
);


ALTER TABLE public.phong OWNER TO postgres;

--
-- Name: phong_id_p_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.phong_id_p_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.phong_id_p_seq OWNER TO postgres;

--
-- Name: phong_id_p_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.phong_id_p_seq OWNED BY public.phong.id_p;


--
-- Name: phong_trangbi_csvc; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.phong_trangbi_csvc (
    id_p integer NOT NULL,
    id_csvc integer NOT NULL,
    so_luong integer,
    tinh_trang character varying(255),
    CONSTRAINT phong_trangbi_csvc_so_luong_check CHECK ((so_luong >= 0))
);


ALTER TABLE public.phong_trangbi_csvc OWNER TO postgres;

--
-- Name: truongdoan; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.truongdoan (
    id_doan integer NOT NULL,
    id_kh integer
);


ALTER TABLE public.truongdoan OWNER TO postgres;

--
-- Name: chinhanh id_cn; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chinhanh ALTER COLUMN id_cn SET DEFAULT nextval('public.chinhanh_id_cn_seq'::regclass);


--
-- Name: chusohuu id_csh; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chusohuu ALTER COLUMN id_csh SET DEFAULT nextval('public.chusohuu_id_csh_seq'::regclass);


--
-- Name: cosovatchat id_csvc; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cosovatchat ALTER COLUMN id_csvc SET DEFAULT nextval('public.cosovatchat_id_csvc_seq'::regclass);


--
-- Name: dichvu id_dv; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dichvu ALTER COLUMN id_dv SET DEFAULT nextval('public.dichvu_id_dv_seq'::regclass);


--
-- Name: doankhach id_doan; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doankhach ALTER COLUMN id_doan SET DEFAULT nextval('public.doankhach_id_doan_seq'::regclass);


--
-- Name: hoadon id_hd; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon ALTER COLUMN id_hd SET DEFAULT nextval('public.hoadon_id_hd_seq'::regclass);


--
-- Name: hoivien id_hv; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoivien ALTER COLUMN id_hv SET DEFAULT nextval('public.hoivien_id_hv_seq'::regclass);


--
-- Name: khachhang id_kh; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang ALTER COLUMN id_kh SET DEFAULT nextval('public.khachhang_id_kh_seq'::regclass);


--
-- Name: khachhang_treem id_tre_em; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang_treem ALTER COLUMN id_tre_em SET DEFAULT nextval('public.khachhang_treem_id_tre_em_seq'::regclass);


--
-- Name: loaiphong id_lp; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loaiphong ALTER COLUMN id_lp SET DEFAULT nextval('public.loaiphong_id_lp_seq'::regclass);


--
-- Name: nhanvien id_nv; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nhanvien ALTER COLUMN id_nv SET DEFAULT nextval('public.nhanvien_id_nv_seq'::regclass);


--
-- Name: phong id_p; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.phong ALTER COLUMN id_p SET DEFAULT nextval('public.phong_id_p_seq'::regclass);


--
-- Name: chinhanh_chusohuu chinhanh_chusohuu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chinhanh_chusohuu
    ADD CONSTRAINT chinhanh_chusohuu_pkey PRIMARY KEY (id_cn, id_csh);


--
-- Name: chinhanh chinhanh_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chinhanh
    ADD CONSTRAINT chinhanh_pkey PRIMARY KEY (id_cn);


--
-- Name: chucvu chucvu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chucvu
    ADD CONSTRAINT chucvu_pkey PRIMARY KEY (chuc_vu);


--
-- Name: chusohuu chusohuu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chusohuu
    ADD CONSTRAINT chusohuu_pkey PRIMARY KEY (id_csh);


--
-- Name: cosovatchat cosovatchat_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cosovatchat
    ADD CONSTRAINT cosovatchat_pkey PRIMARY KEY (id_csvc);


--
-- Name: dichvu dichvu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dichvu
    ADD CONSTRAINT dichvu_pkey PRIMARY KEY (id_dv);


--
-- Name: doankhach doankhach_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.doankhach
    ADD CONSTRAINT doankhach_pkey PRIMARY KEY (id_doan);


--
-- Name: hanghoivien hanghoivien_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hanghoivien
    ADD CONSTRAINT hanghoivien_pkey PRIMARY KEY (hang);


--
-- Name: hoadon hoadon_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon
    ADD CONSTRAINT hoadon_pkey PRIMARY KEY (id_hd);


--
-- Name: hoadon_sudung_dichvu hoadon_sudung_dichvu_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_sudung_dichvu
    ADD CONSTRAINT hoadon_sudung_dichvu_pkey PRIMARY KEY (id_hd, id_dv);


--
-- Name: hoadon_thue_phong hoadon_thue_phong_ma_phien_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_thue_phong
    ADD CONSTRAINT hoadon_thue_phong_ma_phien_key UNIQUE (ma_phien);


--
-- Name: hoadon_thue_phong hoadon_thue_phong_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_thue_phong
    ADD CONSTRAINT hoadon_thue_phong_pkey PRIMARY KEY (id_hd, id_p);


--
-- Name: hoivien hoivien_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoivien
    ADD CONSTRAINT hoivien_pkey PRIMARY KEY (id_hv);


--
-- Name: khachhang khachhang_cccd_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang
    ADD CONSTRAINT khachhang_cccd_key UNIQUE (cccd);


--
-- Name: khachhang khachhang_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang
    ADD CONSTRAINT khachhang_pkey PRIMARY KEY (id_kh);


--
-- Name: khachhang_treem khachhang_treem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang_treem
    ADD CONSTRAINT khachhang_treem_pkey PRIMARY KEY (id_kh, id_tre_em);


--
-- Name: loaiphong loaiphong_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loaiphong
    ADD CONSTRAINT loaiphong_pkey PRIMARY KEY (id_lp);


--
-- Name: nhanvien nhanvien_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nhanvien
    ADD CONSTRAINT nhanvien_pkey PRIMARY KEY (id_nv);


--
-- Name: phong phong_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.phong
    ADD CONSTRAINT phong_pkey PRIMARY KEY (id_p);


--
-- Name: phong_trangbi_csvc phong_trangbi_csvc_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.phong_trangbi_csvc
    ADD CONSTRAINT phong_trangbi_csvc_pkey PRIMARY KEY (id_p, id_csvc);


--
-- Name: truongdoan truongdoan_id_kh_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.truongdoan
    ADD CONSTRAINT truongdoan_id_kh_key UNIQUE (id_kh);


--
-- Name: truongdoan truongdoan_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.truongdoan
    ADD CONSTRAINT truongdoan_pkey PRIMARY KEY (id_doan);


--
-- Name: idx_cn_csh_id_csh; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cn_csh_id_csh ON public.chinhanh_chusohuu USING btree (id_csh);


--
-- Name: idx_hd_sd_dv_id_dv; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hd_sd_dv_id_dv ON public.hoadon_sudung_dichvu USING btree (id_dv);


--
-- Name: idx_hd_thue_phong_id_p; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hd_thue_phong_id_p ON public.hoadon_thue_phong USING btree (id_p);


--
-- Name: idx_hoadon_id_kh; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hoadon_id_kh ON public.hoadon USING btree (id_kh);


--
-- Name: idx_hoadon_id_nv; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hoadon_id_nv ON public.hoadon USING btree (id_nv);


--
-- Name: idx_hoadon_ngay_lap; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hoadon_ngay_lap ON public.hoadon USING btree (ngaylap);


--
-- Name: idx_hoivien_hang; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hoivien_hang ON public.hoivien USING btree (hang);


--
-- Name: idx_hoivien_id_cn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_hoivien_id_cn ON public.hoivien USING btree (id_cn);


--
-- Name: idx_khachhang_hoten; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_khachhang_hoten ON public.khachhang USING btree (ho_ten);


--
-- Name: idx_khachhang_id_doan; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_khachhang_id_doan ON public.khachhang USING btree (id_doan);


--
-- Name: idx_khachhang_id_hv; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_khachhang_id_hv ON public.khachhang USING btree (id_hv);


--
-- Name: idx_khachhang_sdt; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_khachhang_sdt ON public.khachhang USING btree (sdt);


--
-- Name: idx_nhanvien_chuc_vu; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nhanvien_chuc_vu ON public.nhanvien USING btree (chuc_vu);


--
-- Name: idx_nhanvien_id_cn; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_nhanvien_id_cn ON public.nhanvien USING btree (id_cn);


--
-- Name: idx_phong_csvc_id_csvc; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_phong_csvc_id_csvc ON public.phong_trangbi_csvc USING btree (id_csvc);


--
-- Name: idx_phong_id_lp; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_phong_id_lp ON public.phong USING btree (id_lp);


--
-- Name: idx_phong_trang_thai; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_phong_trang_thai ON public.phong USING btree (trang_thai);


--
-- Name: chinhanh_chusohuu chinhanh_chusohuu_id_cn_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chinhanh_chusohuu
    ADD CONSTRAINT chinhanh_chusohuu_id_cn_fkey FOREIGN KEY (id_cn) REFERENCES public.chinhanh(id_cn) ON DELETE CASCADE;


--
-- Name: chinhanh_chusohuu chinhanh_chusohuu_id_csh_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.chinhanh_chusohuu
    ADD CONSTRAINT chinhanh_chusohuu_id_csh_fkey FOREIGN KEY (id_csh) REFERENCES public.chusohuu(id_csh) ON DELETE CASCADE;


--
-- Name: hoadon hoadon_id_kh_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon
    ADD CONSTRAINT hoadon_id_kh_fkey FOREIGN KEY (id_kh) REFERENCES public.khachhang(id_kh) ON DELETE SET NULL;


--
-- Name: hoadon hoadon_id_nv_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon
    ADD CONSTRAINT hoadon_id_nv_fkey FOREIGN KEY (id_nv) REFERENCES public.nhanvien(id_nv) ON DELETE SET NULL;


--
-- Name: hoadon_sudung_dichvu hoadon_sudung_dichvu_id_dv_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_sudung_dichvu
    ADD CONSTRAINT hoadon_sudung_dichvu_id_dv_fkey FOREIGN KEY (id_dv) REFERENCES public.dichvu(id_dv) ON DELETE CASCADE;


--
-- Name: hoadon_sudung_dichvu hoadon_sudung_dichvu_id_hd_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_sudung_dichvu
    ADD CONSTRAINT hoadon_sudung_dichvu_id_hd_fkey FOREIGN KEY (id_hd) REFERENCES public.hoadon(id_hd) ON DELETE CASCADE;


--
-- Name: hoadon_thue_phong hoadon_thue_phong_id_hd_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_thue_phong
    ADD CONSTRAINT hoadon_thue_phong_id_hd_fkey FOREIGN KEY (id_hd) REFERENCES public.hoadon(id_hd) ON DELETE CASCADE;


--
-- Name: hoadon_thue_phong hoadon_thue_phong_id_p_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoadon_thue_phong
    ADD CONSTRAINT hoadon_thue_phong_id_p_fkey FOREIGN KEY (id_p) REFERENCES public.phong(id_p) ON DELETE CASCADE;


--
-- Name: hoivien hoivien_hang_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoivien
    ADD CONSTRAINT hoivien_hang_fkey FOREIGN KEY (hang) REFERENCES public.hanghoivien(hang) ON DELETE SET NULL;


--
-- Name: hoivien hoivien_id_cn_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hoivien
    ADD CONSTRAINT hoivien_id_cn_fkey FOREIGN KEY (id_cn) REFERENCES public.chinhanh(id_cn) ON DELETE CASCADE;


--
-- Name: khachhang khachhang_id_doan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang
    ADD CONSTRAINT khachhang_id_doan_fkey FOREIGN KEY (id_doan) REFERENCES public.doankhach(id_doan) ON DELETE SET NULL;


--
-- Name: khachhang khachhang_id_hv_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang
    ADD CONSTRAINT khachhang_id_hv_fkey FOREIGN KEY (id_hv) REFERENCES public.hoivien(id_hv) ON DELETE SET NULL;


--
-- Name: khachhang_treem khachhang_treem_id_kh_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.khachhang_treem
    ADD CONSTRAINT khachhang_treem_id_kh_fkey FOREIGN KEY (id_kh) REFERENCES public.khachhang(id_kh) ON DELETE CASCADE;


--
-- Name: loaiphong loaiphong_id_cn_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loaiphong
    ADD CONSTRAINT loaiphong_id_cn_fkey FOREIGN KEY (id_cn) REFERENCES public.chinhanh(id_cn) ON DELETE CASCADE;


--
-- Name: nhanvien nhanvien_chuc_vu_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nhanvien
    ADD CONSTRAINT nhanvien_chuc_vu_fkey FOREIGN KEY (chuc_vu) REFERENCES public.chucvu(chuc_vu) ON DELETE SET NULL;


--
-- Name: nhanvien nhanvien_id_cn_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.nhanvien
    ADD CONSTRAINT nhanvien_id_cn_fkey FOREIGN KEY (id_cn) REFERENCES public.chinhanh(id_cn) ON DELETE CASCADE;


--
-- Name: phong phong_id_lp_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.phong
    ADD CONSTRAINT phong_id_lp_fkey FOREIGN KEY (id_lp) REFERENCES public.loaiphong(id_lp) ON DELETE SET NULL;


--
-- Name: phong_trangbi_csvc phong_trangbi_csvc_id_csvc_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.phong_trangbi_csvc
    ADD CONSTRAINT phong_trangbi_csvc_id_csvc_fkey FOREIGN KEY (id_csvc) REFERENCES public.cosovatchat(id_csvc) ON DELETE CASCADE;


--
-- Name: phong_trangbi_csvc phong_trangbi_csvc_id_p_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.phong_trangbi_csvc
    ADD CONSTRAINT phong_trangbi_csvc_id_p_fkey FOREIGN KEY (id_p) REFERENCES public.phong(id_p) ON DELETE CASCADE;


--
-- Name: truongdoan truongdoan_id_doan_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.truongdoan
    ADD CONSTRAINT truongdoan_id_doan_fkey FOREIGN KEY (id_doan) REFERENCES public.doankhach(id_doan) ON DELETE CASCADE;


--
-- Name: truongdoan truongdoan_id_kh_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.truongdoan
    ADD CONSTRAINT truongdoan_id_kh_fkey FOREIGN KEY (id_kh) REFERENCES public.khachhang(id_kh) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict HHz1HGOYESpwPy9ss7Ds8UdAX3y18htdBXblNtav2ZMpJzg6Zhu5Sp7qoeEG2Ut

