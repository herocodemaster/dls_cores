
#ifndef DLSC_PCIE_TLP_SCV_H_INCLUDED
#define DLSC_PCIE_TLP_SCV_H_INCLUDED

#include "dlsc_pcie_tlp.h"
#include <scv.h>

using namespace dlsc::pcie;

SCV_ENUM_EXTENSIONS(pcie_fmt) {
public:
    SCV_ENUM_CTOR(pcie_fmt) {
        SCV_ENUM(FMT_3DW);
        SCV_ENUM(FMT_4DW);
        SCV_ENUM(FMT_3DW_DATA);
        SCV_ENUM(FMT_4DW_DATA);
    }
};

SCV_ENUM_EXTENSIONS(pcie_type) {
public:
    SCV_ENUM_CTOR(pcie_type) {
        SCV_ENUM(TYPE_MEM);
        SCV_ENUM(TYPE_MEM_LOCKED);
        SCV_ENUM(TYPE_IO);
        SCV_ENUM(TYPE_CONFIG_0);
        SCV_ENUM(TYPE_CONFIG_1);
        SCV_ENUM(TYPE_MSG_TO_RC);
        SCV_ENUM(TYPE_MSG_BY_ADDR);
        SCV_ENUM(TYPE_MSG_BY_ID);
        SCV_ENUM(TYPE_MSG_FROM_RC);
        SCV_ENUM(TYPE_MSG_LOCAL);
        SCV_ENUM(TYPE_MSG_PME_RC);
        SCV_ENUM(TYPE_CPL);
        SCV_ENUM(TYPE_CPL_LOCKED);
    }
};

SCV_ENUM_EXTENSIONS(pcie_cpl) {
public:
    SCV_ENUM_CTOR(pcie_cpl) {
        SCV_ENUM(CPL_SC);
        SCV_ENUM(CPL_UR);
        SCV_ENUM(CPL_CRS);
        SCV_ENUM(CPL_CA);
    }
};

#endif

