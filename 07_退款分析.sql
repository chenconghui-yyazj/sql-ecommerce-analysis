-- =====================================================================
-- 项目：sql-电商练习
-- 文件：07_退款分析.sql
-- 真实表：fact_order（订单主表）、fact_refund（退款表）、fact_order_detail、dim_product
-- 口径：
--   成交分母 = order_status = '已完成' 的订单；
--   退款分子 = refund_status = '退款成功' 的退款单（退款审核中不计入）；
--   订单退款率 = 退款成功订单数 / 成交订单数（运营 / 售后看）
--   金额退款率 = 退款成功金额 / 成交总销售额（财务 / 风控看）
-- 核心：订单表 LEFT JOIN 退款表，保证全部成交订单进入分母；退款订单用 DISTINCT 去重。
-- =====================================================================


-- ---------------------------------------------------------------------
-- 7.1 大盘退款率：订单口径 + 金额口径
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT o.order_id) AS 成交订单数,
    COUNT(DISTINCT r.order_id) AS 退款订单数,
    ROUND(COUNT(DISTINCT r.order_id) / COUNT(DISTINCT o.order_id), 3) AS 订单退款率,
    ROUND(SUM(o.order_amount), 2) AS 成交总销售额,
    IFNULL(SUM(r.refund_amount), 0) AS 退款总金额,
    ROUND(IFNULL(SUM(r.refund_amount), 0) / SUM(o.order_amount), 3) AS 金额退款率
FROM fact_order o
LEFT JOIN fact_refund r
    ON o.order_id = r.order_id
   AND r.refund_status = '退款成功'
WHERE o.order_status = '已完成';

-- 运行结果（真实数据集）：
-- 成交订单数 | 退款订单数 | 订单退款率 | 成交总销售额 | 退款总金额 | 金额退款率
--    5147    |    312    |   0.061    |  2586694.74  | 106435.37  |   0.041


-- ---------------------------------------------------------------------
-- 7.2 按月监控退款趋势（发现退款率异动及时归因）
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS 月份,
    COUNT(DISTINCT o.order_id) AS 成交订单数,
    COUNT(DISTINCT r.order_id) AS 退款订单数,
    ROUND(COUNT(DISTINCT r.order_id) / COUNT(DISTINCT o.order_id), 3) AS 订单退款率
FROM fact_order o
LEFT JOIN fact_refund r
    ON o.order_id = r.order_id
   AND r.refund_status = '退款成功'
WHERE o.order_status = '已完成'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY 月份;


-- ---------------------------------------------------------------------
-- 7.3 退款原因结构（定位售后主要问题类型）
-- ---------------------------------------------------------------------
SELECT
    refund_reason AS 退款原因,
    COUNT(DISTINCT order_id) AS 退款订单数,
    ROUND(COUNT(DISTINCT order_id) / SUM(COUNT(DISTINCT order_id)) OVER (), 3) AS 原因占比,
    ROUND(SUM(refund_amount), 2) AS 退款金额
FROM fact_refund
WHERE refund_status = '退款成功'
GROUP BY refund_reason
ORDER BY 退款订单数 DESC;

-- 运行结果（真实数据集，退款成功共 312 笔）：
-- 退款原因     | 退款订单数 | 原因占比
-- 物流损坏     |    57     |  0.183
-- 与描述不符   |    57     |  0.183
-- 尺码/规格不符 |    56     |  0.179
-- 商品质量问题 |    51     |  0.163
-- 七天无理由   |    46     |  0.147
-- 发错货       |    45     |  0.144


-- ---------------------------------------------------------------------
-- 7.4 按商品定位高退款单品（关联明细表 + 商品维度表，交品控排查）
-- ---------------------------------------------------------------------
SELECT
    p.product_name AS 商品名称,
    p.category     AS 商品类目,
    COUNT(DISTINCT o.order_id) AS 关联订单数,
    COUNT(DISTINCT r.order_id) AS 退款订单数,
    ROUND(COUNT(DISTINCT r.order_id) / COUNT(DISTINCT o.order_id), 3) AS 退款率
FROM fact_order o
JOIN fact_order_detail d ON o.order_id = d.order_id
JOIN dim_product p       ON d.product_id = p.product_id
LEFT JOIN fact_refund r
    ON o.order_id = r.order_id
   AND r.refund_status = '退款成功'
WHERE o.order_status = '已完成'
GROUP BY p.product_name, p.category
HAVING 关联订单数 >= 20          -- 样本量过小的商品不纳入排名，避免偶然偏差
ORDER BY 退款率 DESC
LIMIT 10;

-- 运行结果（退款率 Top，样本量 ≥ 20；成交口径，退款为整单退款，分母为含该商品的已完成订单数）：
-- 商品名称 | 商品类目 | 关联订单数 | 退款订单数 | 退款率
-- 台灯     | 家居日用 |    361    |    31     | 0.086
-- 黑咖啡   | 食品生鲜 |    198    |    17     | 0.086
-- 洗面奶   | 美妆护肤 |    237    |    19     | 0.080
-- 每日坚果 | 食品生鲜 |    191    |    15     | 0.079
-- 蓝牙耳机 | 数码家电 |    153    |    12     | 0.078
