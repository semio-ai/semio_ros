#!/bin/sh

ROS_DISTRO=jade
PKGNAME="ros-${ROS_DISTRO}-semio-ros"

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
	docker build -t semio/${PKGNAME}:clean -f docker/clean/ --squash=true
elif [ "$1" = "docker-deps" ] || [ "$1" = "docker-build" ]; then
	. /opt/ros/${ROS_DISTRO}/setup.sh

	PKGSRC="$(git ls-remote --get-url)"
	PROVIDES="${PKGNAME}"

	VERSION="$(cat deb/version)"
	RELEASE="$(cat deb/release)"

	BUILD_REQUIRES="libsemio, libsemio-dev-deps"
	RUN_REQUIRES="libsemio, ros-${ROS_DISTRO}-rosbridge-server"

	LICENSE="GPLv3"
	PKGGROUP="libs"

	if [ "$1" = "docker-deps" ]; then
		cd /root/workspace
		# get build and run deps from catkin and resolve them to system deps using rosdep
		ROSDEP_BUILD="$(rosdep resolve $(catkin list --deps | awk '$1=="build_depend:"{m="p"} $1=="run_depend:"{m=""} m=="p"&&$1=="-"{print $2}' | sort -u) 2>/dev/null | grep -v "^#")"
		# format deps for debian control file
		BUILD_REQUIRES="$(if [ "${BUILD_REQUIRES}" != "" ]; then echo -n "${BUILD_REQUIRES}, "; fi; echo -n "$(for arg in ${ROSDEP_BUILD}; do echo -n "$arg, "; done)" | sed -e 's/, $//g')"

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
		sudo dpkg -i build/${PKGNAME}-dev-deps*.deb 2>/dev/null ||\
		# if installation fails, use apt-cache unmet to figure out whether the system knows about the rest of the deps we need
		{
			DEPS_TO_CHECK="${PKGNAME}-dev-deps"
			# any deps to check are potential unmet dependencies; apt-cache unmet will tell us what is missing
			# we keep checking for deps; when we run out, then everything else can be satisfied through apt
			while [ "${DEPS_TO_CHECK}" != "" ]; do
				echo ">> Need additional dependencies; asking apt to resolve them..."
				for dep in $(apt-cache unmet ${DEPS_TO_CHECK} | awk '$1=="Depends:"{print $2}'); do
					# for any unmet deps, mark them to be searched for locally
					echo ">>> Need ${dep}" && NEW_DEPS_TO_CHECK="${NEW_DEPS_TO_CHECK} ${dep}" && LOCAL_REQUIRES="${LOCAL_REQUIRES} src/project/deps/${dep}_*.deb"
				done

				# try to install the local deps
				if [ "${LOCAL_REQUIRES}" != "" ]; then
					echo ">> Installing unmet dependencies from local files: ${LOCAL_REQUIRES}"
					sudo dpkg -i ${LOCAL_REQUIRES} 2>/dev/null
					LOCAL_REQUIRES=""
				fi

				DEPS_TO_CHECK="${NEW_DEPS_TO_CHECK}"
				NEW_DEPS_TO_CHECK=""
			done

			echo ">> All remaining dependencies satisfiable through apt; installing..."
			sudo apt-get install -yf
		}
	elif [ "$1" = "docker-build" ]; then
		cd /root/workspace

		ROSDEP_RUN="$(rosdep resolve $(catkin list --deps | awk '$1=="build_depend:"{m=""} $1=="run_depend:"{m="p"} m=="p"&&$1=="-"{print $2}' | sort -u) 2>/dev/null | grep -v "^#")"
		RUN_REQUIRES="$(if [ "${RUN_REQUIRES}" != "" ]; then echo -n "${RUN_REQUIRES}, "; fi; echo -n "$(for arg in ${ROSDEP_RUN}; do echo -n "$arg, "; done)" | sed -e 's/, $//g')"

		echo "> Building main package" &&\
		# invoke catkin to build the package; ignore environment setup files; install to ros root; set build to release
		catkin_make -DCATKIN_BUILD_BINARY_PACKAGE="1" -DCMAKE_INSTALL_PREFIX=/opt/ros/${ROS_DISTRO} -DCMAKE_BUILD_TYPE=Release -j$(cat /proc/cpuinfo | grep -c processor) &&\
		# copy the description file for checkinstall (it looks for ./description-pak)
		cp src/project/deb/description build/description-pak &&\
		cd build &&\
		# build the deb
		checkinstall --pkgname=${PKGNAME} --pkgsource="${PKGSRC}" --pkglicense=${LICENSE} --pkggroup=${PKGGROUP} --maintainer='Semio Corp \<support@semio.xyz\>' --provides=${PROVIDES} --requires="${RUN_REQUIRES}" --pkgversion=${VERSION} --pkgrelease=${RELEASE} --backup=no -y --exclude=/root --install=no &&\
		# copy the deb to the output folder
		cp *.deb /root/workspace/debs-out
	fi
elif [ "$1" = "docker-clean" ]; then
	dpkg -i /root/workspace/build/${PKGNAME}_*.deb &&\
	apt-get remove -y ${PKGNAME}-dev-deps && apt-get autoremove -y && apt-get autoclean && rm -rf /var/lib/apt/lists/ &&\
	cd /root/workspace && rm -rf project build
elif [ "$1" = "rviz-intel" ]; then
	docker build -t semio/ros:rviz-intel docker/rviz-intel/
elif [ "$1" = "rviz-nvidia" ]; then
	docker build -t semio/ros:rviz-nvidia docker/rviz-nvidia/
fi
