-- =====================================================================
-- 项目：sql-电商练习
-- 文件：06_客单价与连带率.sql
-- 真实表：fact_order（订单主表，本身就是订单粒度，一行一单，无需再按订单去重）
-- 口径：仅统计 order_status = '已完成' 的成交订单
-- 指标定义：
--   客单价 = 成交总销售额 / 成交订单数     （平均每笔订单花多少钱）
--   连带率 = 商品总件数 / 成交订单数       （平均一单买几件，衡量凑单 / 搭配效果）
-- 注意：fact_order_detail 是订单-商品粒度，做商品维度分析时才使用；
--       订单级金额、件数直接取 fact_order.order_amount / item_count。
-- =====================================================================


-- ---------------------------------------------------------------------
-- 6.1 大盘：整体客单价 + 连带率
-- ---------------------------------------------------------------------
SELECT
    COUNT(order_id) AS 成交订单数,
    ROUND(SUM(order_amount), 2) AS 成交总销售额,
    -- 客单价 = 总销售额 / 订单数
    ROUND(SUM(order_amount) / COUNT(order_id), 2) AS 客单价,
    -- 连带率 = 商品总件数 / 订单数
    ROUND(SUM(item_count) / COUNT(order_id), 2) AS 连带率
FROM fact_order
WHERE order_status = '已完成';

-- 运行结果（真实数据集）：
-- 成交订单数 | 成交总销售额 | 客单价 | 连带率
--    5147    |  2586694.74  | 502.56 |  2.53


-- ---------------------------------------------------------------------
-- 6.2 按月看客单价、连带率趋势（日报 / 月报看板）
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(order_date, '%Y-%m') AS 月份,
    COUNT(order_id) AS 订单数,
    ROUND(SUM(order_amount), 2) AS 月销售额,
    ROUND(SUM(order_amount) / COUNT(order_id), 2) AS 客单价,
    ROUND(SUM(item_count) / COUNT(order_id), 2) AS 连带率
FROM fact_order
WHERE order_status = '已完成'
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY 月份;

-- 运行结果（节选，完整 12 个月在库内执行查看）：
-- 月份   | 订单数 | 月销售额   | 客单价  | 连带率
-- 2025-01 |  435  | 209295.28 | 481.14 |  2.50
-- 2025-08 |  409  | 216482.82 | 529.30 |  2.60
-- 2025-12 |  445  | 228201.30 | 512.81 |  2.50


-- ---------------------------------------------------------------------
-- 6.3 结合明细表：各品类客单结构（商品运营视角，需要关联两张表）
-- ---------------------------------------------------------------------
SELECT
    p.category AS 商品类目,
    COUNT(DISTINCT o.order_id) AS 关联订单数,
    ROUND(SUM(d.detail_amount), 2) AS 品类销售额,
    ROUND(SUM(d.qty), 0) AS 品类销售件数
FROM fact_order o
JOIN fact_order_detail d ON o.order_id = d.order_id
JOIN dim_product p       ON d.product_id = p.product_id
WHERE o.order_status = '已完成'
GROUP BY p.category
ORDER BY 品类销售额 DESC;
