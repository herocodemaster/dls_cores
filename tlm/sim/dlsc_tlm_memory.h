
#ifndef DLSC_TLM_MEMORY_INCLUDED
#define DLSC_TLM_MEMORY_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/multi_passthrough_target_socket.h>

#include <deque>
#include <map>
#include <algorithm>
#include <boost/shared_array.hpp>

#include "dlsc_common.h"

template <typename DATATYPE = uint32_t>
class dlsc_tlm_memory : public sc_core::sc_module {
public:
    typedef tlm_utils::multi_passthrough_target_socket<dlsc_tlm_memory<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> socket_type;

    socket_type socket;

    dlsc_tlm_memory(
        const sc_core::sc_module_name   &nm,
        const unsigned int              mem_size,
        const uint64_t                  base_addr       = 0,
        const sc_core::sc_time          byte_latency    = sc_core::SC_ZERO_TIME,    // time it takes to transfer a single byte
        const sc_core::sc_time          access_latency  = sc_core::SC_ZERO_TIME);   // time it takes to setup a burst

    void set_error_rate(const float err) { set_error_rate_read(err); set_error_rate_write(err); }
    void set_error_rate_read(const float err) { assert(err >= 0.0 && err <= 100.0); this->error_rate_read = (int)(err*10.0); }
    void set_error_rate_write(const float err) { assert(err >= 0.0 && err <= 100.0); this->error_rate_write = (int)(err*10.0); }


    // Backdoor memory access
    
    template <class InputIterator>
    void nb_read(
        uint64_t addr,
        InputIterator first,
        const InputIterator last);
    
    inline void nb_read(
        const uint64_t addr,
        const unsigned int length,
        std::deque<DATATYPE> &data)
    {
        data.resize(length);
        nb_read(addr,data.begin(),data.end());
    }

    template <class InputIterator>
    void nb_write(
        uint64_t addr,
        InputIterator first,
        const InputIterator last);

    inline void nb_write(
        const uint64_t addr,
        std::deque<DATATYPE> &data)
    {
        nb_write(addr,data.begin(),data.end());
    }

    void end_of_elaboration();

    ~dlsc_tlm_memory();

private:
    // no copying/assigning
    dlsc_tlm_memory(const dlsc_tlm_memory&);
    dlsc_tlm_memory& operator= (const dlsc_tlm_memory&);

    int                         error_rate_read;    // percentage of transactions to have fail (0-1000)
    int                         error_rate_write;   // percentage of transactions to have fail (0-1000)

    const unsigned int          bus_width;

    const unsigned int          mem_size;
    const unsigned int          block_size;

    const uint64_t              mem_mask;
    const uint64_t              block_mask;
    const uint64_t              blocks_mask;
    
    const uint64_t              base_addr;

    const sc_core::sc_time      byte_latency;
    const sc_core::sc_time      access_latency;

    bool                        delay_enabled;

    sc_core::sc_time            next_time;
    
    std::map<uint64_t,boost::shared_array<uint8_t> > blocks;
    
    uint8_t *get_block_ptr(const uint64_t addr);

    // multi_passthrough_target_socket callbacks
    tlm::tlm_sync_enum nb_transport_fw(int id,tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);
    void b_transport(int id,tlm::tlm_generic_payload &trans, sc_core::sc_time &delay);
    unsigned int transport_dbg(int id,tlm::tlm_generic_payload &trans);
    bool get_direct_mem_ptr(int id,tlm::tlm_generic_payload &trans, tlm::tlm_dmi &dmi_data);

    friend class tlm_utils::multi_passthrough_target_socket<dlsc_tlm_memory<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types>;
};

template <typename DATATYPE>
dlsc_tlm_memory<DATATYPE>::dlsc_tlm_memory(
    const sc_core::sc_module_name &nm,
    const unsigned int mem_size,
    const uint64_t base_addr,
    const sc_core::sc_time byte_latency,
    const sc_core::sc_time access_latency
) :
    sc_module       (nm),
    socket          ("socket"),
    bus_width       (sizeof(DATATYPE)),
    mem_size        (mem_size),                 // ex: 0x01000000 (16*1024*1024)
    block_size      (2*1024*1024),              // ex: 0x00100000 ( 1*1024*1024)
    mem_mask        (mem_size - 1),             // ex: 0x00FFFFFF
    block_mask      (block_size - 1),           // ex: 0x000FFFFF
    blocks_mask     (mem_mask & ~block_mask),   // ex: 0x00F00000
    base_addr       (base_addr),
    byte_latency    (byte_latency),
    access_latency  (access_latency)
{
    assert( block_size >= 4096 && (block_size & (block_size-1)) == 0 && block_size % bus_width == 0 );
    assert( (mem_size & (mem_size-1)) == 0 && mem_size >= block_size && mem_size % bus_width == 0 );
    assert( base_addr % mem_size == 0 );

    socket.register_nb_transport_fw(this, &dlsc_tlm_memory<DATATYPE>::nb_transport_fw);
    socket.register_b_transport(this, &dlsc_tlm_memory<DATATYPE>::b_transport);
    socket.register_transport_dbg(this, &dlsc_tlm_memory<DATATYPE>::transport_dbg);
    socket.register_get_direct_mem_ptr(this, &dlsc_tlm_memory<DATATYPE>::get_direct_mem_ptr);

    next_time       = sc_core::SC_ZERO_TIME;

    delay_enabled   = byte_latency != sc_core::SC_ZERO_TIME || access_latency != sc_core::SC_ZERO_TIME;

    error_rate_read     = 0;
    error_rate_write    = 0;
}

template <typename DATATYPE> template <class InputIterator>
void dlsc_tlm_memory<DATATYPE>::nb_read(
    uint64_t addr,
    InputIterator first,
    const InputIterator last)
{
    unsigned int lim;
    DATATYPE *ptr;

    addr &= ~((uint64_t)(sizeof(DATATYPE)-1));

    while(first != last) {
        lim     = block_size - (addr & block_mask);
        lim     /= sizeof(DATATYPE);
        if(lim > (last-first))
            lim     = (last-first);

        ptr     = reinterpret_cast<DATATYPE*>(get_block_ptr(addr));

        std::copy(ptr,ptr+lim,first);

        addr    += (lim*sizeof(DATATYPE));
        first   += lim;
    }
}
    
template <typename DATATYPE> template <class InputIterator>
void dlsc_tlm_memory<DATATYPE>::nb_write(
    uint64_t addr,
    InputIterator first,
    const InputIterator last)
{
    unsigned int lim;
    DATATYPE *ptr;

    addr &= ~((uint64_t)(sizeof(DATATYPE)-1));

    while(first != last) {
        lim     = block_size - (addr & block_mask);
        lim     /= sizeof(DATATYPE);
        if(lim > (last-first))
            lim     = (last-first);

        ptr     = reinterpret_cast<DATATYPE*>(get_block_ptr(addr));

        std::copy(first,first+lim,ptr);

        addr    += (lim*sizeof(DATATYPE));
        first   += lim;
    }
}

template <typename DATATYPE>
void dlsc_tlm_memory<DATATYPE>::end_of_elaboration() {
    dlsc_info("initiators bound: " << socket.size());
    assert(socket.size() > 0);
}

template <typename DATATYPE>
dlsc_tlm_memory<DATATYPE>::~dlsc_tlm_memory() {
    // invalidate all DMI pointers on destruction
    for(unsigned int i=0;i<socket.size();++i) {
        socket[i]->invalidate_direct_mem_ptr(0x0,(sc_dt::uint64)-1);
    }
}

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_memory<DATATYPE>::nb_transport_fw(int id, tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay) {
    assert(phase != tlm::END_REQ && phase != tlm::BEGIN_RESP && phase != tlm::END_RESP);

    if(phase == tlm::BEGIN_REQ) {
        // b_transport doesn't block in this implementation, so use it to satisfy request
        b_transport(id,trans,delay);
        phase = tlm::BEGIN_RESP;
        return tlm::TLM_COMPLETED;
    }

    return tlm::TLM_ACCEPTED;
}

template <typename DATATYPE>
void dlsc_tlm_memory<DATATYPE>::b_transport(int id, tlm::tlm_generic_payload &trans, sc_core::sc_time &delay) {
    if(!trans.is_read() && !trans.is_write()) {
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
        return;
    }

    uint64_t addr       = trans.get_address();
    unsigned int length = trans.get_data_length();

    // transaction can't cross block boundary
    if( (addr & ~block_mask) != ((addr + length - 1) & ~block_mask) ) {
        dlsc_warn("crossed block boundary");
        trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
        return;
    }

    // non-zero length; no streaming
    if( length == 0 || trans.get_streaming_width() < length) {
        trans.set_response_status(tlm::TLM_BURST_ERROR_RESPONSE);
        return;
    }

    // compute completion time
    if(delay_enabled) {
        // can't use the past's bandwidth!
        if(next_time < sc_core::sc_time_stamp()) {
            next_time = sc_core::sc_time_stamp();
        }

        dlsc_verb("local time: " << (delay + sc_time_stamp()) );

        dlsc_verb("transaction begins: " << next_time << " (length: " << std::dec << length << ")");

        // time required for this transfer
        sc_core::sc_time xfer_time  = access_latency + (length * byte_latency);

        // account for transfer time (memory's perspective)
        next_time   += xfer_time;
        
        dlsc_verb("..and will complete: " << next_time);

        // earliest this transfer could complete (initiator's perspective)
        delay       += xfer_time;

        // earliest this transfer could complete (memory's perspective; initiator's local time)
        sc_core::sc_time cpl_time   = next_time - sc_core::sc_time_stamp();

        // reconcile
        if( delay < cpl_time ) {
            delay = cpl_time;
        }
    }
    
    if( (trans.is_read()  && error_rate_read  > 0 && (rand()%1000) < error_rate_read ) ||
        (trans.is_write() && error_rate_write > 0 && (rand()%1000) < error_rate_write) )
    {
        // generate error
        trans.set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
        return;
    }

    // setup pointers for copying
    uint8_t *src_ptr;
    uint8_t *dest_ptr;

    if(trans.is_write()) {
        src_ptr     = trans.get_data_ptr();
        dest_ptr    = get_block_ptr(addr);
    } else {
        src_ptr     = get_block_ptr(addr);
        dest_ptr    = trans.get_data_ptr();
    }
        
    unsigned int be_length = trans.get_byte_enable_length();

    if(!be_length) {
        // no strobes; just a straight copy
        std::copy(src_ptr,src_ptr+length,dest_ptr);
    } else {
        // strobes; must examine each byte
        uint8_t *be_ptr = trans.get_byte_enable_ptr();
        unsigned int be = 0;
        for(unsigned int i=0;i<length;++i) {
            if(be_ptr[be] == TLM_BYTE_ENABLED) dest_ptr[i] = src_ptr[i];
            if(++be == be_length) be = 0;
        }
    }
    
    trans.set_dmi_allowed(true); // DMI is allowed to entire memory
    trans.set_response_status(tlm::TLM_OK_RESPONSE);
}

template <typename DATATYPE>
unsigned int dlsc_tlm_memory<DATATYPE>::transport_dbg(int id, tlm::tlm_generic_payload &trans) {
    if(!trans.is_read() && !trans.is_write()) {
        return 0;
    }

    uint64_t addr       = trans.get_address();
    unsigned int length = trans.get_data_length();
    
    // transaction can't cross block boundary
    if( (addr & ~block_mask) != ((addr + length - 1) & ~block_mask) ) {
        dlsc_warn("crossed block boundary");
        return 0;
    }
    
    uint8_t *src_ptr;
    uint8_t *dest_ptr;

    if(trans.is_write()) {
        src_ptr     = trans.get_data_ptr();
        dest_ptr    = get_block_ptr(addr);
    } else {
        src_ptr     = get_block_ptr(addr);
        dest_ptr    = trans.get_data_ptr();
    }
    
    std::copy(src_ptr,src_ptr+length,dest_ptr);

    return length;
}

template <typename DATATYPE>
bool dlsc_tlm_memory<DATATYPE>::get_direct_mem_ptr(int id, tlm::tlm_generic_payload &trans, tlm::tlm_dmi &dmi_data) {
    // generate a DMI response that allows access to an entire block

    uint64_t addr   = trans.get_address() & ~block_mask;

    dmi_data.set_start_address(addr);
    dmi_data.set_end_address(addr+block_size-1);
    dmi_data.set_dmi_ptr(get_block_ptr(addr));
    
    dmi_data.allow_read_write();
    dmi_data.set_read_latency(byte_latency);
    dmi_data.set_write_latency(byte_latency);

    return true;
}

template <typename DATATYPE>
uint8_t *dlsc_tlm_memory<DATATYPE>::get_block_ptr(const uint64_t addr) {
    // get pointer to local storage
    uint8_t *block_ptr = blocks[addr & blocks_mask].get();
    if(!block_ptr) {
        dlsc_info("initializing block 0x" << std::hex << (addr & blocks_mask));
        block_ptr = new uint8_t[block_size];
        blocks[addr & blocks_mask] = boost::shared_array<uint8_t>(block_ptr);

        // initialize memory block to address pattern
        DATATYPE *init_ptr = reinterpret_cast<DATATYPE*>(block_ptr);
        for(uint64_t i = (addr & blocks_mask) + base_addr ; i < (addr & blocks_mask) + base_addr + block_size ; i += sizeof(DATATYPE), ++init_ptr) {
            *init_ptr = static_cast<DATATYPE>(i);
        }
    }

    // offset to beginning of accessed region
    block_ptr += (addr & block_mask);

    return block_ptr;
}

#endif

