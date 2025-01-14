#!/usr/bin/env bash

#   Copyright © 2019 by The qTox Project Contributors
#
#   This file is part of qTox, a Qt-based graphical interface for Tox.
#   qTox is libre software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   qTox is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with qTox.  If not, see <http://www.gnu.org/licenses/>


# This script's purpose is to ease compiling qTox for users.
#
# NO AUTOMATED BUILDS SHOULD DEPEND ON IT.
#
# This script is and will be a subject to breaking changes, and at no time one
# should expect it to work - it's something that you could try to use but
# don't expect that it will work for sure.
#
# If script doesn't work, you should use instructions provided in INSTALL.md
# before reporting issues like “qTox doesn't compile”.
#
# With that being said, reporting that this script doesn't work would be nice.
#
# If you are contributing code to qTox that change its dependencies / the way
# it's being build, please keep in mind that changing just bootstrap.sh
# *IS NOT* and will not be sufficient - you should update INSTALL.md first.

set -eu -o pipefail


################ parameters ################
# directory where the script is located
readonly SCRIPT_DIR=$( cd $(dirname $0); pwd -P)

# directory where dependencies will be installed
readonly INSTALL_DIR=libs

# just for convenience
readonly BASE_DIR="${SCRIPT_DIR}/${INSTALL_DIR}"

# versions of libs to checkout
readonly TOXCORE_VERSION="v0.2.12"
readonly TOXEXT_VERSION="v0.0.2"
readonly TOX_EXT_MESSAGES_VERSION="v0.0.2"
readonly SQLCIPHER_VERSION="v4.3.0"

# directory names of cloned repositories
readonly TOXCORE_DIR="libtoxcore-$TOXCORE_VERSION"
readonly TOXEXT_DIR="toxext-$TOXEXT_VERSION"
readonly TOX_EXT_MESSAGES_DIR="tox_ext_messages-$TOXEXT_VERSION"
readonly SQLCIPHER_DIR="sqlcipher-$SQLCIPHER_VERSION"

# default values for user given parameters
INSTALL_TOX=true
INSTALL_TOXEXT=true
INSTALL_TOX_EXT_MESSAGES=true
INSTALL_SQLCIPHER=false
SYSTEM_WIDE=true
KEEP_BUILD_FILES=false

# if Fedora, by default install sqlcipher
if which dnf &> /dev/null
then
    INSTALL_SQLCIPHER=true
fi


print_help() {
    echo "Use this script to install/update libtoxcore"
    echo ""
    echo "usage:"
    echo "    ${0} PARAMETERS"
    echo ""
    echo "parameters:"
    echo "    --with-tox             : install/update libtoxcore"
    echo "    --without-tox          : do not install/update libtoxcore"
    echo "    --with-sqlcipher       : install/update sqlcipher"
    echo "    --without-sqlcipher    : do not install/update sqlcipher"
    echo "    -h|--help              : displays this help"
    echo "    -l|--local             : install packages into ${INSTALL_DIR}"
    echo "    -k|--keep              : keep build files after installation/update"
    echo ""
    echo "example usages:"
    echo "    ${0}    -- install libtoxcore"
}

############ print debug output ############
print_debug_output() {
    echo "with tox                    : ${INSTALL_TOX}"
    echo "with sqlcipher              : ${INSTALL_SQLCIPHER}"
    echo "install system-wide         : ${SYSTEM_WIDE}"
    echo "keep build files            : ${KEEP_BUILD_FILES}"
}

# remove not needed dirs
remove_build_dirs() {
    rm -rf "${BASE_DIR}/${TOXCORE_DIR}"
    rm -rf "${BASE_DIR}/${TOXEXT_DIR}"
    rm -rf "${BASE_DIR}/${TOX_EXT_MESSAGES_DIR}"
    rm -rf "${BASE_DIR}/${SQLCIPHER_DIR}"
}

install_toxcore() {
    if [[ $INSTALL_TOX = "true" ]]
    then
        git clone https://github.com/toktok/c-toxcore.git \
            --branch $TOXCORE_VERSION \
            --depth 1 \
            "${BASE_DIR}/${TOXCORE_DIR}"

        pushd ${BASE_DIR}/${TOXCORE_DIR}

        # compile and install
        if [[ $SYSTEM_WIDE = "false" ]]
        then
            cmake . -DCMAKE_INSTALL_PREFIX=${BASE_DIR} -DBOOTSTRAP_DAEMON=OFF
            make -j $(nproc)
            make install
        else
            cmake . -DBOOTSTRAP_DAEMON=OFF
            make -j $(nproc)
            sudo make install
            sudo ldconfig
        fi

        popd
    fi
}

install_toxext() {
    if [[ $INSTALL_TOXEXT = "true" ]]
    then
        git clone https://github.com/toxext/toxext.git \
            --branch $TOXEXT_VERSION \
            "${BASE_DIR}/${TOXEXT_DIR}"

        pushd ${BASE_DIR}/${TOXEXT_DIR}

        # compile and install
        if [[ $SYSTEM_WIDE = "false" ]]
        then
            cmake . -DCMAKE_INSTALL_PREFIX=${BASE_DIR}
            make -j $(nproc)
            make install
        else
            cmake .
            make -j $(nproc)
            sudo make install
            sudo ldconfig
        fi

        popd
    fi
}

install_tox_ext_messages() {
    if [[ $INSTALL_TOX_EXT_MESSAGES = "true" ]]
    then
        git clone https://github.com/toxext/tox_extension_messages.git \
            --branch $TOX_EXT_MESSAGES_VERSION \
            "${BASE_DIR}/${TOX_EXT_MESSAGES_DIR}"

        pushd ${BASE_DIR}/${TOX_EXT_MESSAGES_DIR}

        # compile and install
        if [[ $SYSTEM_WIDE = "false" ]]
        then
            cmake . -DCMAKE_INSTALL_PREFIX=${BASE_DIR}
            make -j $(nproc)
            make install
        else
            cmake .
            make -j $(nproc)
            sudo make install
            sudo ldconfig
        fi

        popd
    fi
}

install_sqlcipher() {
    if [[ $INSTALL_SQLCIPHER = "true" ]]
    then
        git clone https://github.com/sqlcipher/sqlcipher.git \
            "${BASE_DIR}/${SQLCIPHER_DIR}" \
            --branch $SQLCIPHER_VERSION \
            --depth 1

        pushd "${BASE_DIR}/${SQLCIPHER_DIR}"
        autoreconf -if

        if [[ $SYSTEM_WIDE = "false" ]]
        then
            ./configure --prefix="${BASE_DIR}" \
                --enable-tempstore=yes \
                CFLAGS="-DSQLITE_HAS_CODEC"
            make -j$(nproc)
            make install || \
                echo "" && \
                echo "Sqlcipher failed to install locally." && \
                echo "" && \
                echo "Try without \"-l|--local\"" && \
                exit 1
        else
            ./configure \
                --enable-tempstore=yes \
                CFLAGS="-DSQLITE_HAS_CODEC"
            make -j$(nproc)
            sudo make install
            sudo ldconfig
        fi

        popd
    fi
}


main() {
    ########## parse input parameters ##########
    while [ $# -ge 1 ]
    do
        if [ ${1} = "--with-tox" ]
        then
            INSTALL_TOX=true
            shift
        elif [ ${1} = "--without-tox" ]
        then
            INSTALL_TOX=false
            shift
        elif [ ${1} = "--with-toxext" ]
        then
            INSTALL_TOXEXT=true
            shift
        elif [ ${1} = "--without-toxext" ]
        then
            INSTALL_TOXEXT=false
            shift
        elif [ ${1} = "--with-toxext-messages" ]
        then
            INSTALL_TOX_EXT_MESSAGES=true
            shift
        elif [ ${1} = "--without-toxext-messages" ]
        then
            INSTALL_TOX_EXT_MESSAGES=false
            shift
        elif [ ${1} = "--with-sqlcipher" ]
        then
            INSTALL_SQLCIPHER=true
            shift
        elif [ ${1} = "--without-sqlcipher" ]
        then
            INSTALL_SQLCIPHER=false
            shift
        elif [ ${1} = "-l" -o ${1} = "--local" ]
        then
            SYSTEM_WIDE=false
            shift
        elif [ ${1} = "-k" -o ${1} = "--keep" ]
        then
            KEEP_BUILD_FILES=true
            shift
        else
            if [ ${1} != "-h" -a ${1} != "--help" ]
            then
                echo "[ERROR] Unknown parameter \"${1}\""
                echo ""
                print_help
                exit 1
            fi

            print_help
            exit 0
        fi
    done

    print_debug_output

    ############### prepare step ###############
    # create BASE_DIR directory if necessary
    mkdir -p "${BASE_DIR}"

    # maybe an earlier run of this script failed
    # thus we should remove the cloned repositories
    # if they exist, otherwise cloning them may fail
    remove_build_dirs

    ############### install step ###############
    install_toxcore
    install_toxext
    install_tox_ext_messages
    install_sqlcipher

    ############### cleanup step ###############
    # remove cloned repositories
    if [[ $KEEP_BUILD_FILES = "false" ]]
    then
        remove_build_dirs
    fi
}
main $@
