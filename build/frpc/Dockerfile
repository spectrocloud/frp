# Build the manager binary
ARG GOLANG_VERSION
FROM us-docker.pkg.dev/palette-images/build-base-images/golang:${GOLANG_VERSION}-alpine as builder

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
RUN --mount=type=cache,sharing=locked,id=gomod,target=/go/pkg/mod/cache \
    --mount=type=cache,sharing=locked,id=goroot,target=/root/.cache/go-build \
    if [ ${CRYPTO_LIB} ]; \
    then \
    go-build-fips.sh -a -o frpc cmd/frpc/main.go ;\
    else \
    go-build-static.sh -a -o frpc cmd/frpc/main.go ;\
    fi

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/frpc .

ENTRYPOINT ["/frpc"]
