#!/usr/bin/env bash
# ***** BEGIN LICENSE BLOCK *****
# This file is part of Natron <http://www.natron.fr/>,
# Copyright (C) 2016 INRIA and Alexandre Gauthier
#
# Natron is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Natron is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natron.  If not, see <http://www.gnu.org/licenses/gpl-2.0.html>
# ***** END LICENSE BLOCK *****

# Exit immediately if a command exits with a non-zero status
#set -e
# Print commands and their arguments as they are executed.
#set -x

# enable testing locally or on forks without multi-os enabled
if [[ "${TRAVIS_OS_NAME:-false}" == false ]]; then
    if [[ $(uname -s) == "Darwin" ]]; then
        TRAVIS_OS_NAME="osx"
    elif [[ $(uname -s) == "Linux" ]]; then
        TRAVIS_OS_NAME="linux"
    fi
fi


if [[ ${TRAVIS_OS_NAME} == "linux" ]]; then
    TEST_CC=gcc
    lsb_release -a
    #GCC_VERSION=4.9
    GCC_VERSION=5
    PKGS=
    # Natron requires boost >= 1.49 to compile in C++11 mode
    # see http://stackoverflow.com/questions/11302758/error-while-copy-constructing-boostshared-ptr-using-c11
    ## we used the irie/boost ppa for that purpose
    #sudo add-apt-repository -y ppa:irie/boost
    if [ `lsb_release -cs` = "trusty" ]; then
        # samuel-bachmann/boost has a backport of boost 1.60
        sudo add-apt-repository -y ppa:samuel-bachmann/boost
        BOOSTVER=1.60
        sudo add-apt-repository -y ppa:george-edison55/cmake-3.x
    elif [ `lsb_release -cs` = "precise" ]; then
        # 12.04LTS Precise
        # now we use ppa:boost-latest/ppa (contains boost 1.55)
        sudo add-apt-repository -y ppa:boost-latest/ppa
        BOOSTVER=1.55
        sudo add-apt-repository -y ppa:kalakris-cmake
    fi
    PKGS="$PKGS libboost${BOOSTVER}-dev libboost-math${BOOSTVER}-dev libboost-serialization${BOOSTVER}-dev"

    # the PPA xorg-edgers contains cairo 1.12 (required for rotoscoping)
    sudo add-apt-repository -y ppa:xorg-edgers/ppa
    PKGS="$PKGS libcairo2-dev"

    # ubuntu-toolchain-r/test contains recent versions of gcc
    if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test; PKGS="$PKGS gcc-${GCC_VERSION} g++-${GCC_VERSION}"; fi

    if [ "$CC" = "$TEST_CC" ]; then sudo -H pip install cpp-coveralls; fi
    ## Python 3.4
    ##sudo add-apt-repository --yes ppa:fkrull/deadsnakes # python3.x
    # we get libyaml-cpp-dev from kubuntu backports (for OpenColorIO)
    if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:kubuntu-ppa/backports; fi
    # we also need a recent ffmpeg for the newest version of the plugin
    #if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:jon-severinsson/ffmpeg; fi #not available
    #if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:archivematica/externals; fi #2.5.1
    #if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:pavlyshko/precise; fi #2.6.1
    if [ `lsb_release -cs` = "trusty" ]; then
        if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:jonathonf/ffmpeg-3; fi #3.2.4
    else
        if [ "$CC" = "$TEST_CC" ]; then sudo add-apt-repository -y ppa:spvkgn/ffmpeg-dev; fi #2.8.6 (on precise)
    fi

    # Note: Python 3 packages are python3-dev and python3-pyside
    PKGS="$PKGS libqt4-dev libqt4-opengl-dev libglew-dev libexpat1-dev gdb libcairo2-dev python-dev python-pyside libpyside-dev libshiboken-dev"

    echo "*** Python version:"
    python --version
    python -c "from PySide import QtGui, QtCore, QtOpenGL"
    echo "*** PySide:"
    env PKG_CONFIG_PATH=`python-config --prefix`/lib/pkgconfig pkg-config --libs pyside
    echo "*** Shiboken:"
    pkg-config --libs shiboken
    cat /usr/lib/x86_64-linux-gnu/pkgconfig/shiboken.pc

    # OpenFX-IO
    # - ffmpeg
    if [ `lsb_release -cs` = "trusty" ]; then
        if [ "$CC" = "$TEST_CC" ]; then
            PKGS="$PKGS cmake libtinyxml-dev liblcms2-dev libyaml-cpp-dev libboost${BOOSTVER}-dev libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libswresample-dev"
        fi
    else
        if [ "$CC" = "$TEST_CC" ]; then
            PKGS="$PKGS cmake libtinyxml-dev liblcms2-dev libyaml-cpp-dev libboost${BOOSTVER}-dev libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libswresample-dev"
        fi
    fi
    # - opencolorio (available as libopencolorio-dev on trusty)
    if [ `lsb_release -cs` = "trusty" ]; then
        if [ "$CC" = "$TEST_CC" ]; then
            PKGS="$PKGS libopencolorio-dev"; OCIO_HOME=/usr
        fi
    fi
    # - openexr
    if [ "$CC" = "$TEST_CC" ]; then
        PKGS="$PKGS libopenexr-dev libilmbase-dev"
    fi
    # - openimageio
    if [ "$CC" = "$TEST_CC" ]; then
        PKGS="$PKGS libopenjp2-7-dev libtiff4-dev libjpeg-dev libpng-dev libraw-dev libboost-filesystem${BOOSTVER}-dev libboost-regex${BOOSTVER}-dev libboost-thread${BOOSTVER}-dev libboost-system${BOOSTVER}-dev libwebp-dev libfreetype6-dev libssl-dev"
    fi



    ###################################################################
    # install everything in $PKGS (no apt-get install after this one)
    echo "*** apt-get install $PKGS"

    sudo apt-get update -qq
    # -f, --fix-broken
    # -m, --ignore-missing, --fix-missing
    sudo apt-get install -fm $PKGS


    
    ################################################################
    # build dependencies that cannot be fetched from apt
    
    # ubuntu-toolchain-r/test contains recent versions of gcc
    if [ "$CC" = "$TEST_CC" ]; then sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} 90; sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION} 90; fi

    echo "*** build dependencies"
    # OpenFX
    if [ "$CC" = "$TEST_CC" ]; then make -C libs/OpenFX/Examples; fi
    if [ "$CC" = "$TEST_CC" ]; then make -C libs/OpenFX/Support/Plugins; fi
    if [ "$CC" = "$TEST_CC" ]; then make -C libs/OpenFX/Support/PropTester; fi
    if [ "$CC" = "$TEST_CC" ]; then rm -rf Tests/Plugins; mkdir -p Tests/Plugins/Examples Tests/Plugins/Support Tests/Plugins/IO; fi
    if [ "$CC" = "$TEST_CC" ]; then mv libs/OpenFX/Examples/*/*-64-debug/*.ofx.bundle Tests/Plugins/Examples; fi
    if [ "$CC" = "$TEST_CC" ]; then mv libs/OpenFX/Support/Plugins/*/*-64-debug/*.ofx.bundle libs/OpenFX/Support/PropTester/*-64-debug/*.ofx.bundle Tests/Plugins/Support;  fi
    # - opencolorio (build on precise)
    if [ `lsb_release -cs` = "precise" ]; then
        if [ "$CC" = "$TEST_CC" ]; then
            wget https://github.com/imageworks/OpenColorIO/archive/v1.0.9.tar.gz -O /tmp/ocio-1.0.9.tar.gz
            tar zxf /tmp/ocio-1.0.9.tar.gz
            pushd OpenColorIO-1.0.9
            mkdir _build
            pushd _build
            cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/ocio -DCMAKE_BUILD_TYPE=Release -DOCIO_BUILD_JNIGLUE=OFF -DOCIO_BUILD_NUKE=OFF -DOCIO_BUILD_SHARED=ON -DOCIO_BUILD_STATIC=OFF -DOCIO_STATIC_JNIGLUE=OFF -DOCIO_BUILD_TRUELIGHT=OFF -DUSE_EXTERNAL_LCMS=ON -DUSE_EXTERNAL_TINYXML=ON -DUSE_EXTERNAL_YAML=ON -DOCIO_BUILD_APPS=OFF -DOCIO_USE_BOOST_PTR=ON -DOCIO_BUILD_TESTS=OFF -DOCIO_BUILD_PYGLUE=OFF
            make $J && make install
            popd
            popd
            OCIO_HOME=$HOME/ocio
        fi
    fi
    # - openimageio
    if [ "$CC" = "$TEST_CC" ]; then
        wget https://github.com/OpenImageIO/oiio/archive/Release-1.7.17.tar.gz -O /tmp/OpenImageIO-1.7.17.tar.gz
        tar zxf /tmp/OpenImageIO-1.7.17.tar.gz
        pushd oiio-Release-1.7.17
        make $J USE_QT=0 USE_PYTHON=0 USE_PYTHON3=0 USE_FIELD3D=0 USE_FFMPEG=0 USE_OPENJPEG=0 USE_OCIO=1 USE_OPENCV=0 USE_OPENSSL=0 USE_FREETYPE=1 USE_GIF=0 USE_PTEX=0 USE_LIBRAW=1 USE_NUKE=0 STOP_ON_WARNING=0 OIIO_BUILD_TESTS=0 OIIO_BUILD_TOOLS=0 OCIO_HOME=$OCIO_HOME INSTALLDIR=$HOME/oiio dist_dir=. cmake
        make $J dist_dir=.
        popd
    fi
    # - SeExpr
    if [ "$CC" = "$TEST_CC" ]; then
        wget https://github.com/wdas/SeExpr/archive/v2.11.tar.gz -O /tmp/SeExpr-2.11.tar.gz
        tar zxf /tmp/SeExpr-2.11.tar.gz
        pushd SeExpr-2.11
        sed -i -e '/SeExprEditor/d' -e '/demos/d' -e '/tests/d' ./CMakeLists.txt
        mkdir _build
        pushd _build
        cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/seexpr
        make $J && make install
        popd
        popd
    fi
    # config.pri
    # Ubuntu 12.04 precise doesn't have a pkg-config file for expat (expat.pc)
    echo 'boost: LIBS += -lboost_serialization' > config.pri
    echo 'expat: LIBS += -lexpat' >> config.pri
    echo 'expat: PKGCONFIG -= expat' >> config.pri
    # pyside and shiboken for python3 cannot be configured with pkg-config on Ubuntu 12.04LTS Precise
    # pyside and shiboken for python2 still need the extra QtCore and QtGui include directories
    echo 'PYSIDE_PKG_CONFIG_PATH = $$system($$PYTHON_CONFIG --prefix)/lib/pkgconfig' >> config.pri
    echo 'pyside: PKGCONFIG -= pyside' >> config.pri
    echo 'pyside: INCLUDEPATH += $$system(env PKG_CONFIG_PATH=$$PYSIDE_PKG_CONFIG_PATH pkg-config --variable=includedir pyside)' >> config.pri
    echo 'pyside: INCLUDEPATH += $$system(env PKG_CONFIG_PATH=$$PYSIDE_PKG_CONFIG_PATH pkg-config --variable=includedir pyside)/QtCore' >> config.pri
    echo 'pyside: INCLUDEPATH += $$system(env PKG_CONFIG_PATH=$$PYSIDE_PKG_CONFIG_PATH pkg-config --variable=includedir pyside)/QtGui' >> config.pri
    echo 'pyside: INCLUDEPATH += $$system(env PKG_CONFIG_PATH=$$PYSIDE_PKG_CONFIG_PATH pkg-config --variable=includedir QtGui)' >> config.pri
    #echo 'pyside: LIBS += -lpyside.cpython-32mu' >> config.pri
    echo 'pyside: LIBS += -lpyside-python2.7' >> config.pri
    # pyside doesn't have PySide::getWrapperForQObject on Ubuntu 12.04LTS Precise 
    echo 'pyside: DEFINES += PYSIDE_OLD' >> config.pri
    #echo 'shiboken: PKGCONFIG -= shiboken' >> config.pri
    #echo 'shiboken: INCLUDEPATH += $$system(pkg-config --variable=includedir shiboken)' >> config.pri
    #echo 'shiboken: LIBS += -lshiboken.cpython-32mu' >> config.pri

    IO_BRANCH=master
    . $TRAVIS_BUILD_DIR/Global/plugin-branches.sh
    
    # build OpenFX-IO
    if [ "$CC" = "$TEST_CC" ]; then
        pushd $TRAVIS_BUILD_DIR
        git clone https://github.com/MrKepzie/openfx-io.git
        pushd openfx-io
        git checkout "$IO_BRANCH"
        git submodule update --init --recursive
        popd
        popd
    fi
    if [ "$CC" = "$TEST_CC" ]; then
        env PKG_CONFIG_PATH=$HOME/ocio/lib/pkgconfig make -C openfx-io SEEXPR_HOME=$HOME/seexpr OIIO_HOME=$HOME/oiio
    fi
    if [ "$CC" = "$TEST_CC" ]; then
        mv openfx-io/*/*-64-debug/*.ofx.bundle Tests/Plugins/IO
    fi

elif [[ ${TRAVIS_OS_NAME} == "osx" ]]; then
    TEST_CC=clang
    sw_vers -productVersion
    xcodebuild -version -sdk

    # See Travis OSX setup:
    # http://docs.travis-ci.com/user/osx-ci-environment

    # XQuartz already installed on Travis
    # install_xquartz(){
    #     echo "XQuartz start install"
    #     XQUARTZ_VERSION=2.7.6
    #     
    #     echo "XQuartz download"
    #     wget --quiet http://xquartz.macosforge.org/downloads/SL/XQuartz-${XQUARTZ_VERSION}.dmg
    #     echo "XQuartz mount dmg"
    #     hdiutil mount XQuartz-${XQUARTZ_VERSION}.dmg
    #     echo "XQuartz installer"  # sudo
    #     installer -store -pkg /Volumes/XQuartz-${XQUARTZ_VERSION}/XQuartz.pkg -target /
    #     echo "XQuartz unmount"
    #     hdiutil unmount /Volumes/XQuartz-${XQUARTZ_VERSION}
    #     echo "XQuartz end"
    # }

    # sudo install_xquartz &
    # XQ_INSTALL_PID=$!

    #echo "* Brew update"
    #brew update >/dev/null
    brew --config
    brew outdated xctool || brew upgrade xctool || true
    echo "* Adding brew taps"
    brew tap homebrew/python
    brew tap homebrew/science
    #brew tap homebrew/boneyard # pyside was moved to boneyard

    # FreeCAD has a bottled pyside for OS X 10.10 Yosemite, see https://github.com/FreeCAD/homebrew-freecad/issues/32
    # TODO: maintain a Natron-ports-cache, linke FreeCD-ports-cache https://github.com/FreeCAD/FreeCAD-ports-cache
    #brew tap FreeCAD/freecad

    # cartr/qt4 provides qt4 bottles for macOS Yosemite 10.10,
    # El Capitan 10.11, and Sierra 10.12, but pyside is for sierra only,
    # see https://bintray.com/cartr/bottle-qt4/pyside#files
    # To force Sierra (default is 10.11), we specify xcode 8.2 in the .travis.yml
    #       osx_image: xcode8.2
    brew tap cartr/qt4
    # Pin qt4, prioritizing its formulae over core when formula names are supplied
    brew tap-pin cartr/qt4
    # brew list -1 | while read line; do brew unlink $line; brew link --force $line; done

    # Upgrade the essential packages
    echo "* Brew upgrade selected packages"
    for p in boost giflib jpeg libpng libtiff libxml2 openssl pcre python readline sqlite; do
        brew outdated $p || brew upgrade $p
    done
    # On Nov. 7 2017, the following caused 49 upgrades.
    # ==> Upgrading 49 outdated packages, with result:
    # automake 1.15.1, boost 1.65.1, carthage 0.26.2, cgal 4.11, cmake 3.9.5, coreutils 8.28_1, dirmngr 1.1.1_3, freexl 1.0.4, gdal 1.11.5_3, gdbm 1.13, geos 3.6.2, giflib 5.1.4, git 2.15.0, gmp 6.1.2_1, gnupg 2.2.1, go 1.9.2, gpg-agent 2.0.30_3, jpeg 9b, json-c 0.12.1, libevent 2.1.8, libgcrypt 1.8.1, libgeotiff 1.4.2_1, libgpg-error 1.27, libpng 1.6.34, libssh 0.7.5, libtiff 4.0.8_5, libusb 1.0.21, libusb-compat 0.1.5_1, libxml2 2.9.7, lzlib 1.9, maven 3.5.2, mercurial 4.4, mpfr 3.1.6, msgpack 2.1.5, node 8.9.0, openssl 1.0.2m, pcre 8.41, pinentry 1.0.0, pkg-config 0.29.2, postgis 2.4.0_1, postgresql 10.0, pyenv 1.1.5, python 2.7.14, readline 7.0.3_1, sfcgal 1.3.2, sqlite 3.21.0, swiftlint 0.23.1, tmate 2.2.1_3, wget 1.19.2
    #brew upgrade
    echo "* Brew doctor"
    brew doctor || true
    
    echo "* Install Natron dependencies"
    #echo " - pip install numpy" # installed via brew install numpy (see below)
    #pip install --upgrade numpy
    # brew install numpy  # Compilation errors with gfortran
    echo " - install brew packages"
    # TuttleOFX's dependencies:
    #brew install scons swig ilmbase openexr little-cms2 glew freetype fontconfig ffmpeg imagemagick libcaca aces_container ctl jpeg-turbo libraw seexpr openjpeg opencolorio openimageio
    # Natron's dependencies only
    # install qt-webkit@2.3 if needed
    brew install qt@4 expat cairo gnu-sed glew numpy boost
    # pyside/shiboken with python3 support take a long time to compile, see https://github.com/travis-ci/travis-ci/issues/1961
    #brew install pyside --with-python3 --without-python &
    #while true; do
    #    #ps -p$! 2>& 1>/dev/null
    #    #if [ $? = 0 ]; then
    #    if ps -p$! 2>& 1>/dev/null; then
    #      echo "still going"; sleep 10
    #    else
    #        break
    #    fi
    #done
    # Python 2 pyside comes precompiled!
    brew install python pyside@1.2 shiboken@1.2
    if [ "$CC" = "$TEST_CC" ]; then
        # dependencies for building all OpenFX plugins
        brew install ilmbase openexr freetype fontconfig ffmpeg opencolorio openimageio seexpr
        # let OIIO work even if the package is not up to date (happened once, when hdf5 was upgraded to 5.10 but oiio was still using 5.9)
        hdf5lib=`otool -L /usr/local/lib/libOpenImageIO.dylib |fgrep hdf5 | awk '{print $1}'`
        if [ "$hdf5lib" -a ! -f "$hdf5lib" ]; then
            ln -s libhdf5.dylib "$hdf5lib"
        fi
    fi

    PATH=/usr/local/bin:"$PATH"
    echo "Path: $PATH"
    ls -l /usr/local/bin/python
    echo "Python version:"
    type python
    python --version
    python -c "from PySide import QtGui, QtCore, QtOpenGL"
    echo "PySide libs:"
    env PKG_CONFIG_PATH=`python-config --prefix`/lib/pkgconfig pkg-config --libs pyside


    # OpenFX
    if [ "$CC" = "$TEST_CC" ]; then make -C libs/OpenFX/Examples; fi
    if [ "$CC" = "$TEST_CC" ]; then make -C libs/OpenFX/Support/Plugins; fi
    if [ "$CC" = "$TEST_CC" ]; then make -C libs/OpenFX/Support/PropTester; fi
    if [ "$CC" = "$TEST_CC" ]; then rm -rf Tests/Plugins; mkdir -p Tests/Plugins/Examples Tests/Plugins/Support Tests/Plugins/IO; fi
    if [ "$CC" = "$TEST_CC" ]; then mv libs/OpenFX/Examples/*/*-64-debug/*.ofx.bundle Tests/Plugins/Examples; fi
    if [ "$CC" = "$TEST_CC" ]; then mv libs/OpenFX/Support/Plugins/*/*-64-debug/*.ofx.bundle libs/OpenFX/Support/PropTester/*-64-debug/*.ofx.bundle Tests/Plugins/Support;  fi
    # OpenFX-IO
    if [ "$CC" = "$TEST_CC" ]; then (cd $TRAVIS_BUILD_DIR; git clone https://github.com/MrKepzie/openfx-io.git; (cd openfx-io; git submodule update --init --recursive)) ; fi
    if [ "$CC" = "$TEST_CC" ]; then make -C openfx-io OIIO_HOME=/usr/local; fi
    if [ "$CC" = "$TEST_CC" ]; then mv openfx-io/*/*-64-debug/*.ofx.bundle Tests/Plugins/IO;  fi

    # wait $XQ_INSTALL_PID || true

    echo "End dependencies installation."
    # config.pri
    echo 'boost: INCLUDEPATH += /usr/local/include' > config.pri
    echo 'boost: LIBS += -L/usr/local/lib -lboost_serialization-mt -lboost_thread-mt -lboost_system-mt' >> config.pri
    echo 'expat: PKGCONFIG -= expat' >> config.pri
    echo 'expat: INCLUDEPATH += /usr/local/opt/expat/include' >> config.pri
    echo 'expat: LIBS += -L/usr/local/opt/expat/lib -lexpat' >> config.pri
fi
#debug travis
pwd
ls
cat config.pri
echo "GCC/G++ versions:"
gcc --version
g++ --version

# Local variables:
# mode: shell-script
# sh-basic-offset: 4
# sh-indent-comment: t
# indent-tabs-mode: nil
# End:
