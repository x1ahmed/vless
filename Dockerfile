FROM debian:stable-slim

# تثبيت الأدوات الأساسية
RUN apt-get update && apt-get install -y curl unzip ca-certificates bash

# تحميل Xray
RUN bash -c "curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip && \
    unzip xray.zip && \
    mv xray /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm -rf xray.zip"

# الإعدادات الافتراضية
ENV UUID=8442ff27-8e79-4f27-b4d2-c3e6447789ea
ENV WS_PATH=/vless-ws
ENV PORT=8080
ENV SNI=api.epicgames.dev

# بناء سكربت التشغيل سطر بسطر لتجنب أخطاء الـ EOF
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-"your-app.up.railway.app"}' >> /start.sh && \
    echo 'printf "{\n  \"log\": {\"loglevel\": \"none\"},\n  \"inbounds\": [{\n    \"port\": %s,\n    \"protocol\": \"vless\",\n    \"settings\": {\"clients\": [{\"id\": \"%s\"}], \"decryption\": \"none\"},\n    \"streamSettings\": {\"network\": \"ws\", \"wsSettings\": {\"path\": \"%s\"}}\n  }],\n  \"outbounds\": [{\"protocol\": \"freedom\"}]\n}" "$PORT" "$UUID" "$WS_PATH" > /etc/config.json' >> /start.sh && \
    echo 'echo "---------------------------------------------------------------"' >> /start.sh && \
    echo 'echo "VLESS LINK:"' >> /start.sh && \
    echo 'echo "vless://$UUID@$DOMAIN:443?path=${WS_PATH//\//%2F}&security=tls&encryption=none&type=ws&sni=$SNI#Railway-VLESS"' >> /start.sh && \
    echo 'echo "---------------------------------------------------------------"' >> /start.sh && \
    echo 'exec xray -config /etc/config.json' >> /start.sh && \
    chmod +x /start.sh

# فتح البورت
EXPOSE $PORT

# تشغيل السكربت
CMD ["/bin/bash", "/start.sh"]
