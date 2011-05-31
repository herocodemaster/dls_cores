
#ifndef DLSC_AXI_TYPES_H_INCLUDED
#define DLSC_AXI_TYPES_H_INCLUDED

#include <stdint.h>

namespace dlsc {
    namespace axi {

struct axi_ar {
    uint32_t    id;
    uint32_t    addr;
    uint32_t    len;
    uint32_t    size;
    uint32_t    burst;
    uint32_t    lock;

    } // end namespace axi
} // end namespace dlsc

#endif

