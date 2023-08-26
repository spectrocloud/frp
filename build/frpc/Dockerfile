# Build the manager binary

FROM --platform=$TARGETPLATFORM gcr.io/spectro-images-public/golang:1.19-alpine as builder

ARG TARGETOS
ARG TARGETARCH
ARG CRYPTO_LIB
ENV GOEXPERIMENT=${CRYPTO_LIB:+boringcrypto}

RUN apk update
RUN apk add curl git gcc g++ 

ADD .netrc /root/.netrc

RUN chmod 600 /root/.netrc

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY . .

# Build
RUN if [ ${CRYPTO_LIB} ]; \
    then \
    CGO_ENABLED=1 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GO111MODULE=on go build -ldflags "-linkmode=external -extldflags=-static" -a -o frpc cmd/frpc/main.go; \
    else \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} GO111MODULE=on go build -a -o frpc cmd/frpc/main.go; \
    fi

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM --platform=$TARGETPLATFORM gcr.io/distroless/static:latest
WORKDIR /
COPY --from=builder /workspace/frpc .

ENTRYPOINT ["/frpc"]