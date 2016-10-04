#!/bin/sh

PKGNAME="libsemio-ros"

if [ "$1" = "" ] || [ "$1" = "build" ]; then
	docker run -ti --name ${PKGNAME}-built -v `pwd`:/root/workspace/src/project:ro -v `pwd`:/root/workspace/debs-out semio/${PKGNAME}:deps /bin/sh build.sh docker-build
	SUCCESS=$?
	CONTAINER_ID=$(docker ps -qaf status=exited -f name=${PKGNAME}-built)
	[ ${SUCCESS} ] && docker commit ${CONTAINER_ID} semio/${PKGNAME}:built
	docker rm ${CONTAINER_ID}
elif [ "$1" = "base" ]; then
	docker build -t semio/${PKGNAME}:base docker/base/
elif [ "$1" = "base-clean" ]; then
	docker build --no-cache -t semio/${PKGNAME}:base docker/base/
elif [ "$1" = "deps" ]; then
	docker build -t semio/${PKGNAME}:deps -f docker/deps/Dockerfile .
elif [ "$1" = "clean" ]; then
	docker run -ti --name ${PKGNAME}-clean -v `pwd`:/root/workspace/src/project:ro semio/ros:sid_local-all_clean /bin/sh /root/workspace/src/project/build.sh docker-clean
	SUCCESS=$?
	CONTAINER_ID=$(docker ps -qaf status=exited -f name=${PKGNAME}-clean)
	[ ${SUCCESS} ] && docker commit ${CONTAINER_ID} semio/${PKGNAME}:clean
	docker rm ${CONTAINER_ID}
elif [ "$1" = "docker-deps" ] || [ "$1" = "docker-build" ]; then

	PKGSRC="$(git ls-remote --get-url)"
	PROVIDES="${PKGNAME}"

	VERSION="$(cat deb/version)"
	RELEASE="$(cat deb/release)"

	BUILD_REQUIRES="libsemio-dev (>= 1.20.3), libroscpp-dev, libtf2-ros-dev, libvisualization-msgs-dev, catkin, ros-message-generation"
	RUN_REQUIRES="'libsemio (>= 1.20.3)', libroscpp1d, libtf2-ros0d"

	LICENSE="GPLv3"
	PKGGROUP="libs"

	if [ "$1" = "docker-deps" ]; then
		cd /root/workspace
		# get build and run deps from catkin and resolve them to system deps using rosdep
		ROSDEP_BUILD="$(rosdep resolve $(catkin list --deps | awk '$1=="build_depend:"{m="p"} $1=="run_depend:"{m=""} m=="p"&&$1=="-"{print $2}' | sort -u) 2>/dev/null | grep -v "^#")"
		# format deps for debian control file
		if [ "${ROSDEP_BUILD}" != "" ]; then
			BUILD_REQUIRES="$(if [ "${BUILD_REQUIRES}" != "" ]; then echo -n "${BUILD_REQUIRES}, "; fi; echo -n "$(for arg in ${ROSDEP_BUILD}; do echo -n "$arg, "; done)" | sed -e 's/, $//g')"
		fi

		echo "> Building and installing metapackage for dev dependencies..."
		mkdir -p build/deb/dev-deps/DEBIAN &&\
		# generate control file from template
		cat src/project/deb/dev-deps/DEBIAN/control.in |\
			sed -e "s/\${PKGNAME}/${PKGNAME}/g" |\
			sed -e "s/\${VERSION}/${VERSION}/g" |\
			sed -e "s/\${RELEASE}/${RELEASE}/g" |\
			sed -e "s/\${BUILD_REQUIRES}/${BUILD_REQUIRES}/g" > build/deb/dev-deps/DEBIAN/control &&\
		cat build/deb/dev-deps/DEBIAN/control &&\
		# build metapackage for dependencies
		dpkg --build build/deb/dev-deps build &&\
		# install metapackage
		dpkg -i build/${PKGNAME}-dev-deps*.deb 2>/dev/null || apt-get install -yf
	elif [ "$1" = "docker-build" ]; then
		cd /root/workspace

		ROSDEP_RUN="$(rosdep resolve $(catkin list --deps | awk '$1=="build_depend:"{m=""} $1=="run_depend:"{m="p"} m=="p"&&$1=="-"{print $2}' | sort -u) 2>/dev/null | grep -v "^#")"
		if [ "${ROSDEP_RUN}" != "" ]; then
			RUN_REQUIRES="$(if [ "${RUN_REQUIRES}" != "" ]; then echo -n "${RUN_REQUIRES}, "; fi; echo -n "$(for arg in ${ROSDEP_RUN}; do echo -n "$arg, "; done)" | sed -e 's/, $//g')"
		fi

		echo "> Building main package" &&\
		# invoke catkin to build the package; ignore environment setup files; install to ros root; set build to release
		catkin_make -DCATKIN_BUILD_BINARY_PACKAGE="1" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -j$(cat /proc/cpuinfo | grep -c processor) &&\
		# copy the description file for checkinstall (it looks for ./description-pak)
		cp src/project/deb/description build/description-pak &&\
		cd build &&\
		# build the deb
		checkinstall --pkgname=${PKGNAME} --pkgsource="${PKGSRC}" --pkglicense=${LICENSE} --pkggroup=${PKGGROUP} --maintainer='Semio Corp \<support@semio.xyz\>' --provides=${PROVIDES} --requires="${RUN_REQUIRES}" --pkgversion=${VERSION} --pkgrelease=${RELEASE} --backup=no -y --exclude=/root --install=no --nodoc &&\
		# copy the deb to the output folder
		cp *.deb /root/workspace/debs-out
	fi
elif [ "$1" = "extras" ]; then
	docker build -t semio/${PKGNAME}:extras docker/extras/
elif [ "$1" = "docker-clean" ]; then
	apt-get update &&\
	apt-get install -y ${PKGNAME} libsemio-util libfreenect2-util libnite2-util libopenface-util python-roslaunch rosbash rospack-tools ros-visualization-msgs python-rostopic python-geometry-msgs tf2-tools gdb wget less vim &&\
	apt-get autoremove -y && apt-get autoclean && rm -rf /etc/apt/sources.list* && rm -rf /var/lib/apt/lists/
elif [ "$1" = "rviz-intel" ]; then
	docker build -t semio/ros:rviz-intel docker/rviz-intel/
elif [ "$1" = "rviz-nvidia" ]; then
	docker build -t semio/ros:rviz-nvidia docker/rviz-nvidia/
fi
