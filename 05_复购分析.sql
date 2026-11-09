-- =====================================================================
-- 项目：sql-电商练习
-- 文件：05_复购分析.sql
-- 真实表：fact_order（订单主表）
-- 口径：仅统计 order_status = '已完成' 的成交订单
-- 两套口径（不可混用，汇报时必须注明）：
--   用户口径：下单 ≥ 2 次的用户数 / 全部成交用户数（衡量用户粘性，最常用）
--   订单口径：复购用户贡献的订单数 / 全部成交订单数（衡量营收来自老客的比例）
-- 核心思路：先在内层按用户统计订单数，外层再判断 ≥ 2，避免同一用户多单被重复计数
-- =====================================================================


-- ---------------------------------------------------------------------
-- 5.1 用户口径复购率（大盘，最常用）
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT user_id) AS 全部成交用户数,
    COUNT(DISTINCT CASE WHEN order_cnt >= 2 THEN user_id END) AS 复购用户数,
    ROUND(
        COUNT(DISTINCT CASE WHEN order_cnt >= 2 THEN user_id END)
        / COUNT(DISTINCT user_id), 3
    ) AS 用户复购率,
    ROUND(AVG(order_cnt), 2) AS 人均下单次数
FROM (
    -- 内层：按用户统计已完成订单数
    SELECT user_id, COUNT(DISTINCT order_id) AS order_cnt
    FROM fact_order
    WHERE order_status = '已完成'
    GROUP BY user_id
) t_user_order;

-- 运行结果（真实数据集）：
-- 全部成交用户数 | 复购用户数 | 用户复购率 | 人均下单次数
--     1191      |    1120    |   0.940    |    4.32


-- ---------------------------------------------------------------------
-- 5.2 订单口径复购率（营收视角补充口径）
--     复购订单 = 来自下单 ≥ 2 次用户的已完成订单
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT o.order_id) AS 全部成交订单数,
    COUNT(DISTINCT CASE WHEN u.order_cnt >= 2 THEN o.order_id END) AS 复购订单数,
    ROUND(
        COUNT(DISTINCT CASE WHEN u.order_cnt >= 2 THEN o.order_id END)
        / COUNT(DISTINCT o.order_id), 3
    ) AS 订单口径复购率
FROM fact_order o
LEFT JOIN (
    SELECT user_id, COUNT(DISTINCT order_id) AS order_cnt
    FROM fact_order
    WHERE order_status = '已完成'
    GROUP BY user_id
) u ON o.user_id = u.user_id
WHERE o.order_status = '已完成';

-- 运行结果：
-- 全部成交订单数 | 复购订单数 | 订单口径复购率
--      5147      |    5076    |     0.986


-- ---------------------------------------------------------------------
-- 5.3 用户下单次数分布（看单次 / 多次用户结构）
-- ---------------------------------------------------------------------
SELECT
    order_cnt AS 下单次数,
    COUNT(user_id) AS 用户数,
    ROUND(COUNT(user_id) / SUM(COUNT(user_id)) OVER (), 3) AS 用户占比
FROM (
    SELECT user_id, COUNT(DISTINCT order_id) AS order_cnt
    FROM fact_order
    WHERE order_status = '已完成'
    GROUP BY user_id
) t
GROUP BY order_cnt
ORDER BY order_cnt;


-- ---------------------------------------------------------------------
-- 5.4 按首单月份看新客复购趋势（观察每一批新客后续留存复购情况）
-- ---------------------------------------------------------------------
SELECT
    first_month AS 首单月份,
    COUNT(DISTINCT user_id) AS 新客用户数,
    COUNT(DISTINCT CASE WHEN order_cnt >= 2 THEN user_id END) AS 复购用户数,
    ROUND(
        COUNT(DISTINCT CASE WHEN order_cnt >= 2 THEN user_id END)
        / COUNT(DISTINCT user_id), 3
    ) AS 新客复购率
FROM (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS order_cnt,
        DATE_FORMAT(MIN(order_date), '%Y-%m') AS first_month
    FROM fact_order
    WHERE order_status = '已完成'
    GROUP BY user_id
) t
GROUP BY first_month
ORDER BY first_month;
