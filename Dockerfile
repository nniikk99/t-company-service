FROM nginx:alpine

# Копируем статические файлы
COPY . /usr/share/nginx/html

# Настраиваем nginx: по умолчанию открывать app.html, затем index.html
RUN sed -i 's/index  index.html;/index  app.html index.html;/' /etc/nginx/conf.d/default.conf || true

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
