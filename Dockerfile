FROM golang:1.22 as builder

WORKDIR /app

COPY . .

ENV GOPROXY=https://goproxy.cn,direct

RUN go mod tidy

RUN CGO_ENABLED=0 GOOS=linux go build --ldflags="-s -w" -o apiserverd main.go

FROM furacas/wine-vnc-box:latest

# 安装必要工具，包括 winbind（提供 ntlm_auth）
RUN sudo apt-get update && sudo apt-get install -y winbind lsof

# 验证 ntlm_auth
RUN ntlm_auth --version

# 清理环境
RUN sudo rm -rf /tmp/.X0-lock

# install lsof
RUN sudo apt-get install -y lsof

# 根据传入参数安装微信和wxhelper.dll
ARG WECHAT_URL=https://github.com/tom-snow/wechat-windows-versions/releases/download/v3.9.11.25/WeChatSetup-3.9.11.25.exe
ARG WXHELPER_URL=https://raw.githubusercontent.com/Clov614/wxapiserver/main/wxhelper.dll

WORKDIR /home/app/.wine/drive_c

COPY DllInjector.exe DllInjector.exe

# 加载注入器
RUN sudo chown app:app DllInjector.exe && sudo chmod a+x DllInjector.exe

# 下载微信
ADD ${WECHAT_URL} WeChatSetup.exe
RUN sudo chown app:app WeChatSetup.exe  && sudo chmod a+x WeChatSetup.exe

# 下载wxhelper.dll
ADD ${WXHELPER_URL} wxhelper.dll

RUN sudo chown app:app wxhelper.dll

RUN ls -lah

# 安装微信
COPY install-wechat.sh install-wechat.sh

RUN sudo chmod a+x install-wechat.sh && ./install-wechat.sh

RUN rm -rf WeChatSetup.exe && rm -rf install-wechat.sh

COPY version.exe version.exe

EXPOSE 19088 8080

COPY cmd.sh /cmd.sh

RUN sudo chmod +x /cmd.sh

COPY --from=builder /app/apiserver.conf /home/app/.wine/drive_c/apiserver.conf

COPY --from=builder /app/apiserverd /home/app/.wine/drive_c/apiserverd

CMD ["/cmd.sh"]