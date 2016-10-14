FROM semio/libsemio-ros:built

RUN apt-get update
RUN dpkg -i /root/workspace/build/libsemio-ros_*.deb || apt-get install -yf
RUN apt-get install -y libsemio-util libfreenect2-util libnite2-util libopenface-util python-roslaunch rosbash rospack-tools ros-visualization-msgs python-rostopic python-rosnode python-geometry-msgs python-visualization-msgs tf2-tools rviz gdb wget less vim

CMD /bin/bash
