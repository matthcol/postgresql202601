ARG DB_TAG=latest
FROM postgis/postgis:${DB_TAG}

RUN apt update && apt install -y vim net-tools iproute2 postgis

COPY docker-entrypoint-initdb.d /docker-entrypoint-initdb.d