from nginx

EXPOSE 8000
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y git ldc make gcc
RUN git clone https://github.com/now-run/now.git \
    && cd now \
    && make \
    && cp dist/now /usr/bin
