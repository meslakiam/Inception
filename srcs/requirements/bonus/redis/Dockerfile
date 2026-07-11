From debian:bookworm


RUN apt-get update && \
    apt-get install -y redis-server && \
    apt-get clean

COPY conf/redis.conf /etc/redis/redis.conf

CMD ["redis-server", "/etc/redis/redis.conf"]