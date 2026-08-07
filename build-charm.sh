#!/bin/bash -x
#SBATCH --job-name=build-charm
#SBATCH --nodes=1
#SBATCH --ntasks=20
#SBATCH --cpus-per-task=1
#SBATCH --time=10:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
#SBATCH --partition=kura
#SBATCH --exclusive

# Builds PAPI and four Charm++ variants into deps/prefix, each skipped if
# already present. Run as a job rather than on the login host: Kabre's login
# nodes differ from its compute nodes, so anything that will run on a compute
# node is better compiled there. One node is enough.
#
# Assumes an MPI installation is available and the repo's submodules are
# initialized. Rationale for the non-obvious flags is in docs/design-notes.org.

module purge
module load mpich/3.1.4-gcc-9.3.0 gcc/9.3.0

export DEPS_DIR=${PWD}/deps
export PREFIX=${DEPS_DIR}/prefix
export CHARM_SRC_DIR=${DEPS_DIR}/charm

# PAPI, following https://github.com/icl-utk-edu/papi/wiki/Downloading-and-Installing-PAPI
if [ ! -d ${PREFIX} ]; then
    mkdir ${PREFIX}
fi

if [ ! -e ${PREFIX}/lib/libpapi.so ]; then
    BUILD_DIR=${DEPS_DIR}/build-papi-${SLURM_JOB_ID}
    echo "Building PAPI"
    cp -r ${DEPS_DIR}/papi/ ${BUILD_DIR}
    pushd ${BUILD_DIR}/src
    ./configure --prefix=${PREFIX}
    make -j
    make install
    popd
    #rm -rf ${BUILD_DIR}
    echo "Built PAPI"
else
    echo "PAPI already built"
fi
export PATH=${PREFIX}/bin:${PATH}
export LD_LIBRARY_PATH=${PREFIX}/lib:${LD_LIBRARY_PATH}
export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}
export CPATH=${PREFIX}/include:${CPATH}

# Variant 1/4: plain charm++ target.
CHARM_INSTALL_DIR=${PREFIX}/charm-base
if [ ! -e ${CHARM_INSTALL_DIR}/bin/charmc ]; then
    BUILD_DIR=${DEPS_DIR}/build-base-${SLURM_JOB_ID}
    echo "Building charm++ in $BUILD_DIR, installing in $CHARM_INSTALL_DIR"

    if [ ! -d ${BUILD_DIR} ]; then
	mkdir ${BUILD_DIR}
    fi

    cmake -S ${CHARM_SRC_DIR} -B ${BUILD_DIR} \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DARCH=x86_64 \
	  -DCMAKE_INSTALL_PREFIX=${CHARM_INSTALL_BASE} \
	  -DNETWORK=mpi \
	  -DTARGET=charm++
    cmake --build ${BUILD_DIR} -j
    cmake --install ${BUILD_DIR} --prefix ${CHARM_INSTALL_DIR}

    #rm -rf ${BUILD_DIR}
    echo "Built charm++"
else
    echo "Charm is already built"
fi

# Variant 2/4: charm++ target with Projections tracing and PAPI.
#
# -DZLIB=1 with an explicit numeric 1, NOT the ZLIB option's default, is what
# enables gzipped trace logs (*.log.gz). Charm's detect-features.cmake copies
# the option value verbatim into conv-autoconfig.h, so the default ON emits
# "#define CMK_USE_ZLIB ON", which the preprocessor evaluates as 0 and compiles
# the compression path out. Do not "simplify" this to -DZLIB=ON, and do not
# switch to Charm's ./build wrapper, which hardcodes zlib but cannot enable
# PAPI. Full derivation in docs/design-notes.org.
CHARM_INSTALL_DIR=${PREFIX}/charm-projections
if [ ! -e ${CHARM_INSTALL_DIR}/bin/charmc ]; then
    BUILD_DIR=${DEPS_DIR}/build-projections-${SLURM_JOB_ID}
    echo "Building charm++ projections in $BUILD_DIR, installing in $CHARM_INSTALL_DIR"

    if [ ! -d ${BUILD_DIR} ]; then
	mkdir ${BUILD_DIR}
    fi

    LDFLAGS="$(pkgconf --libs papi)" cmake -S ${CHARM_SRC_DIR} -B ${BUILD_DIR} \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DARCH=x86_64 \
	  -DCMAKE_INSTALL_PREFIX=${CHARM_INSTALL_BASE} \
	  -DNETWORK=mpi \
	  -DTRACING=TRUE \
	  -DPAPI=ON \
	  -DTRACING_COMMTHREAD=ON \
	  -DZLIB=1 \
	  -DTARGET=charm++
    LDFLAGS="-L${PREFIX}/lib" CFLAGS="-I${PREFIX}/include" cmake --build ${BUILD_DIR} -j
    cmake --install ${BUILD_DIR} --prefix ${CHARM_INSTALL_DIR}

    #rm -rf ${BUILD_DIR}
    echo "Built charm++ with projections"
else
    echo "Charm with projections is already built"
fi

# Variant 3/4: plain changa target.
CHARM_INSTALL_DIR=${PREFIX}/charm-changa
if [ ! -e ${CHARM_INSTALL_DIR}/bin/charmc ]; then
    BUILD_DIR=${DEPS_DIR}/build-changa-${SLURM_JOB_ID}
    echo "Building charm++ changa target in $BUILD_DIR, installing in $CHARM_INSTALL_DIR"

    if [ ! -d ${BUILD_DIR} ]; then
	mkdir ${BUILD_DIR}
    fi

    cmake -S ${CHARM_SRC_DIR} -B ${BUILD_DIR} \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DARCH=x86_64 \
	  -DCMAKE_INSTALL_PREFIX=${CHARM_INSTALL_BASE} \
	  -DNETWORK=mpi \
	  -DTARGET=changa
    cmake --build ${BUILD_DIR} -j
    cmake --install ${BUILD_DIR} --prefix ${CHARM_INSTALL_DIR}

    #rm -rf ${BUILD_DIR}
    echo "Built charm++ with changa target"
else
    echo "Charm with changa target is already built"
fi

# ChaNGa's ./configure sources $CHARM_DIR/tmp/conv-config.sh. Charm's
# CMake build ships conv-config.sh inside include/ and makes tmp a symlink
# to it, but the install() rules only copy bin/include/lib — not that
# symlink — so recreate it in the install prefix. Kept outside the guard
# above so re-running this script repairs an already-built install without
# a full rebuild.
ln -sfn include ${CHARM_INSTALL_DIR}/tmp

# Variant 4/4: changa target with Projections tracing and PAPI. Same -DZLIB=1
# reasoning as variant 2 above.
CHARM_INSTALL_DIR=${PREFIX}/charm-changa-projections
if [ ! -e ${CHARM_INSTALL_DIR}/bin/charmc ]; then
    BUILD_DIR=${DEPS_DIR}/build-changa-projections-${SLURM_JOB_ID}
    echo "Building charm++ with changa target and projections tracing in $BUILD_DIR, installing in $CHARM_INSTALL_DIR"

    if [ ! -d ${BUILD_DIR} ]; then
	mkdir ${BUILD_DIR}
    fi

    LDFLAGS="$(pkgconf --libs papi)" cmake -S ${CHARM_SRC_DIR} -B ${BUILD_DIR} \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DARCH=x86_64 \
	  -DCMAKE_INSTALL_PREFIX=${CHARM_INSTALL_BASE} \
	  -DNETWORK=mpi \
	  -DTRACING=TRUE \
	  -DPAPI=ON \
	  -DTRACING_COMMTHREAD=ON \
	  -DZLIB=1 \
	  -DTARGET=changa
    LDFLAGS="-L${PREFIX}/lib" CFLAGS="-I${PREFIX}/include" cmake --build ${BUILD_DIR} -j
    cmake --install ${BUILD_DIR} --prefix ${CHARM_INSTALL_DIR}

    #rm -rf ${BUILD_DIR}
    echo "Built charm++ with changa target and projections tracing"
else
    echo "Charm with changa target and projections tracing is already built"
fi

# See the changa base variant above: recreate the tmp -> include symlink
# ChaNGa's ./configure needs to source conv-config.sh, outside the guard
# so re-running repairs an already-built install.
ln -sfn include ${CHARM_INSTALL_DIR}/tmp
