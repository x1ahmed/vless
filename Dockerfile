FROM alpine:latest

# 1. تثبيت الحزم المطلوبة
RUN apk add --no-cache curl unzip ca-certificates

# 2. تحميل وتثبيت أحدث إصدار من Xray-core تلقائياً حسب المعمارية
RUN ARCH=$(uname -m) && \
    case "${ARCH}" in \
        x86_64) XARCH="64" ;; \
        aarch64) XARCH="arm64-v8a" ;; \
        *) XARCH="64" ;; \
    esac && \
    curl -Lo /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XARCH}.zip && \
    unzip /tmp/xray.zip -d /tmp/xray && \
    mv /tmp/xray/xray /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    mkdir -p /etc/xray && \
    rm -rf /tmp/xray*

# 3. إنشاء سكريبت التشغيل التلقائي وكتابة الإعدادات داخل نفس الملف
RUN cat <<'EOF' > /entrypoint.sh
#!/bin/sh
set -e

# قراءة البورت من Railway أو استخدام 8080 كافتراضي
PORT="${PORT:-8080}"

# استخدام UUID المحدد في البيئة أو توليد واحد جديد تلقائياً
if [ -z "$UUID" ]; then
    UUID=$(/usr/local/bin/xray uuid)
fi

# مسار الـ WebSocket
WSPATH="${WSPATH:-/vless}"

# إنشاء ملف config.json ديناميكياً
cat <<JSON > /etc/xray/config.json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": ${PORT},
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${WSPATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
JSON

# جلب اسم الدومين من متغيرات Railway تلقائياً
DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-${RAILWAY_STATIC_URL:-your-domain.up.railway.app}}"
ENCODED_PATH=$(echo "$WSPATH" | sed 's/\//%2F/g')

# بناء رابط VLESS الجاهز
VLESS_LINK="vless://${UUID}@${DOMAIN}:443?path=${ENCODED_PATH}&security=tls&encryption=none&type=ws#Railway-VLESS"

# طباعة البيانات ورابط الاتصال في الـ Deploy Logs
echo ""
echo "=================================================================="
echo "🚀 Xray VLESS (WebSocket + TLS) is Running!"
echo "=================================================================="
echo "🔑 UUID: ${UUID}"
echo "🌐 Domain: ${DOMAIN}"
echo "------------------------------------------------------------------"
echo "🔗 COPY YOUR VLESS LINK BELOW:"
echo ""
echo "${VLESS_LINK}"
echo ""
echo "=================================================================="
echo ""

# تشغيل Xray
exec /usr/local/bin/xray run -config /etc/xray/config.json
EOF

RUN chmod +x /entrypoint.sh

# 4. تشغيل السكريبت عند بدء الـ Container
ENTRYPOINT ["/entrypoint.sh"]
