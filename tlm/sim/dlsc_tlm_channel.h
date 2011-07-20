
#ifndef DLSC_TLM_CHANNEL_INCLUDED
#define DLSC_TLM_CHANNEL_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/simple_initiator_socket.h>

template <typename DATATYPE = uint32_t>
class dlsc_tlm_channel : public sc_core::sc_module {
public:

    // ** target socket **

    typedef tlm_utils::simple_target_socket<dlsc_tlm_channel<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> t_socket_type;
    t_socket_type in_socket;
    
    // callback
    virtual tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);


    // ** initiator socket **
    
    typedef tlm_utils::simple_initiator_socket<dlsc_tlm_channel<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> i_socket_type;
    i_socket_type out_socket;
    
    // callback
    virtual tlm::tlm_sync_enum nb_transport_bw(tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);


    // ** functions **
    
    // constructor
    dlsc_tlm_channel(
        const sc_core::sc_module_name &nm);

    // configuration
    void set_request_delay(const sc_core::sc_time &delay_min, const sc_core::sc_time &delay_max);
    void set_response_delay(const sc_core::sc_time &delay_min, const sc_core::sc_time &delay_max);

private:

    sc_core::sc_time fw_min_delay;
    sc_core::sc_time fw_max_delay;
    sc_core::sc_time bw_min_delay;
    sc_core::sc_time bw_max_delay;

    sc_core::sc_time rand_delay(const sc_core::sc_time &min, const sc_core::sc_time &max);
};

// constructor

template <typename DATATYPE>
dlsc_tlm_channel<DATATYPE>::dlsc_tlm_channel(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm)
{
    in_socket.register_nb_transport_fw(this,&dlsc_tlm_channel<DATATYPE>::nb_transport_fw);
    out_socket.register_nb_transport_bw(this,&dlsc_tlm_channel<DATATYPE>::nb_transport_bw);

    sc_core::sc_time min_delay =             sc_core::sc_time(rand()%100,SC_NS);
    sc_core::sc_time max_delay = min_delay + sc_core::sc_time(rand()%200,SC_NS);

    set_request_delay(min_delay,max_delay);
    set_response_delay(min_delay,max_delay);
}
    
// configuration

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::set_request_delay(
    const sc_core::sc_time &delay_min,
    const sc_core::sc_time &delay_max
) {
    fw_min_delay    = delay_min;
    fw_max_delay    = delay_max;
}

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::set_response_delay(
    const sc_core::sc_time &delay_min,
    const sc_core::sc_time &delay_max
) {
    bw_min_delay    = delay_min;
    bw_max_delay    = delay_max;
}

template <typename DATATYPE>
sc_core::sc_time dlsc_tlm_channel<DATATYPE>::rand_delay(
    const sc_core::sc_time &min,
    const sc_core::sc_time &max
) {
    float scale = ((rand()%1000)/1000.0f);
    sc_core::sc_time delay = min + (max * scale);
    return delay;
}


// ** target socket **

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_channel<DATATYPE>::nb_transport_fw(
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_core::sc_time &delay)
{
    // copy delay value; don't want to advance initiator's time until request is completed
    sc_core::sc_time delay_i = delay;

    // request prop delay
    delay_i += rand_delay(fw_min_delay,fw_max_delay);

    // send on its way
    tlm::tlm_sync_enum status = out_socket->nb_transport_fw(trans,phase,delay_i);

    if(phase == tlm::BEGIN_RESP || status == tlm::TLM_COMPLETED) {
        // completed; update time
        delay = delay_i;
    }

    return status;
}


// ** initiator socket **

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_channel<DATATYPE>::nb_transport_bw(
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_core::sc_time &delay)
{
    // copy delay value; don't want to waste target's time
    sc_core::sc_time delay_i = delay;

    // response prop delay
    delay_i += rand_delay(bw_min_delay,bw_max_delay);

    // send on its way
    return in_socket->nb_transport_bw(trans,phase,delay_i);
}

#endif // DLSC_TLM_CHANNEL_INCLUDED

