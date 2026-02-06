# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "未检测到Docker，请先安装Docker"
        echo "安装指南：https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker已安装 ($(docker --version | awk '{print $3}'))"
}

# 检查Docker Compose
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
        print_success "docker-compose已安装"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker compose"
        print_success "docker compose已安装"
    else
        print_error "未检测到docker-compose，请安装："
        echo "sudo apt-get install docker-compose  # Ubuntu/Debian"
        echo "或参考：https://docs.docker.com/compose/install/"
        exit 1
    fi
}

# 检查必要目录和文件
check_files() {
    print_info "检查项目文件..."
    
    # 检查数据文件
    if [ ! -f "data/olist_sellers_dataset.csv" ]; then
        print_warning "卖家数据文件不存在"
        echo "请确保以下文件已放置："
        echo "  data/olist_sellers_dataset.csv"
        echo "  data/olist_orders_dataset.csv"
        echo "  data/olist_order_items_dataset.csv"
        echo ""
        read -p "按回车继续（如果文件不存在，分析可能无法正常运行）..."
    else
        print_success "数据文件检查通过"
    fi
    
    # 检查SQL文件
    if [ ! -f "sql/01_setup_database.sql" ]; then
        print_error "SQL初始化文件不存在"
        exit 1
    fi
    print_success "SQL文件检查通过"
}

# 启动服务
start_services() {
    print_info "启动数据分析环境..."
    
    # 停止可能存在的旧容器
    $DOCKER_COMPOSE_CMD down 2>/dev/null
    
    # 启动新容器
    if $DOCKER_COMPOSE_CMD up -d; then
        print_success "服务启动成功！"
    else
        print_error "服务启动失败"
        exit 1
    fi
}

# 等待服务就绪
wait_for_services() {
    print_info "等待数据库启动（约30秒）..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec ecommerce-analysis-db pg_isready -U admin &> /dev/null; then
            print_success "数据库已就绪"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    print_error "数据库启动超时"
    return 1
}

# 运行数据验证
run_data_validation() {
    print_info "验证数据导入..."
    
    local validation_query="SELECT '卖家数量' as table_name, COUNT(*) as count FROM olist_sellers
                           UNION ALL
                           SELECT '订单数量', COUNT(*) FROM olist_orders
                           UNION ALL
                           SELECT '订单商品数量', COUNT(*) FROM olist_order_items;"
    
    docker exec ecommerce-analysis-db psql -U admin -d ecommerce_analysis \
        -c "$validation_query" 2>/dev/null || {
        print_warning "数据验证查询失败，但服务可能仍在启动中"
    }
}

# 显示访问信息
show_access_info() {
    echo ""
    echo "=========================================="
    echo "电商卖家数据分析环境启动完成！"
    echo "=========================================="
    echo ""
    echo "访问方式："
    echo ""
    echo "1. 数据库管理界面 (PgAdmin)"
    echo "   网址: http://localhost:8080"
    echo "   邮箱: admin@ecommerce.com"
    echo "   密码: admin123"
    echo ""
    echo "2. 直接连接数据库"
    echo "   主机: localhost"
    echo "   端口: 5432"
    echo "   数据库: ecommerce_analysis"
    echo "   用户: admin"
    echo "   密码: password123"
    echo ""
    echo "3. 运行示例分析"
    echo "   卖家分层分析:"
    echo "     docker exec ecommerce-analysis-db psql -U admin -d ecommerce_analysis -f /sql/02_seller_tiering.sql"
    echo ""
    echo "   成长分析:"
    echo "     docker exec ecommerce-analysis-db psql -U admin -d ecommerce_analysis -f /sql/03_growth_analysis.sql"
    echo ""
    echo "管理命令："
    echo "   查看日志: docker-compose logs"
    echo "   停止服务: docker-compose down"
    echo "   重启服务: docker-compose restart"
    echo ""
    echo "项目文档："
    echo "   分析报告: docs/业务分析报告.md"
    echo ""

}

# 主函数
main() {
    clear
    echo "=========================================="
    echo "电商卖家数据分析环境一键启动脚本"
    echo "=========================================="
    echo ""
    
    # 检查依赖
    check_docker
    check_docker_compose
    
    # 检查文件
    check_files
    
    # 启动服务
    start_services
    
    # 等待服务就绪
    if wait_for_services; then
        # 数据验证
        run_data_validation
        
        # 显示访问信息
        show_access_info
        
        # 提示下一步
        echo ""
        print_info "下一步建议："
        echo "  1. 打开浏览器访问 http://localhost:8080"
        echo "  2. 添加服务器连接信息"
        echo "  3. 运行SQL分析脚本"
    else
        print_error "环境启动失败，请检查日志：docker-compose logs"
        exit 1
    fi
}

# 执行主函数
main "$@"
