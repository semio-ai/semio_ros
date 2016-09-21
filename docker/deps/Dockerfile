FROM semio/libsemio-ros:base

WORKDIR /root/workspace/src/project

COPY build.sh .
COPY deb deb
COPY .git .git

RUN ./build.sh docker-deps

CMD /bin/bash
