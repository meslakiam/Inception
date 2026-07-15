FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y \
        curl \
        ca-certificates \
        gnupg && \
    curl -fsSL https://repo.netdata.cloud/netdatabot.gpg.key | \
        gpg --dearmor -o /usr/share/keyrings/netdata-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/netdata-archive-keyring.gpg] https://repo.netdata.cloud/repos/stable/debian/ bookworm/" \
        > /etc/apt/sources.list.d/netdata.list && \
    apt-get update && \
    apt-get install -y netdata

COPY conf/netdata.conf /etc/netdata/netdata.conf

EXPOSE 19999

CMD ["/usr/sbin/netdata", "-D"]