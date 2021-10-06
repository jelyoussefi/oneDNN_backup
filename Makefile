#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL:=/bin/bash

CURRENT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=${CURRENT_DIR}/build
TOOLCHAIN_DIR=${CURRENT_DIR}/toolchain
TOOLS_DIR=${CURRENT_DIR}/tools

ONEAPI_ROOT ?= /opt/intel/oneapi
export TERM=xterm

CUDA ?= OFF

CMAKE_FLAGS = 	-DDNNL_CPU_RUNTIME=DPCPP \
		-DDNNL_GPU_RUNTIME=DPCPP \
      		-DDNNL_GPU_VENDOR=NVIDIA  \
		-DDNNL_SYCL_CUDA=ON \
		-DCMAKE_PREFIX_PATH=/usr/local/cuda/ \
		-DDNNL_GPU_VENDOR=NVIDIA \
		-DCUDA_DRIVER_LIBRARY=/usr/local/cuda/targets/x86_64-linux/lib/stubs/libcuda.so \
		-DOPENCLROOT=/usr/local/cuda \
		-DCUBLAS_INCLUDE_DIR=/usr/local/cuda/targets/x86_64-linux/include/ \
		-DCUBLAS_LIBRARY=/usr/local/cuda/targets/x86_64-linux/lib/libcublas.so 
 
 #     		-DOPENCLROOT=/usr/local/cuda-11.4/targets/x86_64-linux/lib

export CC=${ONEAPI_ROOT}/compiler/latest/linux/bin/clang
export CXX=${ONEAPI_ROOT}/compiler/latest/linux/bin/clang++


#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: build 
.PHONY: build

toolchain:
ifeq (${CUDA},ON)
	@if [ ! -f "${TOOLCHAIN_DIR}/.done" ]; then \
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
endif

install-oneapi:
	@if [ ! -f "${ONEAPI_ROOT}/setvars.sh" ]; then \
		$(call msg,Installing OneAPI ...) && \
		sudo apt update -y  && \
		sudo apt install -y wget software-properties-common && \
		wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo echo "deb https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list && \
		sudo add-apt-repository "deb https://apt.repos.intel.com/oneapi all main" && \
		sudo apt update -y && \
		sudo apt install -y intel-basekit ; \
	fi
	
build: toolchain	
	@$(call msg,Building oneDNN  ...)
	mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} && \
		bash -c  'source ${ONEAPI_ROOT}/setvars.sh --force && \
		cmake ${CMAKE_FLAGS} .. && \
		make -j`nproc` '


install:
	@$(call msg,Installing oneDNN  ...)
	@sudo make install

clean:
	@rm -rf  ${BUILD_DIR}



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

