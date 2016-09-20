FROM semio/libsemio-ros:base

WORKDIR /root/workspace/src/project

COPY . .

RUN ./build.sh docker-deps

CMD /bin/bash
