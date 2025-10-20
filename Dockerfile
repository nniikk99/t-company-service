FROM nginx:alpine

# Копируем статические файлы
COPY . /usr/share/nginx/html

# Настраиваем nginx для правильной работы с Telegram Mini App
RUN echo 'server {' > /etc/nginx/conf.d/default.conf && \
    echo '    listen 80;' >> /etc/nginx/conf.d/default.conf && \
    echo '    server_name localhost;' >> /etc/nginx/conf.d/default.conf && \
    echo '    root /usr/share/nginx/html;' >> /etc/nginx/conf.d/default.conf && \
    echo '    index index.html;' >> /etc/nginx/conf.d/default.conf && \
    echo '    location / {' >> /etc/nginx/conf.d/default.conf && \
    echo '        try_files $uri $uri/ /index.html;' >> /etc/nginx/conf.d/default.conf && \
    echo '        add_header X-Frame-Options "ALLOWALL";' >> /etc/nginx/conf.d/default.conf && \
    echo '        add_header Content-Security-Policy "frame-ancestors '\''self'\'' https://web.telegram.org https://telegram.org https://*.telegram.org https://t.me https://*.t.me;";' >> /etc/nginx/conf.d/default.conf && \
    echo '    }' >> /etc/nginx/conf.d/default.conf && \
    echo '}' >> /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
