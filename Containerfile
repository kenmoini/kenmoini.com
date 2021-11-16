FROM quay.io/polyglotsystems/golang-ubi:latest AS builder

WORKDIR /workspace

COPY . /workspace

RUN cd /workspace/site \
 && /workspace/bin/set_git_hash.sh \
 && /workspace/bin/process_images.sh /workspace/site/static/images/ \
 && /workspace/bin/hugo-linux-amd64

FROM quay.io/polyglotsystems/ubi8-nginx:latest

COPY --from=builder /workspace/site/public /var/www/html

EXPOSE 8080

USER 1001