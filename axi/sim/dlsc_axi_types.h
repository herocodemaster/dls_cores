
#ifndef DLSC_AXI_TYPES_H_INCLUDED
#define DLSC_AXI_TYPES_H_INCLUDED

namespace dlsc {

enum axi_burst {
    AXI_BURST_FIXED     = 0x0,
    AXI_BURST_INCR      = 0x1,
    AXI_BURST_WRAP      = 0x2
};

enum axi_resp {
    AXI_RESP_OKAY       = 0x0,
    AXI_RESP_EXOKAY     = 0x1,
    AXI_RESP_SLVERR     = 0x2,
    AXI_RESP_DECERR     = 0x3
};

enum axi_lock {
    AXI_LOCK_NORMAL     = 0x0,
    AXI_LOCK_EXCLUSIVE  = 0x1,
    AXI_LOCK_LOCKED     = 0x2
};

const unsigned int AXI_CACHE_B          = 0x1;
const unsigned int AXI_CACHE_C          = 0x2;
const unsigned int AXI_CACHE_RA         = 0x4;
const unsigned int AXI_CACHE_WA         = 0x8;

const unsigned int AXI_PROT_PRIVILEGED  = 0x1;
const unsigned int AXI_PROT_NONSECURE   = 0x2;
const unsigned int AXI_PROT_INSTRUCTION = 0x4;

}; // end namespace dlsc

#endif

