#!/bin/sh
set -e -x
# Build epics-base and common support modules
#
# Debian 12 packages to build
# build-essential autoconf automake libreadline-dev libncurses-dev 
# libpcre3-dev libxml2-dev libjpeg-dev libxext-dev re2c libgraphicsmagick++1-dev 
# libaec-dev libhdf5-dev libjpeg-dev libnetcdf-dev libtiff-dev libz3-dev python-is-python3
#
# Required Debian packages to build
#  build-essential autoconf automake
#  libreadline6-dev libncurses5-dev perl
#  libpcre3-dev libxml2-dev libjpeg-dev libxext-dev
#  re2c
#  libgraphicsmagick++-dev libaec-dev libhdf5-dev libaec-devel libjpeg-dev libnetcdf-dev
#  libtiff-dev libz-dev
#
# Required RHEL/CentOS
#  gcc-c++ glibc-devel make readline-devel ncurses-devel autoconf automake
#  perl-devel
#  pkg-config pcre-devel libxml2-devel libjpeg-turbo-devel libtiff-devel
#  libXext-devel
# From EPEL
#  re2c
#  GraphicsMagick-c++-devel hdf5-devel libaec-devel netcdf-devel

opt_J=2
opt_P=
while getopts hj:p: opt
do
    case $opt in
    j)  opt_J=$OPTARG;;
    p)  opt_P=-${OPTARG};;
    *)  echo "$0 [-j #] [-p NAME]"
        exit 1
        ;;
    esac
done
shift `expr $OPTIND - 1`

BASEDIR="$(dirname "$(readlink -f "$0")")"
PREFIX=epics${opt_P}-`uname -m`-`date +%Y%m%d`
TAR=$PREFIX.tar

PMAKE="-j${opt_J}"

die() {
    echo "$1" >&1
    exit 1
}

cd "$BASEDIR"

perl --version || die "Missing perl"
g++ --version || die "Missing gcc/g++"
type re2c || die "Need re2c for sncseq.  Missing PowerTools?"
pkg-config --exists libpcre || die "Need libpcre headers for stream"

# git_module <name>
git_module() {
    [ -d "$1" ] || die "Missing $1"
    echo "=== $1" > $1.version
    printf "URL: " >> $1.version
    (cd "$1" && (git remote get-url origin || git remote show -n origin|grep Fetch) && git describe --always --tags --abbrev=8 HEAD && git log -n1) >> $1.version
}

do_make() {
    make LINKER_USE_RPATH=ORIGIN LINKER_ORIGIN_ROOT="$BASEDIR" $PMAKE "$@"
}

do_module() {
    name="$1"
    shift
    echo "Building module $name"
    cat "$name"/configure/RELEASE
    (cd "$name" && do_make "$@")
    tar --exclude 'O.*' --exclude-vcs -rf $TAR $PREFIX/"$name"
}

git_module procserv
git_module epics-base
git_module pvxs
git_module pcas
git_module ca-cagateway
git_module caputlog
git_module recsync
git_module autosave
git_module calc
git_module busy
git_module asyn
git_module stream
git_module seq
git_module iocstats
git_module sscan
git_module etherip
git_module modbus
git_module p4p

export EPICS_HOST_ARCH=`./epics-base/startup/EpicsHostArch`

cat <<EOF >epics-base/configure/CONFIG_SITE.local
CROSS_COMPILER_TARGET_ARCHS += \$(EPICS_HOST_ARCH)-debug

# workaround for https://sourceware.org/bugzilla/show_bug.cgi?id=16936
EXTRA_SHRLIBDIR_RPATH_LDFLAGS_ORIGIN_NO += \$(SHRLIB_SEARCH_DIRS:%=-Wl,-rpath-link,%)
OP_SYS_LDFLAGS += \$(EXTRA_SHRLIBDIR_RPATH_LDFLAGS_\$(LINKER_USE_RPATH)_\$(STATIC_BUILD))
EOF

if [ ! -f /usr/include/rpc/rpc.h ]
then
  cat <<EOF >asyn/configure/CONFIG_SITE.local
TIRPC=YES
EOF
else
  rm -f asyn/configure/CONFIG_SITE.local
fi

cat <<EOF >pvxs/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >pcas/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >ca-cagateway/configure/RELEASE
PCAS=\$(EPICS_BASE)/../pcas
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >caputlog/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >autosave/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >recsync/client/configure/RELEASE
EPICS_BASE=\$(TOP)/../../epics-base
EOF

cat <<EOF >seq/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >iocstats/configure/RELEASE
SNCSEQ=\$(EPICS_BASE)/../seq
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >asyn/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >etherip/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >busy/configure/RELEASE
ASYN=\$(EPICS_BASE)/../asyn
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >modbus/configure/RELEASE
ASYN=\$(EPICS_BASE)/../asyn
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >sscan/configure/RELEASE
SNCSEQ=\$(EPICS_BASE)/../seq
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >calc/configure/RELEASE
SSCAN=\$(EPICS_BASE)/../sscan
SNCSEQ=\$(EPICS_BASE)/../seq
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >stream/configure/RELEASE
SSCAN=\$(EPICS_BASE)/../sscan
SNCSEQ=\$(EPICS_BASE)/../seq
CALC=\$(EPICS_BASE)/../calc
ASYN=\$(EPICS_BASE)/../asyn
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >devsnmp/configure/RELEASE
EPICS_BASE=\$(TOP)/../epics-base
EOF

cat <<EOF >p4p/configure/RELEASE.local
PVXS=\$(TOP)/../pvxs
EPICS_BASE=\$(TOP)/../epics-base
EOF

trap 'rm -f $PREFIX $TAR' TERM KILL HUP EXIT

rm -f $PREFIX
ln -s . $PREFIX

git remote show origin -n > build-info
git describe --always --tags --abbrev=8 HEAD && git log -n1 >> build-info

tar -cf $TAR $PREFIX/build-info $PREFIX/prepare.sh $PREFIX/README.md $PREFIX/demo.db $PREFIX/build-epics.sh

(cd procserv && autoreconf -v -f -i && ./configure --disable-doc --prefix=$BASEDIR/usr && make install )
tar --exclude '*.o' --exclude autom4te.cache --exclude-vcs -rf $TAR $PREFIX/usr

if [ -f /usr/bin/cmake ]
then
    LIBEVENT_ARGS=LIBEVENT_USE_CMAKE=YES
else
    LIBEVENT_ARGS=LIBEVENT_USE_CMAKE=NO
fi

echo "Bundled libevent"
(cd pvxs/bundle && do_make $LIBEVENT_ARGS libevent.${EPICS_HOST_ARCH})
(cd pvxs/bundle && do_make $LIBEVENT_ARGS libevent.${EPICS_HOST_ARCH}-debug)

do_module epics-base -s
do_module pvxs
do_module pcas
do_module ca-cagateway EMBEDDED_TOPS=
do_module caputlog
do_module autosave
do_module recsync/client
do_module seq
do_module iocstats
do_module asyn
do_module busy
do_module sscan
do_module calc
do_module stream BUILD_PCRE=NO
do_module etherip
do_module modbus
do_module devsnmp
do_module p4p

tar -rf $TAR $PREFIX/*.version

xz -f $TAR
xz -l $TAR.*
ls -lh $TAR.*
