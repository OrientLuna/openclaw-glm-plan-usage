#!/bin/bash
#############################################################################
# GLM 编码套餐使用统计查询脚本
# 从 GLM 编码套餐监控端点查询使用统计信息
#############################################################################

set -uo pipefail

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# 配置路径
readonly OPENCLAW_CONFIG="${HOME}/.openclaw/openclaw.json"
readonly API_BASE="https://open.bigmodel.cn"

# 全局变量
PROVIDER=""
API_KEY=""

#############################################################################
# 辅助函数
#############################################################################

print_error() {
    echo -e "${RED}❌ 错误:${NC} $*" >&2
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $*"
}

# 检查依赖工具
check_dependencies() {
    if ! command -v curl &> /dev/null; then
        print_error "缺少依赖工具，请安装: curl"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "缺少依赖工具，请安装: jq"
        exit 1
    fi
}

# 查找 GLM 编码套餐提供商
find_coding_plan_provider() {
    local config="$1"

    # 检查配置文件是否存在
    if [[ ! -f "$config" ]]; then
        print_error "未找到 OpenClaw 配置文件 ~/.openclaw/openclaw.json"
        exit 1
    fi

    # 获取所有提供商名称
    local providers
    providers=$(jq -r '.models.providers // {} | keys[]' "$config" 2>/dev/null || true)

    if [[ -z "$providers" ]]; then
        print_error "未找到配置的提供商"
        exit 1
    fi

    # 查找第一个使用编码端点的提供商
    for provider in $providers; do
        local base_url
        base_url=$(jq -r ".models.providers.\"$provider\".baseUrl // empty" "$config" 2>/dev/null)

        if [[ "$base_url" == *"api/coding/paas/v4"* ]]; then
            local api_key
            api_key=$(jq -r ".models.providers.\"$provider\".apiKey // empty" "$config" 2>/dev/null)

            if [[ -z "$api_key" ]]; then
                print_error "未找到提供商 '$provider' 的 API 密钥"
                exit 1
            fi

            PROVIDER="$provider"
            API_KEY="$api_key"
            return 0
        fi
    done

    # 未找到编码套餐提供商
    print_error "未找到配置 GLM 编码套餐的提供商"
    echo ""
    echo "请确保 provider 的 baseUrl 包含 'api/coding/paas/v4'"
    echo "示例配置:"
    echo '  "models": {'
    echo '    "providers": {'
    echo '      "glm-coding": {'
    echo '        "baseUrl": "https://open.bigmodel.cn/api/coding/paas/v4",'
    echo '        "apiKey": "your-api-key"'
    echo '      }'
    echo '    }'
    echo '  }'
    exit 1
}

# 查询 API 端点
query_api() {
    local endpoint="$1"
    local url="${API_BASE}${endpoint}"

    local response
    response=$(curl -sS \
        --connect-timeout 10 \
        --max-time 30 \
        -H "Authorization: $API_KEY" \
        -H "Content-Type: application/json" \
        "$url" 2>&1)

    local curl_exit=$?
    if [[ $curl_exit -ne 0 ]]; then
        print_error "API 请求超时"
        exit 1
    fi

    # 检查 HTTP 错误
    local http_code
    http_code=$(echo "$response" | jq -r 'select(.code? // .error? // .status? != null) | .code // .error // .status // "200"' 2>/dev/null)

    if [[ "$http_code" =~ ^(401|403)$ ]]; then
        print_error "认证失败，请检查 API 密钥配置"
        exit 1
    fi

    echo "$response"
}

# 绘制进度条
draw_progress_bar() {
    local percentage="$1"
    local width=30
    local filled=$(( width * percentage / 100 ))
    local empty=$(( width - filled ))

    echo -n "["
    printf '%0.s#' $(seq 1 $filled 2>/dev/null || echo "")
    printf '%0.s-' $(seq 1 $empty 2>/dev/null || echo "")
    echo -n "] "
    printf "%5.1f%%" "$percentage"
}

#############################################################################
# 输出格式化函数
#############################################################################

# 打印头部框
print_header() {
    local title="$1"
    local title_len=${#title}
    local box_width=64

    echo ""
    echo "╔$(printf '═%.0s' $(seq 1 $box_width 2>/dev/null || echo "") 2>/dev/null || echo "══════════════════════════════════════════════════════════════")╗"
    # 居中标题
    local padding=$(( (box_width - title_len - 2) / 2 ))
    printf "║%$((padding + 1))s%s%$((box_width - padding - title_len - 2))s║\n" "" "$title" ""
    echo "╠$(printf '═%.0s' $(seq 1 $box_width 2>/dev/null || echo "") 2>/dev/null || echo "══════════════════════════════════════════════════════════════")╣"
}

# 打印底部
print_footer() {
    local box_width=64
    echo "╚$(printf '═%.0s' $(seq 1 $box_width 2>/dev/null || echo "") 2>/dev/null || echo "══════════════════════════════════════════════════════════════")╝"
    echo ""
}

# 打印信息行
print_info_row() {
    local key="$1"
    local value="$2"
    local box_width=64
    local key_width=12

    printf "║  ${BOLD}%-${key_width}s${NC} %s%$((box_width - key_width - ${#value} - 6))s║\n" "$key" "$value" ""
}

# 打印分节标题
print_section_header() {
    local text="$1"
    local box_width=64

    echo "╠$(printf '═%.0s' $(seq 1 $box_width 2>/dev/null || echo "") 2>/dev/null || echo "══════════════════════════════════════════════════════════════")╣"
    printf "║  ${BOLD}%s${NC}%$((box_width - ${#text} - 4))s║\n" "$text" ""
    echo "╟$(printf '─%.0s' $(seq 1 $box_width 2>/dev/null || echo "") 2>/dev/null || echo "──────────────────────────────────────────────────────────────────────────────────")╢"
}

# 打印进度条行
print_progress_row() {
    local label="$1"
    local percentage="$2"
    local box_width=64

    printf "║  %-26s  " "$label"
    draw_progress_bar "$percentage"
    printf "%13s║\n" ""
}

# 打印统计行
print_stat_row() {
    local label="$1"
    local value="$2"
    local box_width=64

    printf "║  %-26s  %s%$((box_width - ${#label} - ${#value} - 8))s║\n" "$label" "$value" ""
}

#############################################################################
# 主查询函数
#############################################################################

query_quota_limits() {
    local response
    response=$(query_api "/api/monitor/usage/quota/limit")

    local success
    success=$(echo "$response" | jq -r '.success // false' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        print_warning "无法获取配额限制"
        return 1
    fi

    echo "$response"
}

query_model_usage() {
    local response
    response=$(query_api "/api/monitor/usage/model-usage")

    local success
    success=$(echo "$response" | jq -r '.success // false' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        print_warning "无法获取模型使用统计"
        return 1
    fi

    echo "$response"
}

query_tool_usage() {
    local response
    response=$(query_api "/api/monitor/usage/tool-usage")

    local success
    success=$(echo "$response" | jq -r '.success // false' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        print_warning "无法获取工具使用统计"
        return 1
    fi

    echo "$response"
}

#############################################################################
# 显示结果
#############################################################################

display_results() {
    local quota_response="$1"
    local model_response="$2"
    local tool_response="$3"

    # 计算时间周期
    local end_time
    local start_time
    end_time=$(date '+%Y-%m-%d %H:%M:%S')
    start_time=$(date -d '5 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v-5H '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$end_time")

    # 打印头部
    echo ""
    echo -e "${BOLD}📊 GLM 编码套餐使用统计${NC}"
    echo ""
    echo "提供商: $PROVIDER"
    echo "统计时间: $end_time"
    echo ""

    # 配额限制部分
    if [[ -n "$quota_response" ]]; then
        echo -e "${BOLD}配额限制${NC}"
        echo "---"

        local token_5h
        local mcp_1m
        local mcp_current
        local mcp_total
        local mcp_level

        token_5h=$(echo "$quota_response" | jq -r '.data.limits[]? | select(.type == "TOKENS_LIMIT") | .percentage // 0' 2>/dev/null || echo "0")
        mcp_1m=$(echo "$quota_response" | jq -r '.data.limits[]? | select(.type == "TIME_LIMIT") | .percentage // 0' 2>/dev/null || echo "0")
        mcp_current=$(echo "$quota_response" | jq -r '.data.limits[]? | select(.type == "TIME_LIMIT") | .currentValue // 0' 2>/dev/null || echo "0")
        mcp_total=$(echo "$quota_response" | jq -r '.data.limits[]? | select(.type == "TIME_LIMIT") | .usage // 0' 2>/dev/null || echo "0")
        mcp_level=$(echo "$quota_response" | jq -r '.data.level // "unknown"' 2>/dev/null || echo "unknown")

        echo "  Token 使用 (5小时): ${token_5h}%"
        echo "  MCP 使用 (1个月):   ${mcp_1m}%  (${mcp_current}/${mcp_total}) [${mcp_level}]"
        echo ""
    fi

    # 模型使用部分
    if [[ -n "$model_response" ]]; then
        echo -e "${BOLD}模型使用 (24小时)${NC}"
        echo "---"

        local total_tokens
        local total_calls

        total_tokens=$(echo "$model_response" | jq -r '.data.totalTokens // 0' 2>/dev/null || echo "0")
        total_calls=$(echo "$model_response" | jq -r '.data.totalCalls // 0' 2>/dev/null || echo "0")

        # 格式化数字
        formatted_tokens=$(echo "$total_tokens" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')
        formatted_calls=$(echo "$total_calls" | sed ':a;s/\B[0-9]\{3\}\>/,&/;ta')

        echo "  总 Token 数:  $formatted_tokens"
        echo "  总调用次数:  $formatted_calls"
        echo ""
    fi

    # 工具使用部分 - 简化显示
    if [[ -n "$tool_response" ]]; then
        echo -e "${BOLD}工具使用 (24小时)${NC}"
        echo "---"

        local tools
        tools=$(echo "$tool_response" | jq -r '.data.tools[]? // empty' 2>/dev/null)

        if [[ -n "$tools" ]]; then
            echo "$tools" | jq -r '"  \(.toolName // .name // "未知"): \(.usageCount // 0) 次"' 2>/dev/null
        else
            echo "  暂无数据"
        fi
        echo ""
    fi
}

#############################################################################
# 主入口
#############################################################################

main() {
    # 检查依赖
    check_dependencies

    # 查找编码套餐提供商
    find_coding_plan_provider "$OPENCLAW_CONFIG"

    # 查询所有端点
    local quota_response=""
    local model_response=""
    local tool_response=""

    quota_response=$(query_quota_limits)
    model_response=$(query_model_usage)
    tool_response=$(query_tool_usage)

    # 显示结果
    display_results "$quota_response" "$model_response" "$tool_response"
}

# 运行主函数
main "$@"
