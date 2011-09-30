
#ifndef DLSC_TLM_FABRIC_INCLUDED
#define DLSC_TLM_FABRIC_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/multi_passthrough_target_socket.h>
#include <tlm_utils/multi_passthrough_initiator_socket.h>

#include <vector>
#include <map>

template <typename DATATYPE = uint32_t>
class dlsc_tlm_fabric : public sc_core::sc_module {
public:

    // ** target socket **

    typedef tlm_utils::multi_passthrough_target_socket<dlsc_tlm_fabric<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> t_socket_type;
    t_socket_type in_socket;
    
    // callback
    virtual tlm::tlm_sync_enum nb_transport_fw(int id, tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);


    // ** initiator socket **
    
    typedef tlm_utils::multi_passthrough_initiator_socket<dlsc_tlm_fabric<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> i_socket_type;
    i_socket_type out_socket;
    
    // callback
    virtual tlm::tlm_sync_enum nb_transport_bw(int id, tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);


    // ** functions **
    
    // constructor
    dlsc_tlm_fabric(
        const sc_core::sc_module_name &nm);

    // configuration
    void set_map(
        const int       socket,
        const uint64_t  in_mask,
        const uint64_t  in_base,
        const uint64_t  out_mask,
        const uint64_t  out_base,
        const bool      read_okay,
        const bool      write_okay);
    
    void end_of_elaboration();

private:

    struct fabric_map;

    std::vector<fabric_map> maps;

    std::map<tlm::tlm_generic_payload*,int> outstanding;
};


template <typename DATATYPE = uint32_t>
struct dlsc_tlm_fabric<DATATYPE>::fabric_map {
    fabric_map() {
        // default configuration will match anything and not translate
        in_mask     = 0xFFFFFFFFFFFFFFFF;
        in_base     = 0;
        out_mask    = in_mask;
        out_base    = in_base;
        read_okay   = true;
        write_okay  = true;
    }

    uint64_t  in_mask;
    uint64_t  in_base;
    uint64_t  out_mask;
    uint64_t  out_base;
    bool      read_okay;
    bool      write_okay;
};


// constructor

template <typename DATATYPE>
dlsc_tlm_fabric<DATATYPE>::dlsc_tlm_fabric(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm)
{
    in_socket.register_nb_transport_fw(this,&dlsc_tlm_fabric<DATATYPE>::nb_transport_fw);
    out_socket.register_nb_transport_bw(this,&dlsc_tlm_fabric<DATATYPE>::nb_transport_bw);
}

template <typename DATATYPE>
void dlsc_tlm_fabric<DATATYPE>::end_of_elaboration() {
    if(maps.size() != out_socket.size()) {
        maps.resize(out_socket.size());
    }
}
    
// configuration

template <typename DATATYPE>
void dlsc_tlm_fabric<DATATYPE>::set_map(
    const int       socket,
    const uint64_t  in_mask,
    const uint64_t  in_base,
    const uint64_t  out_mask,
    const uint64_t  out_base,
    const bool      read_okay,
    const bool      write_okay
) {
    assert(socket >= 0 && socket < (int)out_socket.size());
    if(maps.size() != out_socket.size()) {
        maps.resize(out_socket.size());
    }

    assert( (in_mask  & 0xFFF) == 0xFFF ); // 4K minimum size
    assert( (out_mask & 0xFFF) == 0xFFF );
    assert( ((in_mask +1) & in_mask ) == 0 ); // one less than a power-of-2
    assert( ((out_mask+1) & out_mask) == 0 );
    assert( (in_base  & in_mask ) == 0 );
    assert( (out_base & out_mask) == 0 );

    maps[socket].in_mask    = in_mask;
    maps[socket].in_base    = in_base;
    maps[socket].out_mask   = out_mask;
    maps[socket].out_base   = out_base;
    maps[socket].read_okay  = read_okay;
    maps[socket].write_okay = write_okay;
}


// ** target socket **

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_fabric<DATATYPE>::nb_transport_fw(
    int id,
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_core::sc_time &delay)
{
    // copy delay value; don't want to advance initiator's time until request is completed
    sc_core::sc_time delay_i = delay;

    // find destination socket
    int socket = -1;
    for(int i=0;i<(int)maps.size();++i) {
        if( ((trans.get_address() & ~maps[i].in_mask) == maps[i].in_base) && 
            ((trans.is_read() && maps[i].read_okay) || (trans.is_write() && maps[i].write_okay)) )
        {
            trans.set_address( (trans.get_address() & maps[i].out_mask) | maps[i].out_base );

            socket = i;
            break;
        }
    }

    tlm::tlm_sync_enum status;

    if(socket < 0) {
        // no matching socket; generate a decode error
        phase   = tlm::BEGIN_RESP;
        status  = tlm::TLM_COMPLETED;
        trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
    } else {
        // send on its way
        assert(socket >= 0 && socket < (int)out_socket.size());
        status = out_socket[socket]->nb_transport_fw(trans,phase,delay_i);
    }

    if(phase == tlm::BEGIN_RESP || status == tlm::TLM_COMPLETED) {
        // completed; apply response delay as well
        delay   = delay_i;
        outstanding.erase(&trans);   // just in case a previous call set this up
    } else {
        // track source socket
        outstanding[&trans] = id;
    }

    return status;
}


// ** initiator socket **

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_fabric<DATATYPE>::nb_transport_bw(
    int id,
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_core::sc_time &delay)
{
    // copy delay value; don't want to waste target's time
    sc_core::sc_time delay_i = delay;

    // find source socket
    int socket = outstanding[&trans];

    // send on its way
    assert(socket >= 0 && socket < (int)in_socket.size());
    tlm::tlm_sync_enum status = in_socket[socket]->nb_transport_bw(trans,phase,delay_i);

    if(phase == tlm::END_RESP || status == tlm::TLM_COMPLETED) {
        // cleanup
        outstanding.erase(&trans);
    }

    return status;
}

#endif // DLSC_TLM_FABRIC_INCLUDED

