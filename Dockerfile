FROM crystallang/crystal:1.4.1-alpine AS builder
RUN apk add --no-cache sqlite-static yaml-static

WORKDIR /invidious
COPY ./invidious/shard.yml ./shard.yml
COPY ./invidious/shard.lock ./shard.lock
RUN shards update --production && shards install --production

COPY --from=quay.io/invidious/lsquic-compiled /root/liblsquic.a ./lib/lsquic/src/lsquic/ext/liblsquic.a

COPY ./invidious/src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./invidious/.git/ ./.git/
# Required for fetching player dependencies
COPY ./invidious/scripts/ ./scripts/
COPY ./invidious/assets/ ./assets/
COPY ./invidious/videojs-dependencies.yml ./videojs-dependencies.yml
RUN crystal build --release ./src/invidious.cr \
    --static --warnings all \
    --link-flags "-lxml2 -llzma"

FROM alpine:latest
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
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]