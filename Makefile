export PATH := $(GOPATH)/bin:$(PATH)
export GO111MODULE=on
LDFLAGS := -s -w
FRPC_IMG ?= "gcr.io/spectro-common-dev/${USER}/frpc:latest"
FRPS_IMG ?= "gcr.io/spectro-common-dev/${USER}/frps:latest"
TARGETARCH ?= amd64

all: fmt build

build: frps frpc

# compile assets into binary file
file:
	rm -rf ./assets/frps/static/*
	rm -rf ./assets/frpc/static/*
	cp -rf ./web/frps/dist/* ./assets/frps/static
	cp -rf ./web/frpc/dist/* ./assets/frpc/static
	rm -rf ./assets/frps/statik
	rm -rf ./assets/frpc/statik
	go generate ./assets/...

fmt:
	go fmt ./...

frps:
	env CGO_ENABLED=0 go build -trimpath -ldflags "$(LDFLAGS)" -o bin/frps ./cmd/frps

ARCHS ?= amd64 arm64

docker-frps:
	docker buildx build --platform linux/${TARGETARCH} --load . -t ${FRPS_IMG} -f build/frps/Dockerfile
	docker push ${FRPS_IMG}

docker-cross: docker-build-cross docker-push-cross docker-manifest-cross-arch

docker-build-cross:
	for arch in ${ARCHS} ; do \
		docker buildx build --platform linux/$$arch --load . -t ${FRPS_IMG}-linux-$$arch -f build/frps/Dockerfile ; \
		docker buildx build --platform linux/$$arch --load . -t ${FRPC_IMG}-linux-$$arch -f build/frps/Dockerfile ; \
	done

docker-push-cross:
	for arch in ${ARCHS} ; do \
		docker push ${FRPS_IMG}-linux-$$arch ; \
		docker push ${FRPC_IMG}-linux-$$arch ; \
	done

docker-manifest-cross-arch:
	for arch in ${ARCHS} ; do \
		docker manifest create --amend ${FRPS_IMG} ${FRPS_IMG}-linux-$$arch ; \
		docker manifest annotate ${FRPS_IMG} ${FRPS_IMG}-linux-$$arch --arch $$arch ; \
		docker manifest create --amend ${FRPC_IMG} ${FRPC_IMG}-linux-$$arch ; \
		docker manifest annotate ${FRPC_IMG} ${FRPC_IMG}-linux-$$arch --arch $$arch ; \
	done
	docker manifest push ${FRPS_IMG}
	docker manifest push ${FRPC_IMG}

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

ci:
	go test -count=1 -p=1 -v ./tests/...

e2e:
	./hack/run-e2e.sh

alltest: gotest ci e2e
	
clean:
	rm -f ./bin/frpc
	rm -f ./bin/frps
