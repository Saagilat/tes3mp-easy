FROM alpine:latest

RUN apk add --no-cache bash tar socat

COPY export_server.sh /app/export_server.sh
RUN chmod +x /app/export_server.sh

CMD ["bash", "/app/export_server.sh"]