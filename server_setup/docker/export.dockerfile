FROM alpine:latest

RUN apk add --no-cache bash tar socat

COPY package.sh /app/package.sh
COPY export_server.sh /app/export_server.sh
RUN chmod +x /app/*.sh

CMD ["bash", "/app/export_server.sh"]