#!/bin/bash -e

PK3_FILE=CapturePointSystems.pk3
ACS_SOURCE_FILES=CPLIB

function banner {
    echo ""
    echo "###################################"
    echo " $1"
    echo "###################################"
    echo ""
}

for cmd in zip acc; do
    which $cmd > /dev/null 2>&1 || true
    status=$?
    if [ $status -ne 0 ]; then
        echo "Cannot locate command: $cmd"
        exit 1
    fi
done

SRCROOT=$(pwd)
BUILDROOT=${SRCROOT}/build

mkdir -p ${BUILDROOT}
rm -rf ${BUILDROOT}/pk3
cp -r ${SRCROOT}/pk3 ${BUILDROOT}/pk3

banner "Compiling ACS"
mkdir -p ${BUILDROOT}/pk3/acs
for acs in ${ACS_SOURCE_FILES}; do
    echo " ### ${acs}"
    acc ${BUILDROOT}/pk3/${acs}.acs ${BUILDROOT}/pk3/acs/${acs}.o
done

banner "Compressing PK3"
rm -f ${SRCROOT}/${PK3_FILE}
pushd ${BUILDROOT}/pk3
zip -r ${SRCROOT}/${PK3_FILE} *
popd

