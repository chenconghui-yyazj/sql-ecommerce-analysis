-- =====================================================================
-- 项目：sql-电商练习
-- 文件：03_转化漏斗分析.sql
-- 真实表：fact_traffic（访问会话）、fact_order（订单主表）
-- 链路：访问 → 站内转化(is_convert=1) → 成交下单(order_status='已完成')
-- 口径说明（重要，面试会被追问）：
--   1. 漏斗主体在 fact_traffic 内完成「访问 → 转化」，使用 UV（DISTINCT user_id）；
--   2. 成交下单来自 fact_order，单独统计成交 UV 与访问成交率，不与流量 UV 做嵌套相除；
--   3. 一个用户可能从多个渠道访问，渠道 UV 之间存在重叠，各渠道数字不可横向相加；
--   4. 已完成订单才计入成交；已取消、待发货不计入成交口径。
-- =====================================================================


-- ---------------------------------------------------------------------
-- 3.1 大盘漏斗（UV 口径，开会 / 汇报看整体）
-- ---------------------------------------------------------------------
SELECT
    -- 访问 UV：发生过访问的独立用户
    COUNT(DISTINCT t.user_id) AS 访问UV,
    -- 转化 UV：is_convert = 1 的独立用户
    COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END) AS 转化UV,
    -- 访问 → 转化率（分母：访问 UV）
    ROUND(
        COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END)
        / COUNT(DISTINCT t.user_id), 3
    ) AS 访问转化率,
    -- 成交下单 UV：已完成订单的独立用户（来自订单表，单独列示）
    COUNT(DISTINCT o.user_id) AS 成交下单UV,
    -- 访问成交率：访问用户中最终产生成交的比例
    ROUND(COUNT(DISTINCT o.user_id) / COUNT(DISTINCT t.user_id), 3) AS 访问成交率
FROM fact_traffic t
LEFT JOIN fact_order o
    ON t.user_id = o.user_id
   AND o.order_status = '已完成';

-- 运行结果（真实数据集）：
-- 访问UV | 转化UV | 访问转化率 | 成交下单UV | 访问成交率
--  1200 |  888  |   0.740    |   1191    |   0.993


-- ---------------------------------------------------------------------
-- 3.2 大盘漏斗（PV / 事件口径，按访问会话记录数统计）
--     is_convert 标记在访问记录上，事件口径更贴合埋点原始行为
-- ---------------------------------------------------------------------
SELECT
    COUNT(visit_id) AS 访问PV,
    SUM(is_convert) AS 转化PV,
    ROUND(SUM(is_convert) / COUNT(visit_id), 3) AS 访问转化率_PV口径
FROM fact_traffic;

-- 运行结果：
-- 访问PV | 转化PV | 访问转化率_PV口径
--  9000  |  1606  |      0.178


-- ---------------------------------------------------------------------
-- 3.3 按渠道拆分漏斗（投放运营判断渠道质量；只做访问 → 转化一层）
-- ---------------------------------------------------------------------
SELECT
    t.traffic_source AS 流量渠道,
    COUNT(DISTINCT t.user_id) AS 访问UV,
    COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END) AS 转化UV,
    ROUND(
        COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END)
        / COUNT(DISTINCT t.user_id), 3
    ) AS 访问转化率
FROM fact_traffic t
GROUP BY t.traffic_source
ORDER BY 访问转化率 DESC;

-- 运行结果（真实数据集，渠道 UV 存在重叠，不可相加）：
-- 流量渠道   | 访问UV | 转化UV | 访问转化率
-- 抖音短视频 |  969   |  311   |   0.321
-- 自然搜索   |  1002  |  300   |   0.299
-- 朋友圈广告 |  723   |  201   |   0.278
-- 直播间     |  846   |  225   |   0.266
-- 老客推荐   |  678   |  177   |   0.261
-- 直通车     |  804   |  209   |   0.260


-- ---------------------------------------------------------------------
-- 3.4 按日期看每日访问转化趋势（日报看板，监控转化率异动）
-- ---------------------------------------------------------------------
SELECT
    t.visit_date AS 日期,
    COUNT(DISTINCT t.user_id) AS 访问UV,
    COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END) AS 转化UV,
    ROUND(
        COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END)
        / COUNT(DISTINCT t.user_id), 3
    ) AS 访问转化率
FROM fact_traffic t
GROUP BY t.visit_date
ORDER BY t.visit_date;
