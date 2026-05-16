FROM registry.heroiclabs.com/heroiclabs/nakama-pluginbuilder:3.22.0 AS builder

ENV GO111MODULE=on
ENV CGO_ENABLED=1
ENV GOPROXY=https://goproxy.cn,direct

WORKDIR /server

# 第一步：先复制依赖文件
COPY go.mod go.sum ./

# 第二步：下载依赖（这一层会被缓存）
RUN go mod download

# 第三步：复制源代码（修改代码不影响缓存）
COPY . .

# 第四步：编译
RUN go build --trimpath --buildmode=plugin -o ./server.so ./modules

FROM registry.heroiclabs.com/heroiclabs/nakama:3.22.0

COPY --from=builder /server/server.so /nakama/data/modules/server.so
COPY --from=builder /server/local.yml /nakama/data/local.yml