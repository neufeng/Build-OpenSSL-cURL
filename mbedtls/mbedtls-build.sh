#!/bin/bash

#  Automatic build script for mbedtls
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 08.04.11.
#  Copyright 2010 Felix Schulze. All rights reserved.
#  modify this script by mingtingjian on 2015_08_06
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#  Change values here
#

if [ -z $1 ]; then
	VERSION="2.24.0"
else
	VERSION="$1"
fi

MBEDTLS_VERSION="mbedtls-${VERSION}"
SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
IOS_MIN_SDK_VERSION="9.0"
#
###########################################################################
#
# Don't change anything here
CURRENTPATH=`pwd`
ARCHS="i386 x86_64 armv7 armv7s arm64 arm64e"
DEVELOPER=`xcode-select -print-path`

##########
set -e
if [ ! -e ${MBEDTLS_VERSION}.tar.gz ]; then
	echo "Downloading ${MBEDTLS_VERSION}.tar.gz"
	curl -O https://github.com/ARMmbed/mbedtls/archive/v${VERSION}.tar.gz
else
	echo "Using ${MBEDTLS_VERSION}.tar.gz"
fi

if [ ! -d ${MBEDTLS_VERSION} ]; then
	echo "Unpacking mbedtls"
	tar xfz ${MBEDTLS_VERSION}.tar.gz
fi

# clean
rm -rf include
rm -rf bin
rm -rf lib

mkdir -p include
mkdir -p bin
mkdir -p lib

cd ${MBEDTLS_VERSION}

for ARCH in ${ARCHS} 
do
	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
	else
		PLATFORM="iPhoneOS"
	fi

	if [[ "${BITCODE}" == "nobitcode" ]]; then
		CC_BITCODE_FLAG=""
	else
		CC_BITCODE_FLAG="-fembed-bitcode"
	fi

	echo "Building mbedtls for ${PLATFORM} ${SDKVERSION} ${ARCH} ${BITCODE}"

	# echo "Patching Makefile..."
	# sed -i.bak '4d' library/Makefile
	make clean

	echo "Please stand by..."

	export DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${SDKVERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"

	export LDFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT}"
	export CFLAGS="-arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${SDKROOT} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} -I${CURRENTPATH}/${MBEDTLS_VERSION}/include ${CC_BITCODE_FLAG}"

	make

	cp library/libmbedcrypto.a ../bin/libmbedcrypto-${ARCH}.a
	cp library/libmbedx509.a ../bin/libmbedx509-${ARCH}.a
	cp library/libmbedtls.a ../bin/libmbedtls-${ARCH}.a
done

cp -R include ../
# cp LICENSE ../include/mbedtls/LICENSE
# rm -rf ${MBEDTLS_VERSION}

cd ${CURRENTPATH}

rm -rf iOS
mkdir -p iOS/lib
lipo -create \
	"bin/libmbedtls-armv7.a" \
	"bin/libmbedtls-armv7s.a" \
	"bin/libmbedtls-arm64.a" \
	"bin/libmbedtls-arm64e.a" \
	-output "lib/libmbedtls_iOS.a"
cp lib/libmbedtls_iOS.a iOS/lib/libmbedtls.a
lipo -create \
	"bin/libmbedcrypto-armv7.a" \
	"bin/libmbedcrypto-armv7s.a" \
	"bin/libmbedcrypto-arm64.a" \
	"bin/libmbedcrypto-arm64e.a" \
	-output "lib/libmbedcrypto_iOS.a"
cp lib/libmbedcrypto_iOS.a iOS/lib/libmbedcrypto.a
lipo -create \
	"bin/libmbedx509-armv7.a" \
	"bin/libmbedx509-armv7s.a" \
	"bin/libmbedx509-arm64.a" \
	"bin/libmbedx509-arm64e.a" \
	-output "lib/libmbedx509_iOS.a"
cp lib/libmbedx509_iOS.a iOS/lib/libmbedx509.a
cp -r include iOS/

rm -rf iOS-simulator
mkdir -p iOS-simulator/lib
lipo -create \
	"bin/libmbedtls-i386.a" \
	"bin/libmbedtls-x86_64.a" \
	-output "lib/libmbedtls_iOS-simulator.a"
cp lib/libmbedtls_iOS-simulator.a iOS-simulator/lib/libmbedtls.a
lipo -create \
	"bin/libmbedcrypto-i386.a" \
	"bin/libmbedcrypto-x86_64.a" \
	-output "lib/libmbedcrypto_iOS-simulator.a"
cp lib/libmbedcrypto_iOS-simulator.a iOS-simulator/lib/libmbedcrypto.a
lipo -create \
	"bin/libmbedx509-i386.a" \
	"bin/libmbedx509-x86_64.a" \
	-output "lib/libmbedx509_iOS-simulator.a"
cp lib/libmbedx509_iOS-simulator.a iOS-simulator/lib/libmbedx509.a
cp -r include iOS-simulator/

rm -rf iOS-fat
mkdir -p iOS-fat/lib
lipo -create \
	"bin/libmbedtls-i386.a" \
	"bin/libmbedtls-x86_64.a" \
	"bin/libmbedtls-armv7.a" \
	"bin/libmbedtls-armv7s.a" \
	"bin/libmbedtls-arm64.a" \
	"bin/libmbedtls-arm64e.a" \
	-output "lib/libmbedtls_fat.a"
cp lib/libmbedtls_fat.a iOS-fat/lib/libmbedtls.a
lipo -create \
	"bin/libmbedcrypto-i386.a" \
	"bin/libmbedcrypto-x86_64.a" \
	"bin/libmbedcrypto-armv7.a" \
	"bin/libmbedcrypto-armv7s.a" \
	"bin/libmbedcrypto-arm64.a" \
	"bin/libmbedcrypto-arm64e.a" \
	-output "lib/libmbedcrypto_fat.a"
cp lib/libmbedcrypto_fat.a iOS-fat/lib/libmbedcrypto.a
lipo -create \
	"bin/libmbedx509-i386.a" \
	"bin/libmbedx509-x86_64.a" \
	"bin/libmbedx509-armv7.a" \
	"bin/libmbedx509-armv7s.a" \
	"bin/libmbedx509-arm64.a" \
	"bin/libmbedx509-arm64e.a" \
	-output "lib/libmbedx509_fat.a"
cp lib/libmbedx509_fat.a iOS-fat/lib/libmbedx509.a
cp -r include iOS-fat/

echo "Build library..."

echo "Building done."
