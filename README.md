# 电商卖家增长数据分析项目

## 项目概述
本项目模拟电商平台的卖家入驻流程，通过SQL构建完整的转化漏斗分析模型，旨在识别增长瓶颈、优化运营策略。

## 业务背景
在平台型电商业务中，卖家增长是核心指标之一。从潜在卖家提交申请到最终成为活跃卖家，整个过程涉及多个环节，每个环节的转化率都直接影响业务增长。本分析旨在：
- 量化各环节转化效率
- 识别关键流失点
- 提供数据驱动的优化建议

## 分析指标
| 指标 | 说明 | 计算公式 |
|------|------|----------|
| 线索总量 | 提交申请的卖家数量 | COUNT(*) |
| 提交率 | 完成资料提交的比例 | 提交数/线索数 |
| 审核率 | 通过初步审核的比例 | 审核通过数/提交数 |
| 激活率 | 完成首单上架的比例 | 激活数/审核通过数 |
| 整体转化率 | 从线索到激活的全流程转化率 | 激活数/线索数 |

## 技术栈
- 数据库: PostgreSQL 14+
- 主要技术: 
  - SQL CTE (Common Table Expressions)
  - 窗口函数 (Window Functions: LAG, LEAD, ROW_NUMBER)
  - 条件逻辑 (CASE WHEN)
  - 高级聚合 (ROLLUP, STRING_AGG)
- 可视化: 可通过Tableau连接分析结果

## 文件结构
/seller-growth-analysis
├── README.md # 项目说明（本文件）
├── sql/
│ ├── 01_create_tables.sql # 建表语句
│ ├── 02_insert_mock_data.sql # 模拟数据插入
│ ├── 03_funnel_analysis.sql # 核心分析查询
│ └── 04_advanced_metrics.sql # 进阶指标分析
├── data/
│ └── mock_data_sample.csv # 模拟数据样本
├── docs/
│ ├── analysis_report.md # 完整分析报告
│ └── business_insights.pdf # 业务洞察总结
└── notebooks/
└── data_validation.ipynb # 数据质量检查（可选）

├── README.md                 # 项目说明（本文件）
├── ByteDance-Seller-Analysis/
│   ├── seller_funnel_analysis.sql    # 完整SQL代码
│   ├── data_sample.csv               # 模拟数据样本
│   ├── analysis_report.md            # 分析报告
│   └── insights_slides.pdf           # 总结PPT（可选）
