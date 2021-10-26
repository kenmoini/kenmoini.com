FROM quay.io/polyglotsystems/golang-ubi AS builder

WORKDIR /workspace

COPY . /workspace

RUN cd /workspace/site \
 && ../bin/hugo-linux-amd64

FROM quay.io/polyglotsystems/ubi8-nginx

COPY --from=builder /workspace/site/public /var/www/html

EXPOSE 8080