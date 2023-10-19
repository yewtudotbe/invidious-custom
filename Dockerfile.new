FROM alpine:3.18 AS builder
RUN apk add --no-cache 'crystal=1.8.2-r0' shards sqlite-static yaml-static yaml-dev libxml2-static zlib-static openssl-libs-static openssl-dev musl-dev xz-static yq

ARG add_build_args

WORKDIR /invidious
COPY ./invidious/shard.yml ./shard.yml
COPY ./invidious/shard.lock ./shard.lock
# Sentry is just for reporting Invidious crashes, no personal data is collected.
#RUN yq e -i '.dependencies.raven.github = "Sija/raven.cr"' shard.yml
#RUN yq e -i '.targets.sentry_crash_handler.main = "lib/raven/src/crash_handler.cr"' shard.yml
RUN shards install --production

COPY --from=quay.io/invidious/lsquic-compiled /root/liblsquic.a ./lib/lsquic/src/lsquic/ext/liblsquic.a

COPY ./invidious/src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./invidious/.git/ ./.git/
# Required for fetching player dependencies
COPY ./invidious/scripts/ ./scripts/
COPY ./invidious/assets/ ./assets/
COPY ./invidious/videojs-dependencies.yml ./videojs-dependencies.yml
RUN crystal build ./src/invidious.cr ${add_build_args} \
        --release \
        -Ddisable_quic \
        --static --warnings all \
        --link-flags "-lxml2 -llzma";

#RUN shards build --release --static sentry_crash_handler

FROM alpine:3.16
RUN apk add --no-cache librsvg ttf-opensans tini
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY --chown=invidious ./invidious/config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: postgres/' config/config.yml
COPY ./invidious/config/sql/ ./config/sql/
COPY ./invidious/locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .
#COPY --from=builder /invidious/bin/sentry_crash_handler .
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
#CMD [ "/invidious/sentry_crash_handler", "/invidious/invidious" ]
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]
