FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    ISO_FILE=ubuntu-22.04.5-desktop-amd64.iso \
    OS_VERSION=22.04.5


RUN apt-get update && \
    apt-get install -y \
        wget \
        squashfs-tools \
        rsync \
        isolinux \
        xorriso && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /builder

RUN wget -q https://releases.ubuntu.com/${OS_VERSION}/${ISO_FILE}

COPY main.sh /builder/main.sh
COPY chroot-files /builder/chroot-files

CMD ["/builder/main.sh"]