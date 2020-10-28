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

WOLFSSL_VERSION="wolfssl-4.5.0"
IOS_SDK_VERSION=""
IOS_MIN_SDK_VERSION="9.0"

DEVELOPER=`xcode-select -print-path`

buildIOS()
{
	ARCH=$1
	BITCODE=$2

	pushd . > /dev/null
	cd "${WOLFSSL_VERSION}"

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

	export $PLATFORM
	export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
	export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
	export BUILD_TOOLS="${DEVELOPER}"
	export CC="${BUILD_TOOLS}/usr/bin/gcc"
	export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=${IOS_MIN_SDK_VERSION} ${CC_BITCODE_FLAG} -DWOLFSSL_DEBUG_TLS"

	export LDFLAGS="-arch ${ARCH} -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK}"

	if [[ "${ARCH}" == *"arm64"* || "${ARCH}" == "arm64e" ]]; then
		./configure --disable-shared --enable-static --host="arm-apple-darwin" --disable-examples --enable-ipv6 --enable-ecc --enable-aesgcm --enable-hkdf --enable-alpn --enable-sni --enable-oldtls  --enable-opensslextra --enable-ecccustcurves  --enable-lighty --enable-session-ticket --enable-debug
	else

		./configure --disable-shared --enable-static --host="${ARCH}-apple-darwin" --disable-examples --enable-ipv6 --enable-ecc --enable-aesgcm --enable-hkdf --enable-alpn --enable-sni --enable-oldtls  --enable-opensslextra --enable-ecccustcurves  --enable-lighty --enable-session-ticket --enable-debug

	fi

	make
 
    mkdir -p ../output
    
    cp src/.libs/libwolfssl.a ../output/${ARCH}.a
    
    #make clean
    
	popd > /dev/null
}

#rm -rf output

buildIOS "armv7" "bitcode"
buildIOS "armv7s" "bitcode"
buildIOS "arm64" "bitcode"
buildIOS "arm64e" "bitcode"
buildIOS "x86_64" "bitcode"
buildIOS "i386" "bitcode"

mkdir -p output/include/wolfssl/wolfcrypt
mkdir -p output/include/wolfssl/openssl
mkdir -p output/lib

cp ${WOLFSSL_VERSION}/wolfssl/*.h output/include/wolfssl
cp ${WOLFSSL_VERSION}/wolfssl/wolfcrypt/*.h output/include/wolfssl/wolfcrypt
cp ${WOLFSSL_VERSION}/wolfssl/openssl/*.h output/include/wolfssl/openssl

rm -rf iOS
mkdir -p iOS/lib
lipo \
    output/armv7.a \
    output/armv7s.a \
    output/arm64.a \
    output/arm64e.a \
    -create -output output/lib/libwolf_iOS.a
cp output/lib/libwolf_iOS.a iOS/lib/libwolfssl.a
cp -r output/include iOS/

rm -rf iOS-simulator
mkdir -p iOS-simulator/lib
lipo \
    output/i386.a \
    output/x86_64.a \
    -create -output output/lib/libwolf_iOS-simulator.a
cp output/lib/libwolf_iOS-simulator.a iOS-simulator/lib/libwolfssl.a
cp -r output/include iOS-simulator/

rm -rf iOS-fat
mkdir -p iOS-fat/lib
lipo \
    output/lib/libwolf_iOS.a \
    output/lib/libwolf_iOS-simulator.a \
    -create -output output/lib/libwolf_fat.a
cp output/lib/libwolf_fat.a iOS-fat/lib/libwolfssl.a
cp -r output/include iOS-fat/

# rm -rf output/*.a
