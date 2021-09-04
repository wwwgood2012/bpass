#!/usr/bin/env bash

# exit if any command returns a non-zero value, use $cmd || true if non-zero value is expected
set -e
# exit if any variable is not set before it is used
set -u

set +u
appName=bpaas-core
version=4.0.2
shouldExit=0
noPush=0
noCache=0
doSave=0
typeset SAVE_IMAGE_TARGET=$(pwd)

para_array=( $@ )
for i in "${para_array[@]}"
do
	if [[ $i == "noPush" ]]; then
        noPush=1
    elif [[ $i == "noCache" ]]; then
        noCache=1
    elif [[ $i == "doSave" ]]; then
        doSave=1
    else
        SAVE_IMAGE_TARGET=$i
    fi
done

if [[ ! -d ${SAVE_IMAGE_TARGET} ]];then
    echo "No existing save docker image target directory" 1>&2
    shouldExit=1
fi

if [[ -z "$appName" ]]; then
    echo "No application name specified." 1>&2
    shouldExit=1
fi

dockerRegistry="docker-registry.marathon.l4lb.thisdcos.directory:5000"
if [[ "$dockerRegistry" == "" ]]; then
    echo "DOCKER_REGISTRY is not set. Image will not be pushed to registry."
fi
set -u

curDir=`pwd`
if [ ! -f $curDir/Dockerfile ]; then
    echo "No Docker file found in the current directory $curDir." 1>&2
    exit 0
fi

if [[ "$shouldExit" == "1" ]]; then
    exit 1;
fi

echo "Start building docker image..."
echo ".git"     > .dockerignore
echo "*/.git"  >> .dockerignore
echo "*~"   >> .dockerignore
# echo "*.tgz" >> .dockerignore
echo "#*" >> .dockerignore

if [[ "$noCache" == "1" ]]; then
    echo "No cache option enabled for docker build"
    docker build --no-cache -t $appName:${version} .
else
    echo "Use cache for docker build"
    docker build -t $appName:${version} .
fi

if [ "$version" == "none" ]; then
    echo "Finished building the service."
    exit 0;
fi

if [[ "$dockerRegistry" != "" ]]; then
    if [[ "$noPush" == "1" ]]; then
        echo "No pushing enabled, will only build and tag the image."
        docker tag $appName:${version} $dockerRegistry/$appName:${version}
    else
        docker tag $appName:${version} $dockerRegistry/$appName:${version} \
        && docker push $dockerRegistry/$appName:${version}
    fi
    if [[ "$doSave" == "1" ]]; then
        echo "It will save this image at ${SAVE_IMAGE_TARGET} directory."
        cd $SAVE_IMAGE_TARGET \
        && docker save $appName:${version} | gzip > $appName.tar.gz
    fi
else
    echo "dockerRegistry is not set. Does not push to registery."
fi
