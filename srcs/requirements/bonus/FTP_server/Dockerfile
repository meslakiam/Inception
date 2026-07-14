FROM debian:bookworm

RUN apt-get update && \
    apt-get install -y vsftpd && \
    apt-get clean

COPY conf/vsftpd.conf /etc/vsftpd.conf


COPY tools/setup.sh /setup.sh

RUN chmod +x /setup.sh

ENTRYPOINT ["/setup.sh"]