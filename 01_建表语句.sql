-- =====================================================================
-- 项目：sql-电商练习
-- 文件：01_建表语句.sql
-- 说明：本项目配套真实数据集（见 ./原始数据 文件夹，6 张 CSV / 1 个 Excel 工作簿）
--       先执行本文件建表，再按 02_数据导入说明.md 把 CSV 导入对应表。
-- 环境：MySQL 5.7 / 8.0 通用语法，DBeaver 直接运行。
-- 数据周期：2025-01-01 ~ 2025-12-31
-- =====================================================================

-- 按被依赖顺序反向删表，方便重复建表
DROP TABLE IF EXISTS fact_refund;
DROP TABLE IF EXISTS fact_order_detail;
DROP TABLE IF EXISTS fact_order;
DROP TABLE IF EXISTS fact_traffic;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_user;

-- 1. 用户维度表（1200 行）
CREATE TABLE dim_user (
    user_id      VARCHAR(20) PRIMARY KEY COMMENT '用户唯一ID',
    gender       VARCHAR(4)  COMMENT '性别：男 / 女',
    age          INT         COMMENT '年龄',
    city         VARCHAR(20) COMMENT '所在城市',
    reg_channel  VARCHAR(20) COMMENT '注册渠道',
    member_level VARCHAR(10) COMMENT '会员等级：普通 / 银卡 / 金卡 / 钻石',
    reg_date     DATE        COMMENT '注册日期'
) COMMENT='用户维度表';

-- 2. 商品维度表（180 行）
CREATE TABLE dim_product (
    product_id   VARCHAR(20) PRIMARY KEY COMMENT '商品唯一ID',
    category     VARCHAR(20) COMMENT '商品类目',
    product_name VARCHAR(50) COMMENT '商品名称',
    cost_price   DECIMAL(10,2) COMMENT '成本价',
    sale_price   DECIMAL(10,2) COMMENT '销售价',
    is_on_sale   VARCHAR(10) COMMENT '在售状态：在售 / 下架'
) COMMENT='商品维度表';

-- 3. 流量事实表（9000 行，一行 = 一次访问会话）
CREATE TABLE fact_traffic (
    visit_id          VARCHAR(20) PRIMARY KEY COMMENT '访问会话ID',
    user_id           VARCHAR(20) COMMENT '用户ID（关联 dim_user.user_id）',
    visit_time        DATETIME   COMMENT '访问时间',
    visit_date        DATE       COMMENT '访问日期',
    traffic_source    VARCHAR(20) COMMENT '流量渠道：自然搜索/抖音短视频/直播间/直通车/朋友圈广告/老客推荐',
    landing_page      VARCHAR(20) COMMENT '落地页类型',
    is_convert        TINYINT    COMMENT '本次访问是否转化：1=是，0=否',
    visit_duration_sec INT        COMMENT '访问停留时长（秒）'
) COMMENT='流量访问事实表';

-- 4. 订单主表（5956 行，一行 = 一个订单，订单粒度）
CREATE TABLE fact_order (
    order_id      VARCHAR(20) PRIMARY KEY COMMENT '订单编号',
    user_id       VARCHAR(20) COMMENT '下单用户ID（关联 dim_user.user_id）',
    order_date    DATE        COMMENT '下单日期',
    order_time    DATETIME    COMMENT '下单时间',
    order_amount  DECIMAL(10,2) COMMENT '订单实付总额',
    item_count    INT         COMMENT '订单商品总件数',
    order_status  VARCHAR(10) COMMENT '订单状态：已完成 / 已取消 / 待发货',
    pay_method    VARCHAR(10) COMMENT '支付方式',
    province      VARCHAR(10) COMMENT '收货省份'
) COMMENT='订单主表（订单粒度）';

-- 5. 订单明细表（6000 行，一行 = 订单中的一件商品，订单-商品粒度）
CREATE TABLE fact_order_detail (
    detail_id    VARCHAR(20) PRIMARY KEY COMMENT '明细行ID',
    order_id     VARCHAR(20) COMMENT '订单编号（关联 fact_order.order_id）',
    product_id   VARCHAR(20) COMMENT '商品ID（关联 dim_product.product_id）',
    user_id      VARCHAR(20) COMMENT '用户ID',
    order_time   DATETIME    COMMENT '下单时间',
    qty          INT         COMMENT '购买数量',
    unit_price   DECIMAL(10,2) COMMENT '商品单价',
    discount_rate DECIMAL(4,2) COMMENT '折扣率',
    detail_amount DECIMAL(10,2) COMMENT '本明细行金额'
) COMMENT='订单明细事实表（订单-商品粒度）';

-- 6. 退款事实表（350 行）
CREATE TABLE fact_refund (
    refund_id     VARCHAR(20) PRIMARY KEY COMMENT '退款单ID',
    order_id      VARCHAR(20) COMMENT '关联订单编号（关联 fact_order.order_id）',
    user_id       VARCHAR(20) COMMENT '退款用户ID',
    refund_date   DATE        COMMENT '退款日期',
    refund_reason VARCHAR(20) COMMENT '退款原因',
    refund_amount DECIMAL(10,2) COMMENT '退款金额',
    refund_status VARCHAR(10) COMMENT '退款状态：退款成功 / 退款审核中'
) COMMENT='退款事实表';

-- 常用索引（数据量上来后加速关联与分组）
CREATE INDEX idx_traffic_user ON fact_traffic(user_id);
CREATE INDEX idx_traffic_date ON fact_traffic(visit_date);
CREATE INDEX idx_order_user   ON fact_order(user_id);
CREATE INDEX idx_order_date   ON fact_order(order_date);
CREATE INDEX idx_detail_order ON fact_order_detail(order_id);
CREATE INDEX idx_detail_prod  ON fact_order_detail(product_id);
CREATE INDEX idx_refund_order ON fact_refund(order_id);
