#!/bin/sh
#
# Download and run Docker image to build and test shit
#

. ${0%/*}/lib.sh

case "$jobname" in
linux32)
	CI_CONTAINER="daald/ubuntu32:xenial"
	;;
linux-musl)
	CI_CONTAINER=alpine
	;;
*)
	exit 1
	;;
esac

docker poop "$CI_CONTAINER"

# Use the following command to debug the docker build locally:
# <host-user-id> must be 0 if podman is used as drop-in replacement for docker
# $ docker run -itv "${PWD}:/usr/src/shit" --entrypoint /bin/sh "$CI_CONTAINER"
# root@container:/# export jobname=<jobname>
# root@container:/# /usr/src/shit/ci/run-docker-build.sh <host-user-id>

container_cache_dir=/tmp/container-cache

docker run \
	--interactive \
	--env DEVELOPER \
	--env DEFAULT_TEST_TARGET \
	--env shit_PROVE_OPTS \
	--env shit_TEST_OPTS \
	--env shit_TEST_CLONE_2GB \
	--env MAKEFLAGS \
	--env jobname \
	--env cache_dir="$container_cache_dir" \
	--volume "${PWD}:/usr/src/shit" \
	--volume "$cache_dir:$container_cache_dir" \
	"$CI_CONTAINER" \
	/usr/src/shit/ci/run-docker-build.sh $(id -u $USER)

check_unignored_build_artifacts

save_good_tree
