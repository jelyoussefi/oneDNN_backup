/*******************************************************************************
* Copyright 2020 Intel Corporation
* Copyright 2020 Codeplay Software Limited
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*******************************************************************************/

#include "gpu/nvidia/cudnn_eltwise.hpp"
#include "gpu/nvidia/sycl_cuda_scoped_context.hpp"
#include "gpu/nvidia/sycl_cuda_stream.hpp"
#include "sycl/sycl_buffer_memory_storage.hpp"

namespace dnnl {
namespace impl {
namespace gpu {
namespace nvidia {

status_t cudnn_eltwise_fwd_t::execute(const exec_ctx_t &ctx) const {
    if (memory_desc_wrapper(pd()->src_md()).has_zero_dim())
        return status::success;

    nvidia::sycl_cuda_stream_t *cuda_stream
            = utils::downcast<nvidia::sycl_cuda_stream_t *>(ctx.stream());

    auto &src = CTX_IN_STORAGE(DNNL_ARG_SRC);
    auto &dst = CTX_OUT_STORAGE(DNNL_ARG_DST);



    return cuda_stream->interop_task([&](cl::sycl::handler &cgh) {
        auto buf = sycl::buffer<void, 1>(1);
        bool src_usm = CTX_IN_IS_USM(DNNL_ARG_SRC);
        bool dst_usm = CTX_OUT_IS_USM(DNNL_ARG_DST);

        auto src_acc = !src_usm ? CTX_IN_ACCESSOR(DNNL_ARG_SRC) : buf.get_access<sycl::access::mode::read>(cgh);
        auto dst_acc = !dst_usm ? CTX_OUT_ACCESSOR(DNNL_ARG_DST) : buf.get_access<sycl::access::mode::write>(cgh);

        printf("==============OK")
        cgh.host_task([=](const cl::sycl::interop_handle &ih) {
            std::vector<void *> args;
            auto &sycl_engine = *utils::downcast<sycl_cuda_engine_t *>(
                    cuda_stream->engine());
            auto sc = cuda_sycl_scoped_context_handler_t(sycl_engine);
            auto handle = cuda_stream->get_cudnn_handle();

            args.push_back(sc.memory<void *>(ih, src_acc));
            args.push_back(sc.memory<void *>(ih, dst_acc));

            pd()->eltwise_fwd_impl_->execute(handle, args.data(), args.size());
        });
    });
}

status_t cudnn_eltwise_bwd_t::execute(const exec_ctx_t &ctx) const {
    if (memory_desc_wrapper(pd()->src_md()).has_zero_dim())
        return status::success;

 
    nvidia::sycl_cuda_stream_t *cuda_stream
            = utils::downcast<nvidia::sycl_cuda_stream_t *>(ctx.stream());

    return cuda_stream->interop_task([&](cl::sycl::handler &cgh) {
        auto src_acc = CTX_IN_ACCESSOR(DNNL_ARG_SRC);
        auto diff_dst_acc = CTX_IN_ACCESSOR(DNNL_ARG_DIFF_DST);
        auto diff_src_acc = CTX_OUT_ACCESSOR(DNNL_ARG_DIFF_SRC);

        cgh.host_task([=](const cl::sycl::interop_handle &ih) {
            std::vector<void *> args;
            auto &sycl_engine = *utils::downcast<sycl_cuda_engine_t *>(
                    cuda_stream->engine());
            auto sc = cuda_sycl_scoped_context_handler_t(sycl_engine);
            auto handle = cuda_stream->get_cudnn_handle();

            args.push_back(sc.memory<void *>(ih, src_acc));
            args.push_back(sc.memory<void *>(ih, diff_dst_acc));
            args.push_back(sc.memory<void *>(ih, diff_src_acc));

            pd()->eltwise_bwd_impl_->execute(handle, args.data(), args.size());
        });
    });
}

} // namespace nvidia
} // namespace gpu
} // namespace impl
} // namespace dnnl
