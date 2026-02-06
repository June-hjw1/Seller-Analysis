#!/bin/bash

echo "🚀 启动电商卖家增长分析数据库环境..."
echo "========================================"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ 未检测到Docker，请先安装Docker"
    exit 1
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "⚠️  未检测到docker-compose，尝试使用docker compose..."
    DOCKER_COMPOSE_CMD="docker compose"
else
    DOCKER_COMPOSE_CMD="docker-compose"
fi

echo "📦 创建项目目录..."
mkdir -p {data,sql,docs,results}

echo "🐳 启动PostgreSQL和PgAdmin..."
$DOCKER_COMPOSE_CMD up -d

echo "⏳ 等待数据库启动（30秒）..."
sleep 30

echo "✅ 环境启动完成！"
echo ""
echo "📊 访问信息："
echo "  数据库:"
echo "   主机: localhost:5432"
echo "   数据库: seller_growth"
echo "   用户: admin"
echo "   密码: password123"
echo ""
echo "  管理界面:"
echo "   URL: http://localhost:8080"
echo "   邮箱: admin@seller.com"
echo "   密码: admin123"
echo ""
echo "📝 示例查询:"
echo "   docker exec -it seller-analysis-db psql -U admin -d seller_growth -c \"SELECT * FROM daily_funnel_metrics LIMIT 5;\""
echo ""
echo "🛑 停止环境:"
echo "   docker-compose down"
echo ""
echo "🔗 GitHub项目: https://github.com/hejiawen/seller-growth-analysis"
