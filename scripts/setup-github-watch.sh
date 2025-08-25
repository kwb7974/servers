#!/bin/bash

# GitHub Watch設定自動化スクリプト
# Auto-setup GitHub Watch settings for MCP servers

set -e

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# GitHub認証確認
check_github_auth() {
    log_info "GitHub認証状況を確認中..."
    if ! gh auth status >/dev/null 2>&1; then
        log_error "GitHub認証が必要です。'gh auth login'を実行してください。"
        exit 1
    fi
    log_info "GitHub認証OK"
}

# リポジトリWatch設定関数
setup_watch() {
    local repo=$1
    local description=$2
    
    log_info "設定中: $repo ($description)"
    
    # カスタムWatch設定 (releases + security_alerts)
    local response
    response=$(gh api --method PUT "repos/$repo/subscription" \
        --field subscribed=true \
        --field ignored=false 2>/dev/null || echo "error")
    
    if [ "$response" = "error" ]; then
        log_warn "Watch設定に失敗: $repo"
        return 1
    else
        log_info "✅ Watch設定完了: $repo"
        return 0
    fi
}

# 通知設定を最適化
optimize_notifications() {
    local repo=$1
    log_info "通知設定を最適化中: $repo"
    
    # Note: GitHub APIでは個別の通知タイプ（releases, security_alertsのみ）の設定は
    # リポジトリレベルでは直接制御できない。これはユーザーのGlobal設定に依存する。
    # 代わりに、Watch状態を有効にして、ユーザーに手動での細かい設定を案内する。
    
    log_info "ℹ️  細かい通知設定は https://github.com/$repo で手動で調整してください"
    log_info "   推奨: カスタム → ✅リリース ✅セキュリティアラート"
}

# メイン関数
main() {
    echo "🔔 MCPサーバー監視のためのGitHub Watch自動設定"
    echo "================================================"
    
    # 認証確認
    check_github_auth
    
    # 設定対象リポジトリリスト
    declare -A repos=(
        ["modelcontextprotocol/servers"]="公式MCPサーバーリポジトリ"
        ["modelcontextprotocol/servers-archived"]="アーカイブサーバー監視"
        ["brave/brave-search-mcp-server"]="Brave Search MCP"
        ["anaisbetts/mcp-installer"]="MCP Installer"
    )
    
    local success_count=0
    local total_count=${#repos[@]}
    
    # 各リポジトリを設定
    for repo in "${!repos[@]}"; do
        if setup_watch "$repo" "${repos[$repo]}"; then
            optimize_notifications "$repo"
            ((success_count++))
        fi
        echo ""  # 空行
    done
    
    # 結果サマリー
    echo "================================================"
    log_info "設定完了: $success_count/$total_count リポジトリ"
    
    if [ $success_count -eq $total_count ]; then
        log_info "🎉 全てのWatch設定が完了しました！"
        log_info ""
        log_info "次のステップ:"
        log_info "1. 各リポジトリで通知設定を細かく調整"
        log_info "2. GitHub通知設定でメール頻度を調整"
        log_info "3. 新しいMCPサーバー追加時はAIが自動で設定提案"
    else
        log_warn "一部のリポジトリで設定に失敗しました。手動で確認してください。"
    fi
}

# 個別リポジトリ追加用関数
add_watch_for_repo() {
    local repo=$1
    local description=${2:-"MCP Server"}
    
    if [ -z "$repo" ]; then
        log_error "使用方法: $0 add <owner/repo> [description]"
        exit 1
    fi
    
    log_info "🔔 新しいリポジトリのWatch設定: $repo"
    check_github_auth
    
    if setup_watch "$repo" "$description"; then
        optimize_notifications "$repo"
        log_info "✅ $repo のWatch設定が完了しました"
        
        # .ai-docs/context/server-health-status.md に記録
        local status_file="/Users/tomohisakawabe/mcp-servers/.ai-docs/context/server-health-status.md"
        if [ -f "$status_file" ]; then
            echo "- [ ] \`https://github.com/$repo\` - カスタム（リリース + セキュリティアラート）" >> "$status_file"
            log_info "📝 server-health-status.md に追加しました"
        fi
    else
        log_error "❌ $repo のWatch設定に失敗しました"
        exit 1
    fi
}

# コマンドライン引数処理
case "${1:-main}" in
    "main"|"")
        main
        ;;
    "add")
        add_watch_for_repo "$2" "$3"
        ;;
    "help"|"-h"|"--help")
        echo "使用方法:"
        echo "  $0              # 全ての既知リポジトリを設定"
        echo "  $0 add <repo>   # 新しいリポジトリを追加"
        echo "  $0 help         # このヘルプを表示"
        ;;
    *)
        log_error "不明なコマンド: $1"
        echo "使用方法については '$0 help' を参照してください"
        exit 1
        ;;
esac