#!/bin/bash

# 主菜单函数
function main_menu() {
    clear
    echo "选择操作："
    echo "(1)删除 Docker"
    echo "(2)删除 启动项"
    echo "(3)删除 进程"
    echo "(4)删除同名的screen"
    echo "(5)删除pm2进行"
    echo "(6)删除 文件"
    echo "(7)执行以上所有操作"
    read -p "选择需要的操作: " choice

    case $choice in
        1) remove_docker ;;
        2) remove_systemctl ;;
        3) kill_processes ;;
        4) kill_screen ;;
        5) remove_pm2 ;;
        6) remove_dir ;;
        7) exe_all_remove ;;
        *) echo "无效选项。" ;;
    esac
}

# 1删除 Docker 资源
function remove_docker() {
    local keyword=$1
    if [ -z "$keyword" ]; then
        read -p "(1)删除 Docker 资源： " keyword
        if [ -z "$keyword" ]; then
            echo "错误：没有提供关键词。"
            return 1
        fi
    fi
    # 查找相关容器
    echo "正在查找所有包含 '$keyword' 的容器..."
    local containers=$(docker ps -a | grep "$keyword" | awk '{print $1}')
    echo "找到以下容器："
    echo "$containers"

    # 查找相关镜像
    echo "(1)正在查找所有包含 '$keyword' 的镜像..."
    local images=$(docker images | grep "$keyword" | awk '{print $3}')
    echo "找到以下镜像："
    echo "$images"

    # 查找相关卷
    echo "正在查找所有包含 '$keyword' 的卷..."
    local volumes=$(docker volume ls | grep "$keyword" | awk '{print $2}')
    echo "找到以下卷："
    echo "$volumes"

    # 请求用户确认是否删除
    read -p "是否停止并删除以上所有容器、镜像和卷？(Y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        # 停止相关容器
        echo "停止所有包含 '$keyword' 的容器..."
        echo "$containers" | xargs -r docker stop

        # 删除相关容器
        echo "删除所有包含 '$keyword' 的容器..."
        echo "$containers" | xargs -r docker rm

        # 删除相关镜像
        echo "删除所有包含 '$keyword' 的镜像..."
        echo "$images" | xargs -r docker rmi -f

        # 删除相关卷
        if [ -n "$volumes" ]; then
            for volume in $volumes; do
                echo "删除卷：$volume"
                docker volume rm $volume
            done
        else
            echo "没有找到与 '$keyword' 相关的卷。"
        fi

        echo "(1)操作已完成。"
    else
        echo "(1)操作已取消。"
    fi
}



# 2停止&删除启动项
function remove_systemctl() {
    local keyword=$1
    if [ -z "$keyword" ]; then
        read -p "(2)停止&删除启动项： " keyword
        if [ -z "$keyword" ]; then
            echo "错误：没有提供关键词。"
            return 1
        fi
    fi

    echo "(2)正在查找包含 '$keyword' 的服务..."
    local services=$(systemctl list-units --type service --all | grep "$keyword" | awk '{print $1}')
    if [ -z "$services" ]; then
        echo "没有找到包含 '$keyword' 的服务。"
        return 0
    fi

    echo "(2)找到以下服务："
    echo "$services"
    
    read -p "(2)是否停止并禁用以上所有服务？(Y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        for service in $services; do
            echo "Stopping and disabling $service..."
            systemctl stop "$service"      # 停止服务
            systemctl disable "$service"   # 禁用服务
        done

        # 重新查询以验证服务是否已被成功停止和禁用
        echo "(2)验证服务已被停止和禁用..."
        services=$(systemctl list-units --type service --all | grep "$keyword" | awk '{print $1}')
        if [ -z "$services" ]; then
            echo "(2)所有与 '$keyword' 相关的服务已成功停止和禁用。"
        else
            echo "(2)以下服务未能停止或禁用："
            echo "$services"
        fi
    else
        echo "(2)操作已取消。"
    fi
}



#3 删除进程
function kill_processes() {
    local keyword=$1
    if [ -z "$keyword" ]; then
        read -p "(3)删除进程： " keyword
        if [ -z "$keyword" ]; then
            echo "(3)错误：没有提供关键词。"
            return 1
        fi
    fi
    echo "(3)正在查找包含 '$keyword' 的进程..."
    local processes=$(pgrep -fl "$keyword")
    
    if [ -z "$processes" ]; then
        echo "(3)没有找到包含 '$keyword' 的进程。"
        return 0
    fi

    echo "(3)找到以下进程："
    echo "$processes"

    # 请求用户确认是否删除
    read -p "(3)是否终止以上所有进程？(Y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo "(3)正在终止进程..."
        echo "$processes" | cut -d ' ' -f1 | xargs kill
        echo "(3)终止命令已发送。"

        # 再次验证进程是否被终止
        local remaining_processes=$(pgrep -fl "$keyword")
        if [ -z "$remaining_processes" ]; then
            echo "(3)所有包含 '$keyword' 的进程已成功终止。"
        else
            echo "(3)以下进程仍在运行："
            echo "$remaining_processes"
        fi
    else
        echo "(3)操作已取消。"
    fi
}



# 4删除所有同名的Screen
function kill_screen() {
    local keyword=$1
    if [ -z "$keyword" ]; then
        read -p "(4)输入要终止的screen会话名： " keyword
        if [ -z "$keyword" ]; then
            echo "(4)错误：没有提供关键词。"
            return 1
        fi
    fi

    echo "(4)正在查找名为 '$keyword' 的screen会话..."
    local sessions=$(screen -ls | grep "$keyword" | awk '{print $1}')
    
    if [ -z "$sessions" ]; then
        echo "(4)没有找到名为 '$keyword' 的screen会话。"
        return 0
    fi

    echo "(4)找到以下screen会话："
    echo "$sessions"

    # 请求用户确认是否删除
    read -p "(4)是否终止以上所有screen会话？(Y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo "(4)正在终止会话..."
        echo "$sessions" | xargs -n1 screen -S  -X quit
        echo "(4)终止命令已发送。"
        # 再次验证会话是否被终止
        local remaining_sessions=$(screen -ls | grep "$keyword" | awk '{print $1}')
        if [ -z "$remaining_sessions" ]; then
            echo "(4)所有名为 '$keyword' 的screen会话已成功终止。"
        else
            echo "(4)以下会话仍在运行："
            echo "$remaining_sessions"
        fi
    else
        echo "(4)操作已取消。"
    fi
}

# 5删除pm2进程
function remove_pm2() {
    local keyword=$1
    if [ -z "$keyword" ]; then
        read -p "(5)删除pm2进程的关键词： " keyword
        if [ -z "$keyword" ]; then
            echo "(5)错误：没有提供关键词。"
            return 1
        fi
    fi

    # 检查是否安装了pm2
    if ! command -v pm2 &> /dev/null; then
        echo "(5)pm2 未安装。"
        return 1
    fi

    echo "(5)正在查找包含 '$keyword' 的pm2进程..."
    local processes=$(pm2 list | grep "$keyword")

    if [ -z "$processes" ]; then
        echo "(5)没有找到包含 '$keyword' 的pm2进程。"
        return 0
    fi

    echo "(5)找到以下pm2进程："
    echo "$processes"

    # 请求用户确认是否删除
    read -p "(5)是否删除以上所有pm2进程？(Y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        # 提取进程ID并停止
        pm2 list | grep "$keyword" | awk '{print $2}' | xargs -I {} pm2 delete {}
        echo "(5)pm2进程已被删除。"
    else
        echo "(5)操作已取消。"
    fi
}


# 6删除项目的所在的文件夹
function remove_dir() {
    local keyword=$1
    if [ -z "$keyword" ]; then
        read -p "(6)删除项目的所在的文件夹： " keyword
        if [ -z "$keyword" ]; then
            echo "(6)错误：没有提供关键词。"
            return 1
        fi
    fi

    # 使用 find 和 du 命令查找文件夹并显示大小
    echo "(6)正在搜索包含关键词 '$keyword' 的所有文件夹并显示大小..."
    local directories=$(find / -type d -name "*$keyword*" 2>/dev/null)
    
    if [ -z "$directories" ]; then
        echo "(6)没有找到包含 '$keyword' 的文件夹。"
        return 0
    fi

    echo "(6)找到以下文件夹："
    echo "$directories" | xargs -I {} du -sh {} 2>/dev/null

    # 请求用户输入是否删除
    read -p "(6)是否删除以上所有文件夹？(Y/N): " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        echo "(6)正在删除文件夹..."
        echo "$directories" | xargs rm -rf
        echo "(6)文件夹已被删除。"
    else
        echo "(6)删除操作已取消。"
    fi
}

# 7执行以上全部的内容
function exe_all_remove(){
    read -p "【慎重】请选择项目关键词： " keyword
    remove_docker "$keyword" 
    remove_systemctl "$keyword" 
    kill_processes "$keyword" 
    kill_screen "$keyword" 
    remove_pm2 "$keyword" 
    remove_dir "$keyword"
}


# 调用主菜单函数以开始程序
main_menu
