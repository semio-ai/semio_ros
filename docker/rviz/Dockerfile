FROM osrf/ros:jade-desktop

RUN apt-get update && apt-get install -y libgl1-mesa-dri-lts-xenial && apt-get autoremove -y && apt-get autoclean && rm -rf /var/lib/apt/lists/

CMD /bin/bash
