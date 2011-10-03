
#ifndef DLSC_TLM_CHANNEL_INCLUDED
#define DLSC_TLM_CHANNEL_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/peq_with_get.h>
#include <tlm_utils/multi_passthrough_target_socket.h>
#include <tlm_utils/multi_passthrough_initiator_socket.h>

template <typename DATATYPE = uint32_t>
class dlsc_tlm_channel : public sc_core::sc_module {
public:

    // ** target socket **

    typedef tlm_utils::multi_passthrough_target_socket<dlsc_tlm_channel<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> t_socket_type;
    t_socket_type in_socket;
    
    // callback
    virtual tlm::tlm_sync_enum nb_transport_fw(int id, tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);


    // ** initiator socket **
    
    typedef tlm_utils::multi_passthrough_initiator_socket<dlsc_tlm_channel<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> i_socket_type;
    i_socket_type out_socket;
    
    // callback
    virtual tlm::tlm_sync_enum nb_transport_bw(int id, tlm::tlm_generic_payload &trans, tlm::tlm_phase &phase, sc_core::sc_time &delay);


    // ** functions **
    
    // constructor
    dlsc_tlm_channel(
        const sc_core::sc_module_name &nm,
        const bool remove_annotation = false
    );

    // configuration
    void set_request_delay(const sc_core::sc_time &delay_min, const sc_core::sc_time &delay_max);
    void set_response_delay(const sc_core::sc_time &delay_min, const sc_core::sc_time &delay_max);
    void set_delay(const sc_core::sc_time &delay_min, const sc_core::sc_time &delay_max) {
        set_request_delay(delay_min,delay_max);
        set_response_delay(delay_min,delay_max);
    }
    
    void end_of_elaboration();
    
    SC_HAS_PROCESS(dlsc_tlm_channel);

private:

    struct queue_entry {
        int                         socket;
        tlm::tlm_phase              phase;
        tlm::tlm_generic_payload    *trans;
    };

    bool fw_outstanding;
    void fw_queue_method();
    sc_core::sc_event fw_event;
    tlm_utils::peq_with_get<queue_entry> fw_queue;

    bool bw_outstanding;
    void bw_queue_method();
    sc_core::sc_event bw_event;
    tlm_utils::peq_with_get<queue_entry> bw_queue;

    const bool rm_ann;

    sc_core::sc_time fw_min_delay;
    sc_core::sc_time fw_max_delay;
    sc_core::sc_time bw_min_delay;
    sc_core::sc_time bw_max_delay;

    sc_core::sc_time fw_next_delay;
    sc_core::sc_time bw_next_delay;

    sc_core::sc_time rand_delay(const sc_core::sc_time &min, const sc_core::sc_time &max, sc_core::sc_time &next);
};

// constructor

template <typename DATATYPE>
dlsc_tlm_channel<DATATYPE>::dlsc_tlm_channel(
    const sc_core::sc_module_name &nm,
    const bool remove_annotation
) :
    sc_module(nm),
    fw_queue("fw_queue"),
    bw_queue("bw_queue"),
    rm_ann(remove_annotation)
{
    in_socket.register_nb_transport_fw(this,&dlsc_tlm_channel<DATATYPE>::nb_transport_fw);
    out_socket.register_nb_transport_bw(this,&dlsc_tlm_channel<DATATYPE>::nb_transport_bw);

    sc_core::sc_time min_delay = sc_core::sc_time(10 ,SC_NS);
    sc_core::sc_time max_delay = sc_core::sc_time(100,SC_NS);

    set_request_delay(min_delay,max_delay);
    set_response_delay(min_delay,max_delay);

    fw_next_delay = sc_core::SC_ZERO_TIME;
    bw_next_delay = sc_core::SC_ZERO_TIME;

    fw_outstanding  = false;
    bw_outstanding  = false;

    SC_METHOD(fw_queue_method);
        sensitive << fw_queue.get_event();
        sensitive << fw_event;

    SC_METHOD(bw_queue_method);
        sensitive << bw_queue.get_event();
        sensitive << bw_event;
}

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::end_of_elaboration() {
    assert(in_socket.size() == out_socket.size());
}
    
// configuration

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::set_request_delay(
    const sc_core::sc_time &delay_min,
    const sc_core::sc_time &delay_max
) {
    assert(delay_max >= delay_min);
    fw_min_delay    = delay_min;
    fw_max_delay    = delay_max;
}

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::set_response_delay(
    const sc_core::sc_time &delay_min,
    const sc_core::sc_time &delay_max
) {
    assert(delay_max >= delay_min);
    bw_min_delay    = delay_min;
    bw_max_delay    = delay_max;
}

template <typename DATATYPE>
sc_core::sc_time dlsc_tlm_channel<DATATYPE>::rand_delay(
    const sc_core::sc_time &min,
    const sc_core::sc_time &max,
    sc_core::sc_time &next
) {
    float scale = ((rand()%1000)/1000.0f);
    sc_core::sc_time delay = min + ((max-min) * scale);
    if(next >= (delay+sc_core::sc_time_stamp())) {
        // don't allow new transaction to pass old ones
        delay = (next-sc_core::sc_time_stamp()) * 1.01f;
    }
    next = (delay+sc_core::sc_time_stamp());
    return delay;
}


// ** target socket **

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_channel<DATATYPE>::nb_transport_fw(
    int id,
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_core::sc_time &delay
) {
    assert(phase != tlm::END_REQ && phase != tlm::BEGIN_RESP);

    // copy delay value; don't want to advance initiator's time until request is completed
    sc_core::sc_time delay_i = delay;

    // request prop delay
    delay_i += rand_delay(fw_min_delay,fw_max_delay,fw_next_delay);

    if(rm_ann) {
        // ** no timing annotation **
        if(phase == tlm::END_RESP) {
            // ending an outstanding transaction
            assert(bw_outstanding);
            bw_outstanding = false;
            bw_event.notify();
            return tlm::TLM_COMPLETED;
        } else if(phase == tlm::BEGIN_REQ) {
            // must schedule forward call for the future
            queue_entry *qe = new queue_entry;
            qe->socket  = id;
            qe->trans   = &trans;
            qe->phase   = phase;
            fw_queue.notify(*qe,delay_i);
            phase       = tlm::END_REQ;
            return tlm::TLM_UPDATED;
        } else {
            dlsc_info("ignored unexpected phase");
            return tlm::TLM_ACCEPTED;
        }
    } else {
        // ** with timing annotation **
        // can send immediately
        tlm::tlm_sync_enum status = out_socket[id]->nb_transport_fw(trans,phase,delay_i);

        if(phase == tlm::BEGIN_RESP || status == tlm::TLM_COMPLETED) {
            // completed; apply response delay as well
            delay_i += rand_delay(bw_min_delay,bw_max_delay,bw_next_delay);

            // can complete now
            delay   = delay_i;
        }
        
        return status;
    }

    assert(false);
}

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::fw_queue_method() {
    queue_entry *qe;
    while( !fw_outstanding && (qe = fw_queue.get_next_transaction()) ) {
        sc_core::sc_time delay      = sc_core::SC_ZERO_TIME;
        sc_core::sc_time delay_i    = sc_core::SC_ZERO_TIME;
        int id                      = qe->socket;
        tlm::tlm_generic_payload &trans = *(qe->trans);
        tlm::tlm_phase phase        = qe->phase;
        delete qe;
        
        tlm::tlm_sync_enum status = out_socket[id]->nb_transport_fw(trans,phase,delay);

        if(phase == tlm::BEGIN_RESP || status == tlm::TLM_COMPLETED) {
            // completed; apply response delay as well
            delay_i     = delay + rand_delay(bw_min_delay,bw_max_delay,bw_next_delay);

            // must schedule a completion notification for the future
            qe          = new queue_entry;
            qe->socket  = id;
            qe->trans   = &trans;
            qe->phase   = tlm::BEGIN_RESP;
            bw_queue.notify(*qe,delay_i);

            if(phase == tlm::BEGIN_RESP && status != tlm::TLM_COMPLETED) {
                // target expects END_RESP; generate it with no additional delay
                phase       = tlm::END_RESP;
                out_socket[id]->nb_transport_fw(trans,phase,delay);
            }
        } else if(phase == tlm::BEGIN_REQ) {
            // blocked
            fw_outstanding = true;
        }
    }
}


// ** initiator socket **

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_channel<DATATYPE>::nb_transport_bw(
    int id,
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_core::sc_time &delay
) {
    assert(phase != tlm::BEGIN_REQ && phase != tlm::END_RESP);

    // copy delay value; don't want to waste target's time
    sc_core::sc_time delay_i = delay;

    // response prop delay
    delay_i += rand_delay(bw_min_delay,bw_max_delay,bw_next_delay);

    if(rm_ann) {
        // ** no timing annotation **
        if(phase == tlm::END_REQ || (phase == tlm::BEGIN_RESP && fw_outstanding)) {
            // ending an outstanding transaction
            assert(fw_outstanding);
            fw_outstanding = false;
            fw_event.notify();
        }
        if(phase == tlm::END_REQ) {
            return tlm::TLM_ACCEPTED;
        } else if(phase == tlm::BEGIN_RESP) {
            // must schedule backward call for the future
            queue_entry *qe = new queue_entry;
            qe->socket  = id;
            qe->trans   = &trans;
            qe->phase   = phase;
            bw_queue.notify(*qe,delay_i);
            phase       = tlm::END_RESP;
            return tlm::TLM_COMPLETED;
        } else {
            dlsc_info("ignored unexpected phase");
            return tlm::TLM_ACCEPTED;
        }
    } else {
        // ** with timing annotation **
        // can send immediately
        return in_socket[id]->nb_transport_bw(trans,phase,delay_i);
    }

    assert(false);
}

template <typename DATATYPE>
void dlsc_tlm_channel<DATATYPE>::bw_queue_method() {
    queue_entry *qe;
    while( !bw_outstanding && (qe = bw_queue.get_next_transaction()) ) {
        sc_core::sc_time delay_i    = sc_core::SC_ZERO_TIME;
        if(in_socket[qe->socket]->nb_transport_bw(*(qe->trans),qe->phase,delay_i) != tlm::TLM_COMPLETED && qe->phase == tlm::BEGIN_RESP) {
            // blocked
            bw_outstanding = true;
        }
        delete qe;
    }
}

#endif // DLSC_TLM_CHANNEL_INCLUDED

