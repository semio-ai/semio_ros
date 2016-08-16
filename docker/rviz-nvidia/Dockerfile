FROM osrf/ros:jade-desktop

LABEL com.nvidia.volumes.needed="nvidia_driver"
ENV PATH /usr/local/nvidia/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/nvidia/lib:/usr/local/nvidia/lib64:${LD_LIBRARY_PATH}

#RUN apt-get update && apt-get install -y libgl1-mesa-dri-lts-xenial && apt-get autoremove -y && apt-get autoclean && rm -rf /var/lib/apt/lists/

CMD /bin/bash
