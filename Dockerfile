FROM golang:1.22 as builder

# 构建 Go 应用程序
WORKDIR /app
COPY . .
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build --ldflags="-s -w" -o apiserverd main.go

# 基础镜像
FROM furacas/wine-vnc-box:latest

# 安装必要工具，包括 winbind（提供 ntlm_auth）和 lsof
RUN sudo apt-get update && \
    sudo apt-get install -y winbind lsof && \
    sudo apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 验证 ntlm_auth 安装
RUN ntlm_auth --version

# 清理 X 服务器的临时文件
RUN sudo rm -rf /tmp/.X0-lock

# 根据传入参数安装微信和 wxhelper.dll
ARG WECHAT_URL=https://github.com/tom-snow/wechat-windows-versions/releases/download/v3.9.8.25/WeChatSetup-3.9.8.25.exe
ARG WXHELPER_URL=https://github.com/ttttupup/wxhelper/releases/download/3.9.8.25-v2/wxhelper.dll

WORKDIR /home/app/.wine/drive_c

# 添加并设置 DllInjector
COPY DllInjector.exe DllInjector.exe
RUN sudo chown app:app DllInjector.exe && sudo chmod a+x DllInjector.exe

# 下载微信安装包
ADD ${WECHAT_URL} WeChatSetup.exe
RUN sudo chown app:app WeChatSetup.exe && sudo chmod a+x WeChatSetup.exe

# 下载 wxhelper.dll
ADD ${WXHELPER_URL} wxhelper.dll
RUN sudo chown app:app wxhelper.dll

# 打印目录内容，调试用
RUN ls -lah

# 安装微信
COPY install-wechat.sh install-wechat.sh
RUN sudo chmod a+x install-wechat.sh && ./install-wechat.sh

# 清理安装文件
RUN rm -rf WeChatSetup.exe install-wechat.sh

# 添加 version.exe
COPY version.exe version.exe

# 暴露端口
EXPOSE 5900 19088

# 添加启动脚本
COPY cmd.sh /cmd.sh
RUN sudo chmod +x /cmd.sh

# 添加 Go 构建产物
COPY --from=builder /app/apiserver.conf /home/app/.wine/drive_c/apiserver.conf
COPY --from=builder /app/apiserverd /home/app/.wine/drive_c/apiserverd

# 启动容器时执行 cmd.sh
CMD ["/cmd.sh"]
