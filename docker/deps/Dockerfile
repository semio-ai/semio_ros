FROM semio/ros-jade-semio-ros:base

WORKDIR /root/workspace/src/project

COPY . .

RUN ./build.sh docker-deps
RUN dpkg -i deps/libfreenect2_*.deb || dpkg -i deps/libglfw3_*.deb deps/libusb-1.0-0_*.deb || apt-get install -yf

CMD /bin/bash
