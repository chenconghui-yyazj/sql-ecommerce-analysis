# sql-电商练习

> 电商业务数据分析实战项目 ｜ MySQL
> 项目定位：基于一套 **1200 用户、180 商品、9000 次访问、5956 笔订单** 的真实模拟电商数据集，复刻数据分析师日常指标开发与业务分析全流程，覆盖 **流量转化 → 用户价值分层 → 用户复购 → 订单商品指标 → 售后退款** 五大模块。
> 工具：MySQL 8.0 + DBeaver；以子查询 / 分层聚合写法为主，分组占比使用窗口函数（需 MySQL 8.0 及以上）。
> 数据周期：2025-01-01 ~ 2025-12-31。

---

## 一、项目概述

### 1.1 项目背景
模拟一家全年运营的综合电商平台，基于用户访问埋点、订单主表、订单明细、退款记录以及用户、商品维度表，搭建常态化业务指标体系：评估流量转化效率、做 RFM 用户分层、衡量用户粘性、分析客单价与凑单效果、定位售后风险，为投放预算、用户运营、商品品控与售后策略提供数据支撑。

### 1.2 分析目标
1. 搭建「访问 → 转化 → 成交」漏斗，拆分渠道与落地页质量，定位流失环节；
2. 用 RFM 模型完成用户价值分层，输出用户标签，支撑精细化运营；
3. 计算用户口径 / 订单口径复购率，评估平台用户粘性；
4. 计算客单价、连带率，评估凑单、搭配购与满减活动效果；
5. 统计退款率与退款原因，定位高退款商品，排查售后风险。

### 1.3 数据表清单（真实数据集，行数已核对）

| 表名 | 表类型 | 粒度 | 行数 | 业务含义 |
| ---- | ---- | ---- | ---- | ---- |
| dim_user | 维度表 | 用户 | 1200 | 用户基础信息、会员等级、注册渠道 |
| dim_product | 维度表 | 商品 | 180 | 商品类目、名称、成本价、售价、在售状态 |
| fact_traffic | 事实表 | 一次访问会话 | 9000 | 流量渠道、落地页、是否转化、停留时长 |
| fact_order | 事实表 | 一个订单 | 5956 | 订单金额、件数、状态、支付方式、省份 |
| fact_order_detail | 事实表 | 订单中的一件商品 | 6000 | 购买数量、单价、折扣、明细金额 |
| fact_refund | 事实表 | 一笔退款 | 350 | 退款原因、金额、退款状态 |

### 1.4 全局口径约定（贯穿全部 SQL）
- **成交订单**：`order_status = '已完成'`；`已取消`、`待发货` 不计入成交 GMV 与成交用户；
- **有效退款**：`refund_status = '退款成功'`；`退款审核中` 不计入退款分子；
- **UV**：独立用户数，一律 `COUNT(DISTINCT user_id)`；**PV**：访问会话记录数；
- 订单主表 `fact_order` 已是订单粒度；商品级分析才下钻到 `fact_order_detail`。

### 1.5 数据画像（导入后可直接用 SQL 复核）
- 订单状态分布：已完成 5147（86.4%）、已取消 441（7.4%）、待发货 368（6.2%）；
- 已完成成交 GMV：**2,586,694.74 元**；已取消订单金额 212,283.91 元；
- 会员等级：普通 695、银卡 272、金卡 181、钻石 52；
- 流量渠道：自然搜索、抖音短视频、直播间、直通车、朋友圈广告、老客推荐共 6 类；
- 主外键已 100% 对齐：流量 / 订单用户全部命中用户表，订单全部命中明细表，退款订单全部命中订单表，明细商品全部命中商品表。

---

## 二、数据字典

### 2.1 dim_user 用户维度表（1200 行）

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| user_id | varchar(20) | 用户唯一ID（主键） |
| gender | varchar(4) | 性别：男 / 女 |
| age | int | 年龄 |
| city | varchar(20) | 所在城市 |
| reg_channel | varchar(20) | 注册渠道 |
| member_level | varchar(10) | 会员等级：普通 / 银卡 / 金卡 / 钻石 |
| reg_date | date | 注册日期 |

### 2.2 dim_product 商品维度表（180 行）

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| product_id | varchar(20) | 商品唯一ID（主键） |
| category | varchar(20) | 商品类目 |
| product_name | varchar(50) | 商品名称 |
| cost_price | decimal(10,2) | 成本价 |
| sale_price | decimal(10,2) | 销售价 |
| is_on_sale | varchar(10) | 在售状态：在售 / 下架 |

### 2.3 fact_traffic 流量事实表（9000 行，一次访问会话）

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| visit_id | varchar(20) | 访问会话ID（主键） |
| user_id | varchar(20) | 用户ID，关联 dim_user.user_id |
| visit_time | datetime | 访问时间 |
| visit_date | date | 访问日期 |
| traffic_source | varchar(20) | 流量渠道 |
| landing_page | varchar(20) | 落地页类型 |
| is_convert | tinyint | 本次访问是否转化：1=是，0=否 |
| visit_duration_sec | int | 访问停留时长（秒） |

### 2.4 fact_order 订单主表（5956 行，订单粒度）

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| order_id | varchar(20) | 订单编号（主键） |
| user_id | varchar(20) | 下单用户ID，关联 dim_user.user_id |
| order_date | date | 下单日期 |
| order_time | datetime | 下单时间 |
| order_amount | decimal(10,2) | 订单实付总额 |
| item_count | int | 订单商品总件数 |
| order_status | varchar(10) | 订单状态：已完成 / 已取消 / 待发货 |
| pay_method | varchar(10) | 支付方式 |
| province | varchar(10) | 收货省份 |

### 2.5 fact_order_detail 订单明细表（6000 行，订单-商品粒度）

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| detail_id | varchar(20) | 明细行ID（主键） |
| order_id | varchar(20) | 订单编号，关联 fact_order.order_id |
| product_id | varchar(20) | 商品ID，关联 dim_product.product_id |
| user_id | varchar(20) | 用户ID |
| order_time | datetime | 下单时间 |
| qty | int | 购买数量 |
| unit_price | decimal(10,2) | 商品单价 |
| discount_rate | decimal(4,2) | 折扣率 |
| detail_amount | decimal(10,2) | 本明细行金额 |

### 2.6 fact_refund 退款事实表（350 行）

| 字段 | 类型 | 说明 |
| ---- | ---- | ---- |
| refund_id | varchar(20) | 退款单ID（主键） |
| order_id | varchar(20) | 关联订单编号，关联 fact_order.order_id |
| user_id | varchar(20) | 退款用户ID |
| refund_date | date | 退款日期 |
| refund_reason | varchar(20) | 退款原因 |
| refund_amount | decimal(10,2) | 退款金额 |
| refund_status | varchar(10) | 退款状态：退款成功 / 退款审核中 |

---

## 三、原始数据与运行步骤

### 3.1 原始数据位置
全部原始数据位于本项目 `原始数据/` 文件夹：
- 6 张可直接导入的 CSV（与表一一对应）；
- `电商SQL教学数据集.xlsx`：6 张表的 Excel 汇总工作簿，首页为表结构说明。

### 3.2 运行顺序
1. 执行 `01_建表语句.sql` 创建 6 张表；
2. 按 `02_数据导入说明.md` 把 CSV 导入对应表（先维度表、后事实表）；
3. 依次执行 `03` ~ `07` 分析 SQL，对照本文档中的真实运行结果核对。

### 3.3 导入自检
```sql
SELECT 'dim_user' AS 表名, COUNT(*) AS 行数 FROM dim_user
UNION ALL SELECT 'dim_product',       COUNT(*) FROM dim_product
UNION ALL SELECT 'fact_traffic',      COUNT(*) FROM fact_traffic
UNION ALL SELECT 'fact_order',        COUNT(*) FROM fact_order
UNION ALL SELECT 'fact_order_detail', COUNT(*) FROM fact_order_detail
UNION ALL SELECT 'fact_refund',       COUNT(*) FROM fact_refund;
```
预期：1200 / 180 / 9000 / 5956 / 6000 / 350。

---

## 四、分析模块（按日常工作顺序）

### 模块 1：转化漏斗分析 ｜ 访问 → 转化 → 成交

**业务逻辑**：漏斗主体在 `fact_traffic` 内完成「访问 → 转化」，使用 UV；成交来自 `fact_order`，单独统计成交 UV 与访问成交率。一个用户可能从多个渠道访问，**渠道 UV 之间存在重叠，各渠道数字不可横向相加**。

#### 1.1 大盘漏斗（UV 口径）

```sql
SELECT
    COUNT(DISTINCT t.user_id) AS 访问UV,
    COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END) AS 转化UV,
    ROUND(
        COUNT(DISTINCT CASE WHEN t.is_convert = 1 THEN t.user_id END)
        / COUNT(DISTINCT t.user_id), 3
    ) AS 访问转化率,
    COUNT(DISTINCT o.user_id) AS 成交下单UV,
    ROUND(COUNT(DISTINCT o.user_id) / COUNT(DISTINCT t.user_id), 3) AS 访问成交率
FROM fact_traffic t
LEFT JOIN fact_order o
    ON t.user_id = o.user_id
   AND o.order_status = '已完成';
```

**运行结果（真实数据集）**

| 访问UV | 转化UV | 访问转化率 | 成交下单UV | 访问成交率 |
| ---- | ---- | ---- | ---- | ---- |
| 1200 | 888 | 0.740 | 1191 | 0.993 |

**业务解读**：1200 名访问用户中 888 人在访问环节被标记转化，访问转化率 74.0%；最终 1191 人产生已完成成交，访问成交率 99.3%，说明平台整体用户购买意愿强，主要流失发生在「访问 → 站内转化」环节。

#### 1.2 大盘漏斗（PV / 事件口径）

```sql
SELECT
    COUNT(visit_id) AS 访问PV,
    SUM(is_convert) AS 转化PV,
    ROUND(SUM(is_convert) / COUNT(visit_id), 3) AS 访问转化率_PV口径
FROM fact_traffic;
```

**运行结果**

| 访问PV | 转化PV | 访问转化率_PV口径 |
| ---- | ---- | ---- |
| 9000 | 1606 | 0.178 |

> UV 口径衡量「多少人被转化」，PV 口径衡量「多少次访问最终转化」，两者回答不同问题，日报中通常并列展示。

#### 1.3 按渠道拆分漏斗

```sql
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
```

**运行结果**

| 流量渠道 | 访问UV | 转化UV | 访问转化率 |
| ---- | ---- | ---- | ---- |
| 抖音短视频 | 969 | 311 | 0.321 |
| 自然搜索 | 1002 | 300 | 0.299 |
| 朋友圈广告 | 723 | 201 | 0.278 |
| 直播间 | 846 | 225 | 0.266 |
| 老客推荐 | 678 | 177 | 0.261 |
| 直通车 | 804 | 209 | 0.260 |

**业务解读**：抖音短视频转化率最高（32.1%），自然搜索次之（29.9%），属于高质量渠道，可优先分配预算；直通车、老客推荐、直播间转化率偏低，需要优化素材与落地承接。按日期监控每日转化率的 SQL 见 `03_转化漏斗分析.sql` 3.4 节。

---

### 模块 2：RFM 用户分层

**业务逻辑**：仅统计已完成订单；基准日 2025-12-31。R = 距最近成交天数，F = 成交订单数，M = 累计成交金额；内层按用户聚合，外层 `CASE WHEN` 打标签。

```sql
SELECT
    user_id, R, F, M,
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
) base;
```

**各分层人数与占比（成交用户共 1191 人）**

| 用户分层 | 用户数 | 人数占比 | 运营动作建议 |
| ---- | ---- | ---- | ---- |
| 一般维持用户 | 447 | 0.375 | 常规触达，推送通用活动 |
| 流失沉睡用户 | 352 | 0.296 | 超过 90 天未成交，短信 / 优惠券召回 |
| 潜力用户 | 247 | 0.207 | 近期有复购、金额中等，满减券拉升客单 |
| 重要价值用户 | 105 | 0.088 | 专属权益、新品优先体验，重点维护 |
| 重要挽回用户 | 33 | 0.028 | 历史高频高消费但近期流失，定向挽回 |
| 新客观察 | 7 | 0.006 | 首单用户，持续培育复购习惯 |

**累计消费 Top 5 用户（M 最高）**

| user_id | R | F | M |
| ---- | ---- | ---- | ---- |
| U100964 | 6 | 11 | 8086.24 |
| U100346 | 94 | 9 | 6918.30 |
| U100088 | 37 | 7 | 6904.40 |
| U100076 | 7 | 8 | 6637.58 |
| U100292 | 8 | 8 | 6560.01 |

**业务解读**：重要价值用户仅占 8.8%，但贡献高客单与高频复购，应配置专属权益；流失沉睡用户占 29.6%，是召回营销的主要池子；U100346 属于典型重要挽回用户（历史 9 单、消费 6918 元，但已 94 天未成交），应优先定向触达。

---

### 模块 3：复购分析（用户粘性）

**业务逻辑**：用户口径复购率 = 成交 ≥ 2 次用户 / 全部成交用户；先内层按用户统计订单数，外层判断 ≥ 2。

```sql
SELECT
    COUNT(DISTINCT user_id) AS 全部成交用户数,
    COUNT(DISTINCT CASE WHEN order_cnt >= 2 THEN user_id END) AS 复购用户数,
    ROUND(
        COUNT(DISTINCT CASE WHEN order_cnt >= 2 THEN user_id END)
        / COUNT(DISTINCT user_id), 3
    ) AS 用户复购率,
    ROUND(AVG(order_cnt), 2) AS 人均下单次数
FROM (
    SELECT user_id, COUNT(DISTINCT order_id) AS order_cnt
    FROM fact_order
    WHERE order_status = '已完成'
    GROUP BY user_id
) t_user_order;
```

**运行结果**

| 全部成交用户数 | 复购用户数 | 用户复购率 | 人均下单次数 |
| ---- | ---- | ---- | ---- |
| 1191 | 1120 | 0.940 | 4.32 |

**订单口径补充结果**：已完成订单 5147 笔，其中复购用户贡献 5076 笔，订单口径复购率 **0.986**。

**业务解读**：用户口径复购率 94.0%、人均成交 4.32 单，平台用户粘性很强，营收高度依赖老客复购；运营重心应放在维持老客活跃度，同时关注 71 名单次成交用户的二次转化。两套口径不可混用：用户口径衡量「多少人愿意再来」，订单口径衡量「营收里多少来自老客」。

---

### 模块 4：客单价 & 连带率（商品与活动评估）

**业务逻辑**：`fact_order` 已是订单粒度，直接在订单层计算；客单价 = 成交总额 / 订单数，连带率 = 商品总件数 / 订单数。

```sql
SELECT
    COUNT(order_id) AS 成交订单数,
    ROUND(SUM(order_amount), 2) AS 成交总销售额,
    ROUND(SUM(order_amount) / COUNT(order_id), 2) AS 客单价,
    ROUND(SUM(item_count) / COUNT(order_id), 2) AS 连带率
FROM fact_order
WHERE order_status = '已完成';
```

**运行结果**

| 成交订单数 | 成交总销售额 | 客单价 | 连带率 |
| ---- | ---- | ---- | ---- |
| 5147 | 2586694.74 | 502.56 | 2.53 |

**各品类销售额（关联明细表 + 商品表）**

| 商品类目 | 关联订单数 | 品类销售额 | 销售件数 |
| ---- | ---- | ---- | ---- |
| 美妆护肤 | 1173 | 657599.90 | 2960 |
| 家居日用 | 1163 | 598986.20 | 2960 |
| 食品生鲜 | 991 | 507030.29 | 2495 |
| 服饰鞋包 | 982 | 467962.36 | 2501 |
| 数码家电 | 870 | 355115.99 | 2124 |

**业务解读**：整体客单价 502.56 元，连带率 2.53 件/单，凑单与搭配效果处于中等水平；美妆护肤、家居日用是销售额前两大类目。月度客单价在 479 ~ 529 元区间波动，8 月客单价最高（529.30 元），可结合当月活动复盘满减与套装策略。

---

### 模块 5：退款分析（售后与风控）

**业务逻辑**：订单表 `LEFT JOIN` 退款表，保证全部成交订单进入分母；退款分子只取「退款成功」；订单退款率看售后，金额退款率看财务。

```sql
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
```

**运行结果**

| 成交订单数 | 退款订单数 | 订单退款率 | 成交总销售额 | 退款总金额 | 金额退款率 |
| ---- | ---- | ---- | ---- | ---- | ---- |
| 5147 | 312 | 0.061 | 2586694.74 | 106435.37 | 0.041 |

**退款原因结构（退款成功 312 笔）**

| 退款原因 | 退款订单数 | 原因占比 |
| ---- | ---- | ---- |
| 物流损坏 | 57 | 0.183 |
| 与描述不符 | 57 | 0.183 |
| 尺码/规格不符 | 56 | 0.179 |
| 商品质量问题 | 51 | 0.163 |
| 七天无理由 | 46 | 0.147 |
| 发错货 | 45 | 0.144 |

**退款率 Top 商品（样本量 ≥ 20，退款为整单退款）**

| 商品名称 | 商品类目 | 关联订单数 | 退款订单数 | 退款率 |
| ---- | ---- | ---- | ---- | ---- |
| 台灯 | 家居日用 | 361 | 31 | 0.086 |
| 黑咖啡 | 食品生鲜 | 198 | 17 | 0.086 |
| 洗面奶 | 美妆护肤 | 237 | 19 | 0.080 |
| 每日坚果 | 食品生鲜 | 191 | 15 | 0.079 |
| 蓝牙耳机 | 数码家电 | 153 | 12 | 0.078 |

**业务解读**：整体订单退款率 6.1%、金额退款率 4.1%，处于可控区间；退款原因集中在物流损坏、与描述不符、尺码/规格不符三类（合计 54.5%），分别对应仓储包装、商品详情页描述、尺码指引三类改进方向；台灯、黑咖啡、洗面奶退款率居前，需交品控与采购重点排查。

---

## 五、整体分析总结与业务建议

1. **流量**：抖音短视频、自然搜索转化质量最高，建议加大预算；直通车、直播间转化偏低，优化投放素材与落地承接；落地页中购物车转化率最低（PV 口径 16.9%），需检查购物车流程与优惠提示。
2. **用户**：复购率 94.0%、人均 4.32 单，基本盘稳固；29.6% 用户已进入流失沉睡状态，应启动分层召回；105 名重要价值用户配置专属权益防止流失。
3. **商品**：连带率 2.53 仍有提升空间，可通过套装、凑单满减、搭配推荐拉高件数；美妆护肤、家居日用为核心类目，重点保障库存与售后。
4. **售后**：退款主因是物流损坏与描述不符，建议加强包装与物流核验、完善详情页图文与尺码表；对退款率靠前的单品做专项品控复盘。

## 六、核心 SQL 知识点清单

- 多表关联：`LEFT JOIN` 保留全量样本保证分母不丢失；`JOIN` 下钻商品 / 明细维度；
- 条件计数：`COUNT(DISTINCT CASE WHEN 条件 THEN user_id END)`；
- 分层聚合：先内层聚合到用户 / 订单粒度，外层再汇总指标；
- 粒度控制：区分会话、订单、订单-商品三种粒度，避免在明细表上直接求订单均值；
- 指标口径：UV 与 PV、用户口径与订单口径、订单退款率与金额退款率；
- 空值与除零：`IFNULL` 替换 NULL；状态过滤保证分子分母同口径；
- 时间函数：`DATEDIFF`、`DATE_FORMAT`、`MAX/MIN` 日期提取；
- 窗口函数：`SUM(COUNT(*)) OVER()` 计算分组占比。

## 七、文件清单

| 文件 | 内容 |
| ---- | ---- |
| `原始数据/` | 6 张 CSV 原始数据集 + Excel 汇总工作簿 |
| `01_建表语句.sql` | 6 张表建表语句与索引 |
| `02_数据导入说明.md` | DBeaver / LOAD DATA 导入步骤与自检 SQL |
| `03_转化漏斗分析.sql` | 大盘 UV / PV 漏斗、渠道漏斗、日期趋势 |
| `04_RFM用户分层.sql` | R/F/M 计算、分层人数占比、高价值用户 Top10 |
| `05_复购分析.sql` | 用户口径、订单口径、下单次数分布、首单月份趋势 |
| `06_客单价与连带率.sql` | 大盘指标、月度趋势、品类销售结构 |
| `07_退款分析.sql` | 大盘退款率、月度趋势、退款原因、高退款商品 |
| `运行结果汇总表.md` | 全部模块真实跑批结果汇总，供网页 / 报告直接引用 |
| `执行验证记录.md` | 交付前复核环境、口径与逐项核对结果留痕 |

## 八、简历项目描述（精简版，可直接粘贴）

> **电商用户行为数据分析项目 ｜ MySQL**
> 基于 1200 用户、5956 笔订单的电商真实模拟数据集（流量、订单主表、订单明细、退款、用户、商品 6 张表），搭建全链路业务指标体系，完成访问转化漏斗、RFM 用户分层、复购率、客单价与连带率、退款分析。严格区分 UV/PV、订单与明细粒度，使用 LEFT JOIN 保证指标口径准确，支持按渠道、月份、品类、商品多维度切片，定位低转化渠道、高价值与流失用户、高退款商品并输出业务优化建议，支撑投放、用户与商品运营决策。
> **技术栈**：MySQL、多表关联、CASE WHEN、分层聚合、窗口函数、RFM 模型。
