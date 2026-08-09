---
title: "Docker Compose 双容器部署 AI 聊天：Nginx + Flask 实战"
date: 2026-08-10T12:00:00+08:00
draft: false
tags: ["Docker", "Nginx", "DeepSeek", "AI"]
summary: "在 Docker Compose 中用两个容器分别运行 Nginx 和 Flask，同一网络下通过容器名互访，接入 DeepSeek API 实现 AI 聊天功能。记录踩坑全过程。"
---

## 目标

给博客加一个 AI 聊天功能，后端用 Flask 代理 DeepSeek API，前端用 DaisyUI 聊天组件，整体通过 Docker Compose 部署。

## 架构

```
浏览器 → Nginx(:443) → /api/chat → Flask(:5000) → DeepSeek API
         容器 blog                 容器 ai-bot
          └──────── 同一 Docker 网络 ────────┘
```

## docker-compose.yml

```yaml
services:
  blog:
    image: nginx:1.27-alpine
    container_name: blog
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/blog/site:/usr/share/nginx/html:ro
      - /opt/blog/nginx/blog.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt/live/www.lihuanyu.icu/fullchain.pem:/etc/ssl/certs/fullchain.pem:ro
      - /etc/letsencrypt/live/www.lihuanyu.icu/privkey.pem:/etc/ssl/private/privkey.pem:ro
    restart: unless-stopped

  ai-bot:
    image: python:3.12-slim
    container_name: ai-bot
    working_dir: /app
    command: sh -c "pip install flask openai -q -i https://mirrors.aliyun.com/pypi/simple/ && python server.py"
    environment:
      - DEEPSEEK_KEY=sk-xxxxxxxx
    volumes:
      - /opt/ai-bot/server.py:/app/server.py:ro
    restart: unless-stopped
```

关键设计点：
- **同一个 compose 文件**：两个容器自动加入同一个 Docker 网络
- **容器名访问**：Nginx 直接 `proxy_pass http://ai-bot:5000`，Docker DNS 自动解析
- **镜像选择**：`python:3.12-slim` 而非 `alpine`，pip 安装更快
- **pip 镜像**：`-i https://mirrors.aliyun.com/pypi/simple/` 国内加速

## Nginx 路由配置

```nginx
location /api/chat {
    proxy_pass http://ai-bot:5000/chat;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

## Flask 后端

```python
from flask import Flask, request, jsonify
from openai import OpenAI
import os

app = Flask(__name__)

@app.route("/chat", methods=["POST"])
def chat():
    data = request.get_json()
    msg = data.get("message", "")
    client = OpenAI(
        api_key=os.environ.get("DEEPSEEK_KEY"),
        base_url="https://api.deepseek.com"
    )
    r = client.chat.completions.create(
        model="deepseek-chat",
        messages=[
            {"role": "system", "content": "你是半亩方塘博客的AI助手。"},
            {"role": "user", "content": msg}
        ],
        max_tokens=1000
    )
    return jsonify({"reply": r.choices[0].message.content})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
```

要点：
- `host="0.0.0.0"`：在容器内必须监听所有接口，否则其他容器连不上
- `DEEPSEEK_KEY` 通过环境变量注入，不写死在代码里

## 前端聊天组件

使用 DaisyUI 的 `chat` 系列类名：

- `chat chat-start`：左对齐气泡（AI 回复）
- `chat chat-end`：右对齐气泡（用户消息）
- `chat-bubble`：聊天气泡容器
- `input input-bordered`：输入框
- `btn btn-primary`：发送按钮

AI 回复加了打字机效果：

```javascript
function typeWriter(el, text, speed) {
  el.textContent = "";
  let i = 0;
  function type() {
    if (i < text.length) {
      el.textContent += text.charAt(i);
      i++;
      setTimeout(type, speed);
    }
  }
  type();
}
```

## 踩坑记录

### 坑 1：Docker 网络隔离

最初把 Flask 跑在宿主机，Nginx 跑在容器里。尝试了 `172.17.0.1`、`172.18.0.1`、`host.docker.internal`、iptables 放行——全部失败。

**根因**：阿里云 ECS 的 iptables 策略是 `FORWARD DROP`，容器到宿主机的流量被拦截。

**解决**：不跨网络。两个容器放同一个 compose 文件，自动共享网络，容器名互访。

### 坑 2：Alpine 镜像 pip 安装慢

`python:3.12-alpine` 需要先装编译工具链，下载 20 多个包，耗时 400+ 秒。

**解决**：换 `python:3.12-slim`，pip 直接装在预编译环境，30 秒搞定。

### 坑 3：Flask 监听 127.0.0.1

容器内 `app.run(host="127.0.0.1")` 只接受本容器连接，其他容器连不上。

**解决**：改成 `host="0.0.0.0"`。

## 部署命令

```bash
cd /opt/blog
sudo docker compose down
sudo docker compose up -d

# 验证
curl -s https://www.lihuanyu.icu/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"你好"}'
```

## 总结

Docker Compose 多容器部署的核心原则：**同一 compose 文件、同一网络、容器名互访**。别再跨网络折腾 iptables 了。
