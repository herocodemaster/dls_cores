
#include <stdexcept>
#include <iomanip>

#include <systemc>

#include "dlsc_common.h"

#include "dlsc_pcie_tlp.h"

using namespace std;
using namespace sc_dt;
using namespace dlsc::pcie;

pcie_tlp::pcie_tlp() : name_str("pcie_tlp") {
    clear();
}

pcie_tlp::pcie_tlp(const char *nm) : name_str(nm) {
    clear();
}
    

void pcie_tlp::clear() {
    malformed   = false;

    fmt         = FMT_3DW;
    type        = TYPE_MEM;
    tc          = 0;
    td          = 0;
    ep          = 0;
    attr_ro     = false;
    attr_ns     = false;
    length      = 1;

    src_id      = 0;
    src_tag     = 0;
    cpl_status  = CPL_SC;
    cpl_bcm     = false;
    cpl_bytes   = 1;
    be_last     = 0;
    be_first    = 0;
    msg_code    = 0;

    dest_addr   = 0;
    dest_id     = 0;
    cpl_tag     = 0;
    cpl_addr    = 0;
    cfg_reg     = 0;
    
    data.clear();
    digest      = 0;

    fmt_size    = 0;
    fmt_4dw     = false;
    fmt_data    = false;
    type_mem    = false;
    type_io     = false;
    type_cfg    = false;
    type_msg    = false;
    type_cpl    = false;
    non_posted  = false;
    digest_size = 0;
}

bool pcie_tlp::set_format(pcie_fmt f) {
    fmt         = f;
    fmt_4dw     = (fmt == FMT_4DW || fmt == FMT_4DW_DATA);
    fmt_size    = fmt_4dw ? 4 : 3;
    fmt_data    = (fmt == FMT_3DW_DATA || fmt == FMT_4DW_DATA);
    if(type_mem) {
        non_posted  = !fmt_data;    // only non-posted if it is a read (no data)
    }
    return true;
}

bool pcie_tlp::set_type(pcie_type t) {
    type_mem    = false;
    type_io     = false;
    type_cfg    = false;
    type_msg    = false;
    type_cpl    = false;
    non_posted  = false;
    
    type        = t;
    
    switch(type) {
        case TYPE_MEM:
        case TYPE_MEM_LOCKED:
            type_mem    = true;
            non_posted  = !fmt_data;    // only non-posted if it is a read (no data)
            break;
        case TYPE_IO:
            type_io     = true;
            non_posted  = true;
            break;
        case TYPE_CONFIG_0:
        case TYPE_CONFIG_1:
            type_cfg    = true;
            non_posted  = true;
            break;
        case TYPE_MSG_TO_RC:
        case TYPE_MSG_BY_ADDR:
        case TYPE_MSG_BY_ID:
        case TYPE_MSG_FROM_RC:
        case TYPE_MSG_LOCAL:
        case TYPE_MSG_PME_RC:
            type_msg    = true;
            non_posted  = true;
            break;
        case TYPE_CPL:
        case TYPE_CPL_LOCKED:
            type_cpl    = true;
            break;
        default:
            return false;
    }

    return true;
}

void pcie_tlp::set_traffic_class(unsigned int traffic_class) {
    if(traffic_class >= 8) {
        throw invalid_argument("invalid traffic class");
    }
    tc          = traffic_class;
}

void pcie_tlp::set_digest(uint32_t dg) {
    td          = true;
    digest      = dg;
    digest_size = 1;
}

void pcie_tlp::set_poisoned(bool poison=true) {
    ep          = poison;
}

void pcie_tlp::set_attributes(bool relaxed_ordering, bool no_snoop) {
    attr_ro     = relaxed_ordering;
    attr_ns     = no_snoop;
}

void pcie_tlp::set_length(unsigned int words) {
    if(words == 0 || words > 1024) {
        cout << "set_length(" << words << ")" << endl;
        throw invalid_argument("invalid length");
    }
    length      = words;
    if(length == 1) {
        be_last     = 0;
    }
}

void pcie_tlp::set_source(unsigned int id) {
    if(id > 0xFFFF) {
        throw invalid_argument("invalid source id");
    }
    src_id      = id;
}

void pcie_tlp::set_tag(unsigned int tag) {
    if(tag >= 256) {
        throw invalid_argument("invalid tag");
    }

    src_tag     = tag;
}

bool pcie_tlp::set_completion_status(pcie_cpl status) {
    cpl_status  = status;

    switch(cpl_status) {
        case CPL_SC:
        case CPL_UR:
        case CPL_CRS:
        case CPL_CA:
            break;
        default:
            return false;
    }

    return true;    
}

void pcie_tlp::set_completion(pcie_cpl status, bool bcm, unsigned int bytes, unsigned int tag, unsigned int lower_addr) {
    if(bytes == 0 || bytes > 4096 || tag >= 256 || lower_addr >= 128) {
        throw invalid_argument("invalid completion");
    }

    set_completion_status(status);

    cpl_bcm     = bcm;
    cpl_bytes   = bytes;
    cpl_tag     = tag;
    cpl_addr    = lower_addr;

    if(!type_cpl) {
        set_type(TYPE_CPL);
    }
}

void pcie_tlp::set_bcm(bool bcm) {
    cpl_bcm     = bcm;
}

void pcie_tlp::set_byte_count(unsigned int bytes) {
    if(bytes <= 0 || bytes > 4096) {
        throw invalid_argument("invalid byte count");
    }

    cpl_bytes   = bytes;
}

void pcie_tlp::set_lower_addr(unsigned int lower_addr) {
    if(lower_addr >= 128) {
        throw invalid_argument("invalid lower address");
    }

    cpl_addr    = lower_addr;
}

void pcie_tlp::set_completion_tag(unsigned int tag) {
    if(tag >= 256) {
        throw invalid_argument("invalid completion tag");
    }

    cpl_tag     = tag;
}

void pcie_tlp::set_byte_enables(unsigned int first, unsigned int last) {
    if(first > 0xF || last > 0xF) {
        throw invalid_argument("invalid byte-enables");
    }

    be_last     = last;
    be_first    = first;
}

void pcie_tlp::set_address(uint64_t address) {
    if((address & 0x3) != 0) {
        throw invalid_argument("invalid address");
    }

    if(address & 0xFFFFFFFF00000000ll) {
        set_format(fmt_data ? FMT_4DW_DATA : FMT_4DW);
    } else {
        set_format(fmt_data ? FMT_3DW_DATA : FMT_3DW);
    }

    dest_addr   = address;
}

void pcie_tlp::set_destination(unsigned int id) {
    if(id > 0xFFFF) {
        throw invalid_argument("invalid destination id");
    }
    dest_id      = id;
}

void pcie_tlp::set_data(const deque<uint32_t> &dw) {
    set_length(dw.size());
    set_format(fmt_4dw ? FMT_4DW_DATA : FMT_3DW_DATA);
    data        = dw;
}


bool pcie_tlp::deserialize(const deque<uint32_t> &dw) {
    clear();

    if(dw.empty()) {
        throw invalid_argument("no data");
    }

    sc_int<32> d;

    // ** bytes 0-3
    d           = dw.at(0);

    // format/header-size
    if(!set_format( static_cast<pcie_fmt>((int)d.range(30,29)) )) {
//        dlsc_error("invalid format");
        malformed = true;
        return false;
    }

    if(dw.size() < fmt_size) {
//        dlsc_error("insufficient header data (have " << dw.size() << ", but need " << fmt_size << ")");
        malformed = true;
        return false;
    }

    // type
    if(!set_type( static_cast<pcie_type>((int)d.range(28,24)) )) {
//        dlsc_error("invalid type");
        malformed = true;
        return false;
    }

    tc          = d.range(22,20);
    td          = d[15];
    ep          = d[14];
    attr_ro     = d[13];
    attr_ns     = d[12];
    length      = d.range(9,0);

    digest_size = td ? 1 : 0;

    if(length == 0) length = 1024;

    if(d[31] != 0 || d[23] != 0 || d.range(19,16) != 0 || d.range(11,10) != 0) {
        dlsc_warn("reserved bits non-zero");
    }

    // ** bytes 4-7
    d           = dw.at(1);

    src_id      = d.range(31,16);

    if(type_mem || type_io || type_cfg || type_msg) {
        src_tag     = d.range(15,8);
    }

    if(type_cpl) {
        if(!set_completion_status( static_cast<pcie_cpl>((int)d.range(15,13)) )) {
            dlsc_warn("reserved completion status");
        }
        cpl_bcm     = d[12];
        cpl_bytes   = d.range(11,0);
        if(cpl_bytes == 0) cpl_bytes = 4096;
    }

    if(type_mem || type_io || type_cfg) {
        be_last     = d.range(7,4);
        be_first    = d.range(3,0);
    }

    if(type_msg) {
        msg_code    = d.range(7,0);
    }

    // ** bytes 8-11

    d           = dw.at(2);

    if(type_mem || type_io || type == TYPE_MSG_BY_ADDR) {
        dest_addr   = 0;
        if(fmt_4dw) {
            dest_addr   = d;
            dest_addr   <<= 32;
            // ** bytes 12-15
            d           = dw.at(3);
        }
            
        dest_addr   |= d.range(31,2) << 2;
        
        if(d.range(1,0) != 0) {
            dlsc_warn("reserved bits non-zero");
        }
    }

    if(type_cfg || type_cpl || type == TYPE_MSG_BY_ID) {
        dest_id     = d.range(31,16);
    }

    if(type_cpl) {
        cpl_tag     = d.range(15,8);
        cpl_addr    = d.range(6,0);
        if(d[7] != 0) {
            dlsc_warn("reserved bits non-zero");
        }
    }

    if(type_cfg) {
        cfg_reg     = d.range(11,2);
        if(d.range(15,12) != 0 || d.range(1,0) != 0) {
            dlsc_warn("reserved bits non-zero");
        }
    }

    if(type_msg && type != TYPE_MSG_BY_ADDR && type != TYPE_MSG_BY_ID) {
        if(dw.at(2) != 0 || (fmt_4dw && dw.at(3) != 0)) {
            dlsc_warn("reserved bits non-zero");
        }
    }

    // ** payload

    if(fmt_data || td) {
//        if((dw.size()-fmt_size-digest_size) != length) {
//            dlsc_error("incorrect payload data length (have " << (dw.size()-fmt_size-digest_size) << ", but expected " << length << ")");
//            return false;
        data.assign(dw.begin()+fmt_size,dw.end()); // gets digest too
//        if(data.size() != length) {
//            malformed = true;
//        }
    }

    // ** digest
    if(td) {
        if(!data.empty()) {
            digest      = data.back();
            data.pop_back();
        } else {
            malformed = true;
        }
    }

    return true;
}

bool pcie_tlp::validate() const {

    if(malformed) {
        return false;
    }

    // ** assertions

    if(type_mem || type_io) {
        // 4K crossing
        dlsc_assert( ((dest_addr & 0xFFF) + length) <= 4096 );

        if(fmt_4dw) {
            dlsc_assert((dest_addr & 0xFFFFFFFF00000000ll) != 0);
        }
    }

    if(type_mem || type_io || type_cfg) {
        if(length == 1) {
            dlsc_assert(be_last == 0);
        }
        if(length > 1) {
            dlsc_assert(be_first != 0);
            dlsc_assert(be_last != 0);
        }
        if( (length == 1) || (length == 2 && type_mem && ((dest_addr & 0x7) == 0)) ) {
            // non-contiguous byte-enables okay
        } else {
            // TODO: not okay
        }
    }

    if(type_io || type_cfg) {
        dlsc_assert(fmt == FMT_3DW || fmt == FMT_3DW_DATA);
        dlsc_assert(tc == 0);
        dlsc_assert(attr_ro == false && attr_ns == false);
        dlsc_assert(length == 1);
    }

    if(type_msg) {
        dlsc_assert(attr_ro == false && attr_ns == false);
    }

    if(type_cpl) {
        dlsc_assert(fmt == FMT_3DW || fmt == FMT_3DW_DATA);
    }

    return true;
}

void pcie_tlp::serialize(deque<uint32_t> &dw) const {

    sc_int<32> d;

    // ** bytes 0-3
    d               = 0;

    d.range(30,29)  = fmt;
    d.range(28,24)  = type;
    d.range(22,20)  = tc;
    d[15]           = td;
    d[14]           = ep;
    d[13]           = attr_ro;
    d[12]           = attr_ns;
    d.range(9,0)    = (length == 1024) ? 0 : length;

    dw.push_back(d);
    
    // ** bytes 4-7
    d               = 0;

    d.range(31,16)  = src_id;
    
    if(type_mem || type_io || type_cfg || type_msg) {
        d.range(15,8) = src_tag;
    }

    if(type_cpl) {
        d.range(15,13)  = cpl_status;
        d[12]           = cpl_bcm;
        d.range(11,0)   = (cpl_bytes == 4096) ? 0 : cpl_bytes;
    }

    if(type_mem || type_io || type_cfg) {
        d.range(7,4)    = be_last;
        d.range(3,0)    = be_first;
    }

    if(type_msg) {
        d.range(7,0)    = msg_code;
    }
    
    dw.push_back(d);

    // ** bytes 8-11/15
    
    if(type_mem || type_io || type == TYPE_MSG_BY_ADDR) {
        if(fmt_4dw) {
            dw.push_back(dest_addr >> 32);
        }
        dw.push_back(dest_addr & 0xFFFFFFFC);
    } else {
        d               = 0;

        if(type_cfg || type_cpl || type == TYPE_MSG_BY_ID) {
            d.range(31,16)  = dest_id;
        }

        if(type_cpl) {
            d.range(15,8)   = cpl_tag;
            d.range(6,0)    = cpl_addr;
        }

        if(type_cfg) {
            d.range(11,2)   = cfg_reg;
        }

        dw.push_back(d);

        if(fmt_4dw) {
            dw.push_back(0);
        }
    }

    // ** payload
    if(fmt_data) {
        dw.insert(dw.end(),data.begin(),data.end());
    }

    // ** digest
    if(td) {
        dw.push_back(digest);
    }
}

ostream& dlsc::pcie::operator << ( ostream &os, const pcie_tlp &tlp ) {

    os << "==== PCIe TLP ====" << endl;
    
    // ** bytes 0-3

    os << " Format:             " << tlp.fmt << endl;
    os << " Type:               " << tlp.type << endl;
    os << " Traffic class:      " << dec << tlp.tc << endl;
    os << " Digest present:     " << dec << tlp.td << endl;
    os << " Poisoned:           " << dec << tlp.ep << endl;
    os << " Relaxed ordering:   " << dec << tlp.attr_ro << endl;
    os << " No-snoop:           " << dec << tlp.attr_ns << endl;
    os << " Length:             " << dec << tlp.length << endl;

    // ** bytes 4-7

    os << " Source ID:          0x" << hex << setw(4) << setfill('0') << tlp.src_id << endl;
    
    if(tlp.type_mem || tlp.type_io || tlp.type_cfg || tlp.type_msg) {
        os << " Source tag:         0x" << hex << setw(2) << setfill('0') <<  tlp.src_tag << endl;
    }

    if(tlp.type_cpl) {
        os << " Completion status:  " << tlp.cpl_status << endl;
        os << " Byte-count-mod:     " << dec << tlp.cpl_bcm << endl;
        os << " Remaining bytes:    " << dec << tlp.cpl_bytes << endl;
    }

    if(tlp.type_mem || tlp.type_io || tlp.type_cfg) {
        os << " Last DW BE:         0x" << hex << tlp.be_last << endl;
        os << " First DW BE:        0x" << hex << tlp.be_first << endl;
    }

    if(tlp.type_msg) {
        os << " Message code:       0x" << hex << setw(2) << setfill('0') << tlp.msg_code << endl;
    }
    
    // ** bytes 8-11/15
    
    if(tlp.type_mem || tlp.type_io || tlp.type == TYPE_MSG_BY_ADDR) {
        os << " Address:            0x" << hex << setfill('0');
        if(tlp.fmt_4dw) {
            os << setw(16);
        } else {
            os << setw(8);
        }
        os << tlp.dest_addr << endl;
    }

    if(tlp.type_cfg || tlp.type_cpl || tlp.type == TYPE_MSG_BY_ID) {
        os << " Dest ID:            0x" << hex << setw(4) << setfill('0') << tlp.dest_id << endl;
    }

    if(tlp.type_cpl) {
        os << " Completion tag:     0x" << hex << setw(2) << setfill('0') << tlp.cpl_tag << endl;
        os << " Completion address: 0x" << hex << setw(2) << setfill('0') << tlp.cpl_addr << endl;
    }

    if(tlp.type_cfg) {
        os << " Config register:    0x" << hex << tlp.cfg_reg << endl;
    }
    
    // ** digest
    if(tlp.td) {
        os << " Digest:             0x" << hex << setw(8) << setfill('0') << tlp.digest << endl;
    }
    
    // ** payload
    if(tlp.fmt_data) {
        for(unsigned int i=0;i<tlp.data.size();i=i+1) {
            os << " Data[" << dec << setw(4) << setfill(' ') << i << "]:         0x" << hex << setw(8) << setfill('0') << tlp.data.at(i) << endl;
        }
    }
    
    os << "==================" << endl;

    return os;
}

bool pcie_tlp::operator==(const pcie_tlp &tlp) const {
    if(fmt      != tlp.fmt      ||
       type     != tlp.type     ||
       tc       != tlp.tc       ||
       td       != tlp.td       ||
       ep       != tlp.ep       ||
       attr_ro  != tlp.attr_ro  ||
       attr_ns  != tlp.attr_ns  ||
       length   != tlp.length   ||
       src_id   != tlp.src_id) {
        return false;
    }

    if(type_mem || type_io || type_cfg || type_msg) {
        if(src_tag      != tlp.src_tag) {
            return false;
        }
    }

    if(type_cpl) {
        if(cpl_status   != tlp.cpl_status   ||
           cpl_bcm      != tlp.cpl_bcm      ||
           cpl_bytes    != tlp.cpl_bytes    ||
           cpl_tag      != tlp.cpl_tag      ||
           cpl_addr     != tlp.cpl_addr) {
            return false;
        }
    }

    if(type_mem || type_io || type_cfg) {
        if(be_last      != tlp.be_last      ||
           be_first     != tlp.be_first) {
            return false;
        }
    }

    if(type_msg) {
        if(msg_code     != tlp.msg_code) {
            return false;
        }
    }

    if(type_mem || type_io) {
        if(dest_addr    != tlp.dest_addr) {
            return false;
        }
    }

    if(type_cfg || type_cpl) {
        if(dest_id      != tlp.dest_id) {
            return false;
        }
    }

    if(type_cfg) {
        if(cfg_reg      != tlp.cfg_reg) {
            return false;
        }
    }

    if(fmt_data) {
        if(data         != tlp.data) {
            return false;
        }
    }

    if(td) {
        if(digest       != tlp.digest) {
            return false;
        }
    }

    return true;
}

ostream& dlsc::pcie::operator << ( ostream &os, const pcie_fmt &fmt ) {
    switch(fmt) {
        case FMT_3DW:       os << "3DW (no data)"; break;
        case FMT_4DW:       os << "4DW (no data)"; break;
        case FMT_3DW_DATA:  os << "3DW (with data)"; break;
        case FMT_4DW_DATA:  os << "4DW (with data)"; break;
    }
    return os;
}

ostream& dlsc::pcie::operator << ( ostream &os, const pcie_type &type ) {
    switch(type) {
        case TYPE_MEM:          os << "Memory"; break;
        case TYPE_MEM_LOCKED:   os << "Memory (locked)"; break;
        case TYPE_IO:           os << "I/O"; break;
        case TYPE_CONFIG_0:     os << "Config (type 0)"; break;
        case TYPE_CONFIG_1:     os << "Config (type 1)"; break;
        case TYPE_MSG_TO_RC:    os << "Message (routed to RC)"; break;
        case TYPE_MSG_BY_ADDR:  os << "Message (routed by address)"; break;
        case TYPE_MSG_BY_ID:    os << "Message (routed by ID)"; break;
        case TYPE_MSG_FROM_RC:  os << "Message (broadcast from RC)"; break;
        case TYPE_MSG_LOCAL:    os << "Message (local - terminate at receiver)"; break;
        case TYPE_MSG_PME_RC:   os << "Message (gathered and routed to RC)"; break;
        case TYPE_CPL:          os << "Completion"; break;
        case TYPE_CPL_LOCKED:   os << "Completion (locked)"; break;
        default:                os << "Reserved";
    }
    return os;
}

ostream& dlsc::pcie::operator << ( ostream &os, const pcie_cpl &cpl ) {
    switch(cpl) {
        case CPL_SC:    os << "Successful Completion (SC)"; break;
        case CPL_UR:    os << "Unsupported Request (UR)"; break;
        case CPL_CRS:   os << "Configuration Request Retry Status (CRS)"; break;
        case CPL_CA:    os << "Completer Abort (CA)"; break;
        default:        os << "Reserved";
    }
    return os;
}
