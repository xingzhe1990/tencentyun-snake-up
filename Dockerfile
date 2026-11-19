# 腾讯云秒杀工具镜像
# 基于 README：Python 3.8+ / playwright + chromium / requests
FROM python:3.8-slim

# 时区固定为北京时间，保证秒杀时间判断与本地一致
ENV TZ=Asia/Shanghai \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DISPLAY=:99 \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

# xvfb/x11vnc/novnc：容器内跑「有界面」浏览器扫码登录
# tini：正确转发信号，避免 Xvfb / 浏览器进程僵死
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tini \
        xvfb \
        x11vnc \
        novnc \
        websockify \
        fonts-wqy-zenhei \
    && rm -rf /var/lib/apt/lists/*

# 国内网络可用清华源加速；海外环境可传 --build-arg PIP_INDEX_URL=https://pypi.org/simple
ARG PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# 先装依赖，利用 Docker 层缓存
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -i "${PIP_INDEX_URL}" -r requirements.txt

# 安装 chromium 及其系统依赖（playwright 自带 install-deps）
RUN playwright install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*

# 业务代码（.dockerignore 已排除 .git / .idea / data / cookies.json）
COPY . /app

# Cookie 落在挂载卷里，容器重建不丢登录态
RUN mkdir -p /app/data && ln -sfn /app/data/cookies.json /app/cookies.json

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# 默认直接跑秒杀；login 模式跑扫码取 Cookie
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["seckill"]
