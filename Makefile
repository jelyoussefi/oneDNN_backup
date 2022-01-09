#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL:=/bin/bash

CURRENT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=${CURRENT_DIR}/build
TOOLCHAIN_DIR?=${CURRENT_DIR}/toolchain
ONEAPI_ROOT ?= /opt/intel/oneapi
LLVM_SYCL_TAG?=2021-WW40

export TERM=xterm

CUDA ?= OFF

CMAKE_FLAGS = 	-DDNNL_LIBRARY_TYPE=SHARED \
      		-DCMAKE_BUILD_TYPE=release \
      		-DDNNL_CPU_RUNTIME=DPCPP \
      		-DDNNL_GPU_RUNTIME=DPCPP \
		-DDNNL_BUILD_EXAMPLES=ON      
		-DCMAKE_C_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang \
      		-DCMAKE_CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++ \
		
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
CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++
else
PATH := /opt/intel/oneapi/compiler/latest/linux/bin/:${PATH}
CXX_COMPILER=${ONEAPI_ROOT}/compiler/latest/linux/bin/dpcpp
LD_LIBRARY_PATH=$(shell source ${ONEAPI_ROOT}/setvars.sh --force > \
	/dev/null 2>&1 && env | grep ^LD_LIBRARY_PATH | awk -F"=" '{print $$2}')

endif

CXX_FLAGS="-fsycl -fopenmp -O3 -g "

export PATH

#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: build 
.PHONY: build


toolchain:
ifeq ($(CUDA),ON)
ifneq ($(shell which apt 2>/dev/null ),)
	@sudo apt install -y ninja-build
else ifneq ($(shell which zypper),)
	@sudo zypper install -y ninja
endif

	@if [ ! -f "${TOOLCHAIN_DIR}/llvm/build/bin/clang" ]; then \
		$(call msg,Building Cuda Toolchain  ...)  && \
		mkdir -p ${TOOLCHAIN_DIR} && rm -rf ${TOOLCHAIN_DIR}/* && \
		cd ${TOOLCHAIN_DIR} && \
			git clone https://github.com/intel/llvm -b sycl && \
			cd llvm && \
				python ./buildbot/configure.py   ${TOOLCHAIN_FLAGS} && \
				python ./buildbot/compile.py; \
	fi
endif

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
# Docker
#----------------------------------------------------------------------------------------------------------------------
DOCKER_FILE = Dockerfile
DOCKER_IMAGE_NAME = mammo-poc
DOCKER_RUN_FLAGS=--privileged -v /dev:/dev 

ifeq ($(CUDA),ON)
	DOCKER_FILE := ${DOCKER_FILE}-cuda
	DOCKER_IMAGE_NAME:=${DOCKER_IMAGE_NAME}-cuda
	DOCKER_RUN_FLAGS = --env CUDA=ON --gpus all
endif

DOCKER_BUILD_FLAGS:= --build-arg CUDA=${CUDA} 

docker-build: 
	@$(call msg, Building docker image ${DOCKER_IMAGE_NAME}  ...)
	@docker build   -f ${DOCKER_FILE} ${DOCKER_BUILD_FLAGS} -t ${DOCKER_IMAGE_NAME} .

docker-run:
	@$(call msg, Running docker container for ${DOCKER_IMAGE_NAME} image  ...)
	docker run -it -a stdout -a stderr --network=host ${DOCKER_RUN_FLAGS}  ${DOCKER_IMAGE_NAME} bash
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

