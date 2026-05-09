FROM registry.heroiclabs.com/heroiclabs/nakama-pluginbuilder:3.22.0 AS builder

ENV GO111MODULE=on
ENV CGO_ENABLED=1

WORKDIR /server
COPY . .

RUN go build --trimpath --buildmode=plugin -o ./server.so ./modules

FROM registry.heroiclabs.com/heroiclabs/nakama:3.22.0

COPY --from=builder /server/server.so /nakama/data/modules/server.so
COPY --from=builder /server/local.yml /nakama/data/local.yml
