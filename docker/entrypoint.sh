#!/usr/bin/env bash
# 用法：
#   entrypoint.sh login     启动虚拟桌面 + VNC，扫码登录并把 Cookie 写入 /app/data/cookies.json
#   entrypoint.sh seckill   运行 snap_up_server.py 抢购（默认）
#   entrypoint.sh python xx 其他命令直接透传
set -euo pipefail

cd /app

case "${1:-seckill}" in
  login)
    export DISPLAY=:99
    echo "[login] 启动虚拟桌面 Xvfb :99 ..."
    Xvfb :99 -screen 0 1400x900x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
    sleep 1

    echo "[login] 启动 VNC 服务（5900）与 noVNC 网页（6080）..."
    x11vnc -display :99 -nopw -forever -shared -rfbport 5900 -quiet >/tmp/x11vnc.log 2>&1 &
    websockify --web /usr/share/novnc 6080 127.0.0.1:5900 >/tmp/websockify.log 2>&1 &
    sleep 1

    cat <<'EOF'
--------------------------------------------------------------
请用浏览器打开： http://<服务器IP>:6080/vnc.html?autoconnect=1
（本机运行则是 http://localhost:6080/vnc.html?autoconnect=1）
页面里会出现腾讯云登录二维码 —— 用手机扫码完成登录。
Cookie 保存到 /app/data/cookies.json 后本进程会停在
Playwright Inspector，看到该文件后即可停止容器。
--------------------------------------------------------------
EOF
    exec python get_cookies.py
    ;;

  seckill)
    if [ ! -s /app/data/cookies.json ]; then
      echo "[error] 未找到 /app/data/cookies.json" >&2
      echo "[error] 请先运行 login 模式扫码获取 Cookie，或把已有 cookies.json 放到宿主机 ./data/ 目录" >&2
      exit 1
    fi
    exec python snap_up_server.py
    ;;

  *)
    exec "$@"
    ;;
esac
