
#ifndef DLSC_WB_TYPES_H_INCLUDED
#define DLSC_WB_TYPES_H_INCLUDED

namespace dlsc {

enum wishbone_cti {
    WB_CTI_CLASSIC      = 0x0,
    WB_CTI_FIXED        = 0x1,
    WB_CTI_INCR         = 0x2,
    WB_CTI_END          = 0x7
};

}; // end namespace dlsc

#endif

