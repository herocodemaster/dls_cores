
#ifndef DLSC_PCIE_TLP_H_INCLUDED
#define DLSC_PCIE_TLP_H_INCLUDED

#include <iostream>
#include <string>
#include <deque>
#include <stdint.h>

namespace dlsc {
    namespace pcie {

enum pcie_fmt {
    FMT_3DW             = 0x0,
    FMT_4DW             = 0x1,
    FMT_3DW_DATA        = 0x2,
    FMT_4DW_DATA        = 0x3
};

enum pcie_type {
    TYPE_MEM            = 0x00,
    TYPE_MEM_LOCKED     = 0x01,
    TYPE_IO             = 0x02,
    TYPE_CONFIG_0       = 0x04,
    TYPE_CONFIG_1       = 0x05,
    TYPE_MSG_TO_RC      = 0x10,
    TYPE_MSG_BY_ADDR    = 0x11,
    TYPE_MSG_BY_ID      = 0x12,
    TYPE_MSG_FROM_RC    = 0x13,
    TYPE_MSG_LOCAL      = 0x14,
    TYPE_MSG_PME_RC     = 0x15,
    TYPE_CPL            = 0x0A,
    TYPE_CPL_LOCKED     = 0x0B
};

enum pcie_cpl {
    CPL_SC              = 0x0,
    CPL_UR              = 0x1,
    CPL_CRS             = 0x2,
    CPL_CA              = 0x4
};

class pcie_tlp {

public:
    bool            malformed;

    // ** bytes 0-3
    // header (all)
    pcie_fmt        fmt;        // [30:29]
    pcie_type       type;       // [28:24]
    unsigned int    tc;         // [22:20]  traffic class
    bool            td;         // [15]     digest present
    bool            ep;         // [14]     poisoned
    bool            attr_ro;    // [13]     relaxed-ordering
    bool            attr_ns;    // [12]     no-snoop
    unsigned int    length;     // [9:0]    payload length in 32-bit dwords

    // ** bytes 4-7
    // requester/completer (all)
    unsigned int    src_id;     // [31:16]

    // request tag (memory, I/O, config, messages)
    unsigned int    src_tag;    // [15:8]

    // completion fields (completions)
    pcie_cpl        cpl_status; // [15:13]
    bool            cpl_bcm;    // [12]
    unsigned int    cpl_bytes;  // [11:0]

    // byte-enables (memory, I/O, config)
    unsigned int    be_last;    // [7:4]
    unsigned int    be_first;   // [3:0]

    // message code (messages)
    unsigned int    msg_code;   // [7:0]

    // ** bytes 8-11 (3DW) or 8-15 (4DW)
    // address-based routing (memory, I/O)
    uint64_t        dest_addr;  // [31:2]

    // ID-based routing (config, completions)
    unsigned int    dest_id;    // [31:16]

    // completion fields (completions)
    unsigned int    cpl_tag;    // [15:8]
    unsigned int    cpl_addr;   // [6:0]

    // config fields (config)
    unsigned int    cfg_reg;    // [11:2]

    // ** payload
    std::deque<uint32_t> data;
    uint32_t        digest;

    // decoded fields
    unsigned int    fmt_size;
    bool            fmt_4dw;
    bool            fmt_data;
    bool            type_mem;
    bool            type_io;
    bool            type_cfg;
    bool            type_msg;
    bool            type_cpl;
    unsigned int    digest_size;

    inline bool is_write() const { return fmt_data; }
    inline bool is_read() const { return !fmt_data; }

    inline bool is_posted() const { return type_mem && fmt_data; }

    inline unsigned int size() const { return length; }

public:
    pcie_tlp();
    pcie_tlp(const char *nm);

    const std::string name_str;

    inline const char *name() const { return name_str.c_str(); }

    void clear();

    bool set_format(pcie_fmt f);
    bool set_type(pcie_type t);
    void set_traffic_class(unsigned int traffic_class);
    void set_digest(uint32_t dg);
    void set_poisoned(bool poison);
    void set_attributes(bool relaxed_ordering, bool no_snoop);
    void set_length(unsigned int words);
    void set_source(unsigned int id);
    void set_tag(unsigned int tag);
    bool set_completion_status(pcie_cpl status);
    void set_bcm(bool bcm);
    void set_byte_count(unsigned int bytes);
    void set_lower_addr(unsigned int lower_addr);
    void set_completion_tag(unsigned int tag);
    void set_completion(pcie_cpl status, bool bcm, unsigned int bytes, unsigned int tag, unsigned int lower_addr);
    void set_byte_enables(unsigned int first, unsigned int last);
    void set_address(uint64_t address);
    void set_destination(unsigned int id);
    void set_data(const std::deque<uint32_t> &dw);

    bool deserialize(const std::deque<uint32_t> &dw);
    void serialize(std::deque<uint32_t> &dw) const;

    bool validate() const;

    bool operator==(const pcie_tlp &tlp) const;

    friend std::ostream& operator << ( std::ostream &s, const pcie_tlp &tlp );
};

std::ostream& operator << ( std::ostream &s, const pcie_tlp &tlp );

std::ostream& operator << ( std::ostream &s, const pcie_fmt &fmt );
std::ostream& operator << ( std::ostream &s, const pcie_type &type );
std::ostream& operator << ( std::ostream &s, const pcie_cpl &cpl );

    } // end namespace pcie
} // end namespace dlsc

#endif

