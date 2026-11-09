-- =====================================================================
-- 项目：sql-电商练习
-- 文件：04_RFM用户分层.sql
-- 真实表：fact_order（订单主表，订单粒度）
-- 模型定义：
--   R（Recency）：最近一次成交订单距基准日的天数，越小越活跃
--   F（Frequency）：已完成订单数，越大越忠诚
--   M（Monetary）：累计成交金额，越高价值越大
-- 口径：仅统计 order_status = '已完成' 的订单；基准日取 2025-12-31（年末）
-- 分层阈值（基于本数据集分布设定，可在 CASE WHEN 中按业务调整）：
--   R：≤30 近期活跃；>90 沉睡；F：≥5 高频，=1 单次；M：≥3000 高消费，<1000 低消费
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 计算每个用户的 R / F / M 与用户标签（明细层）
-- ---------------------------------------------------------------------
SELECT
    user_id,
    R, F, M,
    CASE
        WHEN R <= 30  AND F >= 5 AND M >= 3000 THEN '重要价值用户'  -- 近期活跃、高频、高消费
        WHEN R >  90  AND F >= 5 AND M >= 3000 THEN '重要挽回用户'  -- 历史高频高消费，近期流失，优先挽回
        WHEN R <= 30  AND F = 1  AND M <  1000 THEN '新客观察'      -- 刚成交一次、金额不高，持续观察培育
        WHEN R <= 30  AND F >= 2 AND M <  3000 THEN '潜力用户'      -- 近期有复购但金额中等，可提客单
        WHEN R >  90                              THEN '流失沉睡用户'  -- 超过 90 天未成交
        ELSE '一般维持用户'                                          -- 其余常规维护人群
    END AS user_tag
FROM (
    -- 内层：按用户聚合已完成订单，得到最近下单日、订单数、累计金额
    SELECT
        user_id,
        DATEDIFF('2025-12-31', MAX(order_date)) AS R,
        COUNT(DISTINCT order_id) AS F,
        SUM(order_amount) AS M
    FROM fact_order
    WHERE order_status = '已完成'
    GROUP BY user_id
) base;


-- ---------------------------------------------------------------------
-- 4.2 各分层用户人数与占比（汇报汇总表）
--     先在内层打好标签，外层再按标签分组，避免在 GROUP BY 里重复写 CASE
-- ---------------------------------------------------------------------
SELECT
    user_tag AS 用户分层,
    COUNT(*) AS 用户数,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 3) AS 人数占比
FROM (
    SELECT
        user_id,
        CASE
            WHEN R <= 30  AND F >= 5 AND M >= 3000 THEN '重要价值用户'
            WHEN R >  90  AND F >= 5 AND M >= 3000 THEN '重要挽回用户'
            WHEN R <= 30  AND F = 1  AND M <  1000 THEN '新客观察'
            WHEN R <= 30  AND F >= 2 AND M <  3000 THEN '潜力用户'
            WHEN R >  90                              THEN '流失沉睡用户'
            ELSE '一般维持用户'
        END AS user_tag
    FROM (
        SELECT
            user_id,
            DATEDIFF('2025-12-31', MAX(order_date)) AS R,
            COUNT(DISTINCT order_id) AS F,
            SUM(order_amount) AS M
        FROM fact_order
        WHERE order_status = '已完成'
        GROUP BY user_id
    ) base
) tagged
GROUP BY user_tag
ORDER BY 用户数 DESC;

-- 运行结果（真实数据集，成交用户共 1191 人）：
-- 用户分层     | 用户数 | 人数占比
-- 一般维持用户 |  447  |  0.375
-- 流失沉睡用户 |  352  |  0.296
-- 潜力用户     |  247  |  0.207
-- 重要价值用户 |  105  |  0.088
-- 重要挽回用户 |   33  |  0.028
-- 新客观察     |    7  |  0.006


-- ---------------------------------------------------------------------
-- 4.3 高价值用户明细（累计消费 Top 10，供运营重点维护）
-- ---------------------------------------------------------------------
SELECT
    user_id,
    DATEDIFF('2025-12-31', MAX(order_date)) AS R,
    COUNT(DISTINCT order_id) AS F,
    ROUND(SUM(order_amount), 2) AS M
FROM fact_order
WHERE order_status = '已完成'
GROUP BY user_id
ORDER BY M DESC
LIMIT 10;
