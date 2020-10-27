#!/bin/bash

# This script downlaods and builds the Mac, iOS and tvOS libcurl libraries with Bitcode enabled

# Credits:
#
# Felix Schwarz, IOSPIRIT GmbH, @@felix_schwarz.
#   https://gist.github.com/c61c0f7d9ab60f53ebb0.git
# Bochun Bai
#   https://github.com/sinofool/build-libcurl-ios
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
# Preston Jennings
#   https://github.com/prestonj/Build-OpenSSL-cURL

set -e

# Formatting
default="\033[39m"
wihte="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${green}\033[1m"
subbold="\033[0m${green}"
archbold="\033[0m${yellow}\033[1m"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

# set trap to help debug any build errors
trap 'echo -e "${alert}** ERROR with Build - Check /tmp/curl*.log${alertdim}"; tail -3 /tmp/curl*.log' INT TERM EXIT

CURL_VERSION="curl-7.72.0"
IOS_SDK_VERSION=""
IOS_MIN_SDK_VERSION="9.0"
TVOS_SDK_VERSION=""
TVOS_MIN_SDK_VERSION="9.0"
IPHONEOS_DEPLOYMENT_TARGET="6.0"
nohttp2="0"
catalyst="0"

usage ()
{
	echo
	echo -e "${bold}Usage:${normal}"
	echo
	echo -e "  ${subbold}$0${normal} [-v ${dim}<curl version>${normal}] [-s ${dim}<iOS SDK version>${normal}] [-t ${dim}<tvOS SDK version>${normal}] [-i ${dim}<iPhone target version>${normal}] [-b] [-m] [-x] [-n] [-h]"
    echo
	echo "         -v   version of curl (default $CURL_VERSION)"
	echo "         -s   iOS SDK version (default $IOS_MIN_SDK_VERSION)"
	echo "         -t   tvOS SDK version (default $TVOS_MIN_SDK_VERSION)"
	echo "         -i   iPhone target version (default $IPHONEOS_DEPLOYMENT_TARGET)"
	echo "         -b   compile without bitcode"
	echo "         -n   compile with nghttp2"
	echo "         -m   compile Mac Catalyst library [beta]"
	echo "         -x   disable color output"
	echo "         -h   show usage"
	echo
	trap - INT TERM EXIT
	exit 127
}

while getopts "v:s:t:i:nmbxh\?" o; do
    case "${o}" in
        v)
			CURL_VERSION="curl-${OPTARG}"
            ;;
        s)
            IOS_SDK_VERSION="${OPTARG}"
            ;;
        t)
	    	TVOS_SDK_VERSION="${OPTARG}"
            ;;
        i)
	    	IPHONEOS_DEPLOYMENT_TARGET="${OPTARG}"
            ;;
		n)
			nohttp2="1"
			;;
		m)
			catalyst="1"
			;;
		b)
			NOBITCODE="yes"
			;;
		x)
			bold=""
			subbold=""
			normal=""
			dim=""
			alert=""
			alertdim=""
			archbold=""
			;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

WOLFSSL="${PWD}/../wolfssl"
DEVELOPER=`xcode-select -print-path`

# HTTP2 support
NGHTTP2="${PWD}/../nghttp2"

buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${CURL_VERSION}"

	if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
		PLATFORM="iPhoneSimulator"
		SSLVARIANT="iOS-simulator"
	else
		PLATFORM="iPhoneOS"
		SSLVARIANT="iOS"
	fi

	if [[ "${BITCODE}" == "nobitcode" ]]; then
		CC_BITCODE_FLAG=""
	else
		CC_BITCODE_FLAG="-fembed-bitcode"
	fi

	if [ $nohttp2 == "1" ]; then
		NGHTTP2CFG="--with-nghttp2=${NGHTTP2}/iOS/${ARCH}"
		NGHTTP2LIB="-L${NGHTTP2}/iOS/${ARCH}/lib"
	fi

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG}"

	echo -e "${subbold}Building ${CURL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${archbold}${ARCH}${dim} ${BITCODE}"

	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -L${WOLFSSL}/${SSLVARIANT}/lib ${NGHTTP2LIB}"

	if [[ "${ARCH}" == *"arm64"* || "${ARCH}" == "arm64e" ]]; then
		./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}" --disable-shared --enable-static -with-random=/dev/urandom --with-wolfssl=${WOLFSSL}/${SSLVARIANT} ${NGHTTP2CFG} --without-ssl --host="arm-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}.log"
	else

		./configure -prefix="/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}" --disable-shared --enable-static -with-random=/dev/urandom --with-wolfssl=${WOLFSSL}/${SSLVARIANT} ${NGHTTP2CFG} --without-ssl --host="${ARCH}-apple-darwin" &> "/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}.log"
	fi

    make -j8 >> "/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
    make install >> "/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
    make clean >> "/tmp/${CURL_VERSION}-iOS-${ARCH}-${BITCODE}.log" 2>&1
    popd > /dev/null
}

echo -e "${bold}Cleaning up${dim}"
rm -rf include/curl/* lib/*

mkdir -p lib
mkdir -p include/curl/

rm -rf "/tmp/${CURL_VERSION}-*"
rm -rf "/tmp/${CURL_VERSION}-*.log"

#rm -rf "${CURL_VERSION}"

if [ ! -e ${CURL_VERSION}.tar.gz ]; then
    echo "Downloading ${CURL_VERSION}.tar.gz"
    curl -LO https://curl.haxx.se/download/${CURL_VERSION}.tar.gz
else
    echo "Using ${CURL_VERSION}.tar.gz"
fi

if [ ! -d ${CURL_VERSION} ]; then
	echo "Unpacking curl"
	tar xfz "${CURL_VERSION}.tar.gz"
fi

echo -e "${bold}Building iOS libraries (bitcode)${dim}"
buildIOS "armv7" "bitcode"
buildIOS "armv7s" "bitcode"
buildIOS "arm64" "bitcode"
buildIOS "arm64e" "bitcode"

lipo \
    "/tmp/${CURL_VERSION}-iOS-armv7-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-armv7s-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-arm64-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-arm64e-bitcode/lib/libcurl.a" \
    -create -output lib/libcurl_iOS.a

buildIOS "x86_64" "bitcode"
buildIOS "i386" "bitcode"

lipo \
    "/tmp/${CURL_VERSION}-iOS-i386-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-x86_64-bitcode/lib/libcurl.a" \
    -create -output lib/libcurl_iOS-simulator.a

lipo \
    "/tmp/${CURL_VERSION}-iOS-armv7-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-armv7s-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-arm64-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-arm64e-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-i386-bitcode/lib/libcurl.a" \
    "/tmp/${CURL_VERSION}-iOS-x86_64-bitcode/lib/libcurl.a" \
    -create -output lib/libcurl_iOS-fat.a

if [[ "${NOBITCODE}" == "yes" ]]; then
    echo -e "${bold}Building iOS libraries (nobitcode)${dim}"
    buildIOS "armv7" "nobitcode"
    buildIOS "armv7s" "nobitcode"
    buildIOS "arm64" "nobitcode"
    buildIOS "arm64e" "nobitcode"
    buildIOS "x86_64" "nobitcode"
    buildIOS "i386" "nobitcode"

    lipo \
        "/tmp/${CURL_VERSION}-iOS-armv7-nobitcode/lib/libcurl.a" \
        "/tmp/${CURL_VERSION}-iOS-armv7s-nobitcode/lib/libcurl.a" \
        "/tmp/${CURL_VERSION}-iOS-i386-nobitcode/lib/libcurl.a" \
        "/tmp/${CURL_VERSION}-iOS-arm64-nobitcode/lib/libcurl.a" \
        "/tmp/${CURL_VERSION}-iOS-arm64e-nobitcode/lib/libcurl.a" \
        "/tmp/${CURL_VERSION}-iOS-x86_64-nobitcode/lib/libcurl.a" \
        -create -output lib/libcurl_iOS_nobitcode.a

fi

echo -e "${bold}Cleaning up${dim}"
rm -rf /tmp/${CURL_VERSION}-*
#rm -rf ${CURL_VERSION}

echo "Checking libraries"
xcrun -sdk iphoneos lipo -info lib/*.a

#reset trap
trap - INT TERM EXIT

echo -e "${normal}Done"
