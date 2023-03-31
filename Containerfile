FROM quay.io/polyglotsystems/golang-ubi:latest AS builder

WORKDIR /workspace

COPY . /workspace

RUN cd /workspace/site \
 && /workspace/bin/set_git_hash.sh \
 && cd /workspace/bin/ \
 && /workspace/bin/process_images.sh /workspace/site/static/images/ \
 && cd /workspace/site \
 && /workspace/bin/hugo-linux-amd64

#FROM quay.io/polyglotsystems/ubi8-nginx:latest
FROM registry.access.redhat.com/ubi9/nginx-120:latest

#COPY --from=builder /workspace/site/public /var/www/html
COPY --from=builder /workspace/site/public /opt/app-root/src

EXPOSE 8080

USER 1001

CMD nginx -g "daemon off;"