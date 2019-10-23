.PHONY: test installer debian docker docker-multiarch-build

BUILD_ARCH ?= amd64
DEBIAN_ARCH ?= $(BUILD_ARCH)

test:
	bash test.sh

debian: installer
	bash debianize.sh --architecture $(DEBIAN_ARCH)

installer:
	bash build.sh voice2json.spec

docker: installer
	bash debianize.sh --nopackage --architecture $(DEBIAN_ARCH)
	docker build . \
        --build-arg BUILD_ARCH=$(BUILD_ARCH) \
        --build-arg DEBIAN_ARCH=$(DEBIAN_ARCH) \
        -t synesthesiam/voice2json:$(DEBIAN_ARCH)

# -----------------------------------------------------------------------------
# Multi-Arch Builds
# -----------------------------------------------------------------------------

# Builds voice2json Docker images for armhf/aarch64
docker-multiarch: docker-multiarch-install
	docker run -it \
      -v "$$(pwd):$$(pwd)" -w "$$(pwd)" \
      -e DEBIAN_ARCH=armhf \
      voice2json/multi-arch-build:armhf \
      debianize.sh --nopackage --architecture armhf
	docker build . \
        --build-arg BUILD_ARCH=arm32v7 \
        --build-arg DEBIAN_ARCH=armhf \
        -t synesthesiam/voice2json:armhf
	docker run -it \
      -v "$$(pwd):$$(pwd)" -w "$$(pwd)" \
      -e DEBIAN_ARCH=aarch64 \
      voice2json/multi-arch-build:aarch64 \
      debianize.sh --nopackage --architecture aarch64
	docker build . \
        --build-arg BUILD_ARCH=arm64v8 \
        --build-arg DEBIAN_ARCH=aarch64 \
        -t synesthesiam/voice2json:aarch64

# Installs/builds voice2json in armhf/aarch64 virtual environments
docker-multiarch-install: docker-multiarch-build
	docker run -it \
      -v "$$(pwd):$$(pwd)" -w "$$(pwd)" \
      -e DEBIAN_ARCH=armhf \
      voice2json/multi-arch-build:armhf \
      install.sh --noruntime --nocreate
	docker run -it \
      -v "$$(pwd):$$(pwd)" -w "$$(pwd)" \
      -e DEBIAN_ARCH=aarch64 \
      voice2json/multi-arch-build:aarch64 \
      install.sh --noruntime --nocreate

# Creates armhf/aarch64 build images with PyInstaller
docker-multiarch-build: docker-multiarch-build-armhf docker-multiarch-build-aarch64

docker-multiarch-build-armhf:
	docker build . -f docker/multiarch_build/Dockerfile \
        --build-arg DEBIAN_ARCH=armhf \
        --build-arg CPU_ARCH=armv7l \
        --build-arg BUILD_FROM=arm32v7/ubuntu:bionic \
        -t voice2json/multi-arch-build:armhf

docker-multiarch-build-aarch64:
	docker build . -f docker/multiarch_build/Dockerfile \
        --build-arg DEBIAN_ARCH=aarch64 \
        --build-arg CPU_ARCH=arm64v8 \
        --build-arg BUILD_FROM=arm64v8/ubuntu:bionic \
        -t voice2json/multi-arch-build:aarch64

# Create Debian packages for armhf/aarch64
docker-multiarch-debian: docker-multiarch-install
	docker run -it \
      -v "$$(pwd):$$(pwd)" -w "$$(pwd)" \
      -e DEBIAN_ARCH=armhf \
      --entrypoint make \
      voice2json/multi-arch-build:armhf \
      multiarch-debian
	docker run -it \
      -v "$$(pwd):$$(pwd)" -w "$$(pwd)" \
      -e DEBIAN_ARCH=aarch64 \
      --entrypoint make \
      voice2json/multi-arch-build:aarch64 \
      multiarch-debian

# Called from docker-multi-arch-debian within build image
multiarch-debian:
	bash build.sh voice2json.spec
	bash debianize.sh --architecture $(DEBIAN_ARCH)

# Amend existing docker manifest
manifest:
	docker manifest push --purge synesthesiam/voice2json:latest
	docker manifest create --amend synesthesiam/voice2json:latest \
        synesthesiam/voice2json:amd64 \
        synesthesiam/voice2json:armhf \
        synesthesiam/voice2json:aarch64
	docker manifest annotate synesthesiam/voice2json:latest synesthesiam/voice2json:armhf --os linux --arch arm
	docker manifest annotate synesthesiam/voice2json:latest synesthesiam/voice2json:aarch64 --os linux --arch arm64
	docker manifest push synesthesiam/voice2json:latest
