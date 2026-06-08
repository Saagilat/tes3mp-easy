FROM alpine:latest

RUN apk add --no-cache bash tar socat rhash jq docker

COPY scripts/package.sh /app/package.sh
COPY scripts/list-backups.sh /app/list-backups.sh
COPY export_server.sh /app/export_server.sh
RUN chmod +x /app/*.sh

CMD ["bash", "/app/export_server.sh"]
