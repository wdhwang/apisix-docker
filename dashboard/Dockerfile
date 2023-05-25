ARG BUILDPLATFORM=amd64

FROM --platform=$BUILDPLATFORM alpine:latest as pre-build
ARG APISIX_DASHBOARD_TAG=v3.0.0
RUN set -x \
    && apk update \
    && apk upgrade \
    && apk add --no-cache --virtual .builddeps git \
    && git clone https://github.com/apache/apisix-dashboard.git -b ${APISIX_DASHBOARD_TAG} /usr/local/apisix-dashboard \
    && cd /usr/local/apisix-dashboard && git clean -Xdf \
    && rm -f ./.githash && git log --pretty=format:"%h" -1 > ./.githash

FROM --platform=$BUILDPLATFORM golang:1.19 as api-builder
ARG ENABLE_PROXY=false
WORKDIR /usr/local/apisix-dashboard
COPY --from=pre-build /usr/local/apisix-dashboard .
ARG TARGETOS
ARG TARGETARCH
RUN if [ "$ENABLE_PROXY" = "true" ] ; then go env -w GOPROXY=https://goproxy.io,direct ; fi \
    && go env -w GO111MODULE=on \
    && CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} ./api/build.sh

FROM --platform=$BUILDPLATFORM node:14-alpine as fe-builder
ARG ENABLE_PROXY=false
WORKDIR /usr/local/apisix-dashboard
COPY --from=pre-build /usr/local/apisix-dashboard .
WORKDIR /usr/local/apisix-dashboard/web
RUN yarn install \
    && cp ./node_modules/@ant-design/pro-provider/lib/locale/en_US.js ./node_modules/@ant-design/pro-provider/lib/locale/zh_CN.js \
    && cp ./node_modules/@ant-design/pro-provider/es/locale/en_US.js ./node_modules/@ant-design/pro-provider/es/locale/zh_CN.js \
    && yarn build

FROM alpine:latest as prod
WORKDIR /usr/local/apisix-dashboard
COPY --from=api-builder /usr/local/apisix-dashboard/output/ ./
COPY --from=fe-builder /usr/local/apisix-dashboard/output/ ./
RUN mkdir -p logs
RUN mkdir -p html/swagger
COPY ./swagger-ui-4.18.1/dist/ /usr/local/apisix-dashboard/html/swagger/
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
RUN set -x \
    && apk update \
    && apk add yq jq curl
COPY ./exportOpenAPI.sh /usr/local/apisix-dashboard
RUN chmod 755 exportOpenAPI.sh
RUN echo "*       *       *       *       *       /usr/local/apisix-dashboard/exportOpenAPI.sh" >> /etc/crontabs/root

EXPOSE 9000

ENTRYPOINT /usr/sbin/crond -bS -L /dev/null && /usr/local/apisix-dashboard/manager-api
#CMD /usr/sbin/crond -bS -L /dev/null && /usr/local/apisix-dashboard/manager-api
