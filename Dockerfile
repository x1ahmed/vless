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

# إنشاء سكربت التشغيل مباشرة
RUN echo '#!/bin/bash \n\
# تحديد الدومين (Railway يوفر PUBLIC_DOMAIN تلقائيا) \n\
DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-$RAILWAY_TCP_PROXY_DOMAIN} \n\
[ -z "$DOMAIN" ] && DOMAIN="your-app.up.railway.app" \n\
\n\
# إنشاء الإعدادات \n\
cat <<EOF > /etc/config.json \n\
{ \n\
    "log": {"loglevel": "warning"}, \n\
    "inbounds": [{ \n\
        "port": '$PORT', \n\
        "protocol": "vless", \n\
        "settings": { \n\
            "clients": [{"id": "'$UUID'"}], \n\
            "decryption": "none" \n\
        }, \n\
        "streamSettings": { \n\
            "network": "ws", \n\
            "wsSettings": {"path": "'$WS_PATH'"} \n\
        } \n\
    }], \n\
    "outbounds": [{"protocol": "freedom"}] \n\
} \n\
EOF \n\
\n\
# طباعة الرابط في اللوجات \n\
echo "---------------------------------------------------------------" \n\
echo "VLESS LINK:" \n\
echo "vless://$UUID@\$DOMAIN:443?path=${WS_PATH//\//%2F}&security=tls&encryption=none&type=ws&sni=$SNI#Railway-VLESS" \n\
echo "---------------------------------------------------------------" \n\
\n\
# تشغيل Xray وجعله في الواجهة لضمان بقاء الحاوية Online \n\
exec /usr/local/bin/xray -config /etc/config.json' > /start.sh && chmod +x /start.sh

# إخبار Railway بالبورت المستخدم
EXPOSE $PORT

# البدء
CMD ["/bin/bash", "/start.sh"]
