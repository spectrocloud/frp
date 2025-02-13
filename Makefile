export PATH := $(GOPATH)/bin:$(PATH)
export GO111MODULE=on
LDFLAGS := -s -w
TARGETARCH ?= amd64
FRPC_IMG ?= "gcr.io/spectro-dev-public/${USER}/frpc:latest"
FRPS_IMG ?= "gcr.io/spectro-dev-public/${USER}/frps:latest"
FIPS_ENABLE ?= ""
GOLANG_VERSION?=1.23
ifeq ($(FIPS_ENABLE),yes)
	FRPC_IMG := "gcr.io/spectro-dev-public/${USER}/fips/frpc:latest"
	FRPS_IMG := "gcr.io/spectro-dev-public/${USER}/fips/frps:latest"
endif
BUILD_ARGS = --build-arg CRYPTO_LIB=${FIPS_ENABLE} --build-arg GOLANG_VERSION=${GOLANG_VERSION}

all: fmt build

build: frps frpc

# compile assets into binary file
file:
	rm -rf ./assets/frps/static/*
	rm -rf ./assets/frpc/static/*
	cp -rf ./web/frps/dist/* ./assets/frps/static
	cp -rf ./web/frpc/dist/* ./assets/frpc/static

fmt:
	go fmt ./...

vet:
	go vet ./...

frps:
	env CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/frps ./cmd/frps

ARCHS ?= amd64 arm64

docker-frps:
	docker buildx build --platform linux/${TARGETARCH} --load . -t ${FRPS_IMG} -f build/frps/Dockerfile
	docker push ${FRPS_IMG}

docker-cross: docker-build-cross-frpc docker-build-cross-frps

docker-build-cross-frps:
	docker buildx build --platform linux/amd64,linux/arm64 --push . -t ${FRPS_IMG} ${BUILD_ARGS} -f build/frps/Dockerfile

docker-build-cross-frpc:
	docker buildx build --platform linux/amd64,linux/arm64 --push . -t ${FRPC_IMG} ${BUILD_ARGS} -f build/frpc/Dockerfile

frpc:
	env CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/frpc ./cmd/frpc

docker-frpc:
	docker buildx build --platform linux/${TARGETARCH} --load . -t ${FRPC_IMG} -f build/frpc/Dockerfile
	docker push ${FRPC_IMG}

test: gotest

gotest:
	go test -v --cover ./assets/...
	go test -v --cover ./cmd/...
	go test -v --cover ./client/...
	go test -v --cover ./server/...
	go test -v --cover ./pkg/...

e2e:
	./hack/run-e2e.sh

e2e-trace:
	DEBUG=true LOG_LEVEL=trace ./hack/run-e2e.sh

alltest: vet gotest e2e
	
clean:
	rm -f ./bin/frpc
	rm -f ./bin/frps
