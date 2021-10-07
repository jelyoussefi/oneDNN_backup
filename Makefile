#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL:=/bin/bash

CURRENT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=${CURRENT_DIR}/build
TOOLCHAIN_DIR?=${CURRENT_DIR}/toolchain

export TERM=xterm

CUDA ?= ON

CMAKE_FLAGS = 	-DDNNL_LIBRARY_TYPE=SHARED \
      		-DCMAKE_BUILD_TYPE=release \
      		-DDNNL_CPU_RUNTIME=DPCPP \
      		-DDNNL_GPU_RUNTIME=DPCPP \
		-DDNNL_BUILD_EXAMPLES=ON      
		
ifeq ($(CUDA),ON)
CMAKE_FLAGS := ${CMAKE_FLAGS} \
		-DCMAKE_C_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang \
      		-DCMAKE_CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++ \
      		-DDNNL_SYCL_CUDA=ON \
      		-DDNNL_GPU_VENDOR=NVIDIA \
      		-DCUDA_DRIVER_LIBRARY=/usr/local/cuda/targets/x86_64-linux/lib/stubs/libcuda.so \
		-DOpenCL_INCLUDE_DIR=${TOOLCHAIN_DIR}/llvm/build/install/include/sycl/ \
      		-DOpenCL_LIBRARY=${TOOLCHAIN_DIR}/llvm/build/lib/libOpenCL.so \
      		-DCUBLAS_INCLUDE_DIR=/usr/local/cuda/targets/x86_64-linux/include/ \
      		-DCUBLAS_LIBRARY=/usr/local/cuda/targets/x86_64-linux/lib/libcublas.so 
      		
TOOLCHAIN_FLAGS = --cuda --cmake-opt=-DCMAKE_PREFIX_PATH="/usr/local/cuda/lib64/stubs/"

endif

CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++
CXX_FLAGS="-fsycl -fopenmp -O3  "

#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: build 
.PHONY: build

toolchain:

	@if [ ! -f "${TOOLCHAIN_DIR}/llvm/build/bin/clang" ]; then \
		mkdir -p ${TOOLCHAIN_DIR} && rm -rf ${TOOLCHAIN_DIR}/* && \
		$(call msg,Building Cuda Toolchain  ...) && \
		cd ${TOOLCHAIN_DIR} && \
			dpkg -l ninja-build  > /dev/null 2>&1  || sudo apt install -y ninja-build && \
			git clone https://github.com/intel/llvm -b sycl && \
			cd llvm && \
				python ./buildbot/configure.py   ${TOOLCHAIN_FLAGS} && \
				python ./buildbot/compile.py && \
		touch ${TOOLCHAIN_DIR}/.done; \
	fi


build: toolchain	
	@$(call msg,Building oneDNN  ...)
	@mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} && \
		CXX=${CXX_COMPILER} \
		CXXFLAGS=${CXX_FLAGS} \
		bash -c  ' \
		cmake ${CMAKE_FLAGS} .. && \
		make  -j`nproc` '

install:
	@$(call msg,Installing oneDNN  ...)
	@cd ${BUILD_DIR} && \
		sudo make install

clean:
	@rm -rf  ${BUILD_DIR}


distclean: clean
	@rm -rf ${TOOLCHAIN_DIR}
	
#----------------------------------------------------------------------------------------------------------------------
# helper functions
#----------------------------------------------------------------------------------------------------------------------
define msg
	tput setaf 2 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo  "" && \
	echo "         "$1 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo "" && \
	tput sgr0
endef

