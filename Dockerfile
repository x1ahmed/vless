FROM alpine:latest

# تثبيت الأدوات اللازمة
RUN apk add --no-cache curl bash jq

# تحميل أحدث إصدار من Xray
RUN bash -c "curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -o xray.zip && \
    unzip xray.zip && \
    mv xray /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm -rf xray.zip geoip.dat geosite.dat"

# إعداد المتغيرات (يمكنك تغيير الـ UUID من إعدادات Railway)
ENV UUID=8442ff27-8e79-4f27-b4d2-c3e6447789ea
ENV WS_PATH=/vless-ws
ENV PORT=8080
ENV SNI=api.epicgames.dev

# إنشاء سكريبت التشغيل وتوليد الرابط
RUN echo '#!/bin/bash \n\
# جلب الدومين الخاص بـ Railway \n\
DOMAIN=${RAILWAY_PUBLIC_DOMAIN:-"your-app.up.railway.app"} \n\
\n\
# إنشاء ملف config.json \n\
cat <<EOF > /etc/config.json \n\
{ \n\
    "log": {"loglevel": "none"}, \n\
    "inbounds": [{ \n\
        "port": $PORT, \n\
        "protocol": "vless", \n\
        "settings": { \n\
            "clients": [{"id": "$UUID"}], \n\
            "decryption": "none" \n\
        }, \n\
        "streamSettings": { \n\
            "network": "ws", \n\
            "wsSettings": {"path": "$WS_PATH"} \n\
        } \n\
    }], \n\
    "outbounds": [{"protocol": "freedom"}] \n\
} \n\
EOF \n\
\n\
# توليد رابط VLESS مع SNI \n\
echo -e "\n\n--- VLESS LINK READY ---" \n\
echo "vless://$UUID@\$DOMAIN:443?path=\${WS_PATH//\//%2F}&security=tls&encryption=none&type=ws&sni=$SNI#Railway-EpicGames" \n\
echo -e "------------------------\n\n" \n\
\n\
# تشغيل البرنامج \n\
exec xray -config /etc/config.json' > /start.sh && chmod +x /start.sh

# فتح البورت (Railway سيوجهه تلقائياً)
EXPOSE $PORT

CMD ["/bin/bash", "/start.sh"]
