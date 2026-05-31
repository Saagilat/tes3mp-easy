FROM debian:11-slim

RUN apt-get update && apt-get install -y \
    libluajit-5.1-2 \
    libcurl4 \
    libssl1.1 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tes3mp

# Download and extract TES3MP server tarball
ARG TES3MP_URL=https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.1/tes3mp-server-GNU+Linux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz

ADD "${TES3MP_URL}" /tmp/tes3mp.tar.gz
RUN tar --strip-components=1 -xzf /tmp/tes3mp.tar.gz -C /tes3mp \
    && rm -f /tmp/tes3mp.tar.gz

# Copy entrypoint
COPY entrypoint.sh /tes3mp/entrypoint.sh
RUN chmod +x /tes3mp/entrypoint.sh

ENTRYPOINT ["/tes3mp/entrypoint.sh"]

EXPOSE 25565/tcp
EXPOSE 25565/udp