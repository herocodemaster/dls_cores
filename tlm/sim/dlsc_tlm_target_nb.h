
#ifndef DLSC_TLM_TARGET_NB_INCLUDED
#define DLSC_TLM_TARGET_NB_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/peq_with_get.h>
#include <tlm_utils/simple_target_socket.h>

#include <vector>
#include <deque>
#include <map>
#include <algorithm>
#include <boost/shared_ptr.hpp>

#include "dlsc_common.h"


template <typename MODULE, typename DATATYPE = uint32_t>
class dlsc_tlm_target_nb : public sc_core::sc_module {
public:

    tlm_utils::simple_target_socket<dlsc_tlm_target_nb<MODULE,DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> socket;

    class transaction_state;
    typedef boost::shared_ptr<transaction_state> transaction;
   
    // constructor with callback for targets supporting timing annotation
    dlsc_tlm_target_nb(
        const sc_core::sc_module_name &nm,
        MODULE *mod,
        void (MODULE::*cb)(transaction,sc_core::sc_time),
        const unsigned int max_length = 16);

    // constructor with callback for targets not supporting annotation
    dlsc_tlm_target_nb(
        const sc_core::sc_module_name &nm,
        MODULE *mod,
        void (MODULE::*cb)(transaction),
        const unsigned int max_length = 16);
    
    virtual tlm::tlm_sync_enum nb_transport_fw(tlm::tlm_generic_payload &trans,tlm::tlm_phase &phase,sc_time &delay);
//    virtual void b_transport(tlm::tlm_generic_payload &trans,sc_time &delay);
    
    SC_HAS_PROCESS(dlsc_tlm_target_nb);

private:
    // no copying/assigning
    dlsc_tlm_target_nb(const dlsc_tlm_target_nb&);
    dlsc_tlm_target_nb& operator= (const dlsc_tlm_target_nb&);

    // code shared by both constructors
    void construct_common();

    // parameters
    const bool tann; // timing annotation enabled
    const unsigned int max_length;

    // callbacks
    MODULE *callback_module;
    void (MODULE::*callback)(transaction);                          // invoked at: ts->ready_time == sc_time_stamp()
    void (MODULE::*callback_delay)(transaction,sc_core::sc_time);   // invoked at: ts->ready_time == sc_time_stamp() + delay
    bool (MODULE::*callback_validate)(tlm::tlm_generic_payload&);   // validates payload before transaction is issued

    bool validate_payload(tlm::tlm_generic_payload &trans);         // internal fallback validation function

    // queue for unannotated use
    tlm_utils::peq_with_get<tlm::tlm_generic_payload> *ready_queue;

    // triggered by ready_queue->get_event(); invokes ready_launch()
    void ready_method();

    // invokes callback to parent
    void ready_launch(transaction ts, sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME);

    // tracks pending completion responses
    std::deque<transaction>     complete_queue;
    bool                        complete_outstanding;
    sc_core::sc_event           complete_event;

    // triggered by complete_event; will generate nb_transport_bw calls
    void complete_method();

    // tidies up
    void complete(transaction ts);

    // associates outstanding transactions with TLM payloads
    std::map<tlm::tlm_generic_payload*,transaction> outstanding;

    // transaction_state invokes this callback when it has been completed
    void completed_notify(tlm::tlm_generic_payload *payload);

    friend class transaction_state;
};


// constructor with callback for targets supporting timing annotation
template <typename MODULE, typename DATATYPE>
dlsc_tlm_target_nb<MODULE,DATATYPE>::dlsc_tlm_target_nb(
    const sc_core::sc_module_name &nm,
    MODULE *mod,
    void (MODULE::*cb)(transaction,sc_core::sc_time),
    const unsigned int max_length
) :
    sc_module(nm),
    tann(true),
    max_length(max_length)
{
    callback_module = mod;
    callback        = 0;
    callback_delay  = cb;
    
    callback_validate = 0;

    construct_common();
}

// constructor with callback for targets not supporting annotation
template <typename MODULE, typename DATATYPE>
dlsc_tlm_target_nb<MODULE,DATATYPE>::dlsc_tlm_target_nb(
    const sc_core::sc_module_name &nm,
    MODULE *mod,
    void (MODULE::*cb)(transaction),
    const unsigned int max_length
) :
    sc_module(nm),
    tann(false),
    max_length(max_length)
{
    callback_module = mod;
    callback        = cb;
    callback_delay  = 0;

    callback_validate = 0;

    construct_common();
}

// code shared by both constructors
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::construct_common() {
    complete_outstanding = false;

    if(tann) {
        ready_queue     = 0; // not needed when using timing annotation
    } else {
        ready_queue     = new tlm_utils::peq_with_get<tlm::tlm_generic_payload>("ready_queue");
        SC_METHOD(ready_method);
            sensitive << ready_queue->get_event();
    }

    SC_METHOD(complete_method);
        sensitive << complete_event;
    
    socket.register_nb_transport_fw(this,&dlsc_tlm_target_nb<MODULE,DATATYPE>::nb_transport_fw);
}

// nb_transport_fw callback
template <typename MODULE, typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_target_nb<MODULE,DATATYPE>::nb_transport_fw(
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_time &delay)
{
    assert(phase != tlm::END_REQ && phase != tlm::BEGIN_RESP); // we generate these phases

    if(phase == tlm::BEGIN_REQ) {
        transaction ts(new transaction_state(this,&trans,delay));
        outstanding[&trans] = ts;

        if(!validate_payload(trans)) {
            // validation failed; complete transaction immediately
            ts->complete_delta(sc_core::SC_ZERO_TIME);
        } else {
            // validation passed; issue transaction
            if(tann || delay == sc_core::SC_ZERO_TIME) {
                // invoke callback
                ready_launch(ts,delay);
            } else {
                // schedule future callback invocation
                ready_queue->notify(trans,delay);
            }
        }

        if(!complete_outstanding && !complete_queue.empty() && complete_queue.front() == ts) {
            // transaction completed during ready_launch call; we can generate an immediate response
            ts->calc_complete_delay(delay);
            complete(ts);
            phase = tlm::BEGIN_RESP;
            return tlm::TLM_COMPLETED;
        }

        phase = tlm::END_REQ;
        return tlm::TLM_UPDATED;
    }

    if(phase == tlm::END_RESP) {
        assert(complete_outstanding);
        complete_outstanding = false;
        complete(outstanding[&trans]);
        complete_event.notify();
        return tlm::TLM_COMPLETED;
    }

    return tlm::TLM_ACCEPTED;
}

// internal fallback validation function
template <typename MODULE, typename DATATYPE>
bool dlsc_tlm_target_nb<MODULE,DATATYPE>::validate_payload(tlm::tlm_generic_payload &trans) {
    if(callback_validate) {
        // invoke external validation function
        return (callback_module->*callback_validate)(trans);
    }

    // fallback to internal validation method..
    uint64_t addr           = trans.get_address();
    unsigned int length     = trans.get_data_length();
    unsigned int be_length  = trans.get_byte_enable_length();

    trans.set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);

    if(!trans.is_read() && !trans.is_write()) {             // must be read or write
        dlsc_warn("transaction wasn't a read or write");
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
        return false;
    }

    if( (addr   % sizeof(DATATYPE)) != 0 ||                 // address aligned to bus width
        (length % sizeof(DATATYPE)) != 0 ||                 // data length aligned to bus width
        ((addr  % 4096) + length) > 4096 )                  // burst doesn't cross 4K boundary
    {
        dlsc_warn("transaction violated address rules");
        trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
        return false;
    }

    if( length == 0 ||                                      // length must be non-zero
        (length / sizeof(DATATYPE)) > max_length ||         // length doesn't exceed max_length beats
        trans.get_streaming_width() < length)               // no streaming
    {
        dlsc_warn("transaction violated burst rules");
        trans.set_response_status(tlm::TLM_BURST_ERROR_RESPONSE);
        return false;
    }

    if(be_length != 0) {
        if( trans.is_read() ||                              // no strobes on read
            be_length != length)                            // strobes 1:1 with data
        {
            dlsc_warn("transaction violated strobe rules");
            trans.set_response_status(tlm::TLM_BYTE_ENABLE_ERROR_RESPONSE);
            return false;
        }
    }

    return true;
}

// triggered by complete_event; will generate nb_transport_bw calls
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::complete_method() {
    while(!complete_outstanding && !complete_queue.empty()) {
        transaction ts = complete_queue.front();
        tlm::tlm_phase phase = tlm::BEGIN_RESP;

        sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
        ts->calc_complete_delay(delay);

        if(socket->nb_transport_bw(*(ts->get_payload()),phase,delay) == tlm::TLM_COMPLETED || phase == tlm::END_RESP) {
            // response acknowledged by initiator; complete it here
            complete(ts);
        } else {
            // response acknowledgement deferred to future
            // can't issue further responses until then
            complete_outstanding = true;
        }
    }
}

// tidies up
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::complete(transaction ts) {
    assert(!complete_outstanding && !complete_queue.empty() && complete_queue.front() == ts);
    complete_queue.pop_front();
    outstanding.erase(ts->get_payload());
}

// triggered by ready_queue->get_event(); invokes ready_launch()
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::ready_method() {
    tlm::tlm_generic_payload *trans;
    while( (trans = ready_queue->get_next_transaction()) ) {
        transaction ts = outstanding[trans];
        ready_launch(ts);
    }
}

// invokes callback to parent
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::ready_launch(
    transaction ts,
    sc_core::sc_time delay_initial)
{
    if(tann) {
        (callback_module->*callback_delay)(ts,delay_initial);
    } else {
        assert(delay_initial == sc_core::SC_ZERO_TIME);
        (callback_module->*callback)(ts);
    }
}

// transaction_state invokes this callback when it has been completed
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::completed_notify(tlm::tlm_generic_payload *payload) {
    transaction ts = outstanding[payload];
    assert(ts);
    complete_queue.push_back(ts);
    complete_event.notify();
}






template <typename MODULE, typename DATATYPE = uint32_t>
class dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state {
public:
    void complete();                                // transaction completed at: sc_time_stamp()
    void complete_delay(sc_core::sc_time delay);    // transaction completed at: sc_time_stamp() + delay
    void complete_delta(sc_core::sc_time delta);    // transaction completed at: ready_time + delta

    inline void set_response_status(tlm::tlm_response_status status) { payload->set_response_status(status); }

    inline bool is_read() { return payload->is_read(); }
    inline bool is_write() { return payload->is_write(); }

    inline uint64_t get_address() { return payload->get_address(); }

    inline unsigned int size() { return payload->get_data_length()/sizeof(DATATYPE); }

    // set payload data
    template <class InputIterator>
    void set_data(InputIterator first);

    inline void set_data(std::vector<DATATYPE> &data) { assert(data.size() == size()); set_data(data.begin()); }
    inline void set_data(std::deque<DATATYPE>  &data) { assert(data.size() == size()); set_data(data.begin()); }

    // get payload data
    template <class InputIterator>
    void get_data(InputIterator first);

    inline void get_data(std::vector<DATATYPE> &data) { data.resize(size()); get_data(data.begin()); }
    inline void get_data(std::deque<DATATYPE>  &data) { data.resize(size()); get_data(data.begin()); }

    // get payload strobes
    inline bool has_strobes() { return (payload->get_byte_enable_length() != 0); }
    template <class InputIterator>
    void get_strobes(InputIterator first);

    inline void get_strobes(std::vector<uint32_t> &strb) { strb.resize(size()); get_strobes(strb.begin()); }
    inline void get_strobes(std::deque<uint32_t>  &strb) { strb.resize(size()); get_strobes(strb.begin()); }
   
    inline sc_core::sc_time get_ready_time() { return ready_time; }
    inline sc_core::sc_time get_complete_time() { return complete_time; }
    
    // gets complete_time relative to sc_time_stamp()
    // (suitable for use as an annotated delay)
    void calc_complete_delay(sc_core::sc_time &delay);

    inline bool completed() { return complete_flag; }

    // destructor
    ~transaction_state();

private:
    // no copying/assigning
    transaction_state(const transaction_state&);
    transaction_state& operator= (const transaction_state&);

    // constructor
    transaction_state(
        dlsc_tlm_target_nb<MODULE,DATATYPE> *parent,
        tlm::tlm_generic_payload *payload,
        sc_core::sc_time ready_delay);

    inline tlm::tlm_generic_payload* get_payload() { return payload; }

    dlsc_tlm_target_nb<MODULE,DATATYPE> *parent;
    tlm::tlm_generic_payload            *payload;

    sc_core::sc_time                    ready_time;
    sc_core::sc_time                    complete_time;

    bool                                complete_flag;

    // invoked by public complete methods; notifies parent
    void complete_common();

    friend class dlsc_tlm_target_nb<MODULE,DATATYPE>;
};

// transaction completed at: sc_time_stamp()
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::complete() {
    complete_time = sc_core::sc_time_stamp();
    complete_common();
}

// transaction completed at: sc_time_stamp() + delay
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::complete_delay(sc_core::sc_time delay) {
    complete_time = sc_core::sc_time_stamp() + delay;
    complete_common();
}

// transaction completed at: ready_time + delta
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::complete_delta(sc_core::sc_time delta) {
    complete_time = ready_time + delta;
    complete_common();
}

// invoked by public complete methods; notifies parent
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::complete_common() {
    complete_flag = true;
    parent->completed_notify(payload);
}

// gets complete_time relative to sc_time_stamp()
// (suitable for use as an annotated delay)
template <typename MODULE, typename DATATYPE>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::calc_complete_delay(
    sc_core::sc_time &delay)
{
    sc_core::sc_time local_time = delay + sc_core::sc_time_stamp();

    if(complete_time > local_time) {
        delay += (complete_time - local_time);
    }
}

// set payload data
template <typename MODULE, typename DATATYPE> template <class InputIterator>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::set_data(InputIterator first) {
    assert(is_read() && payload->get_data_ptr());
    std::copy(first,first+size(),reinterpret_cast<DATATYPE*>(payload->get_data_ptr()));
}

// get payload data
template <typename MODULE, typename DATATYPE> template <class InputIterator>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::get_data(InputIterator first) {
    assert(is_write() && payload->get_data_ptr());
    DATATYPE *src_ptr = reinterpret_cast<DATATYPE*>(payload->get_data_ptr());
    std::copy(src_ptr,src_ptr+size(),first);
}

// get payload strobes
template <typename MODULE, typename DATATYPE> template <class InputIterator>
void dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::get_strobes(InputIterator first) {
    if(payload->get_byte_enable_length()) {
        // payload has strobes; use them
        assert(payload->get_byte_enable_ptr());
        uint8_t *strb_ptr = payload->get_byte_enable_ptr();
        InputIterator last = first+size();
        for(;first!=last;++first) {
            uint32_t strb = 0;
            for(unsigned int i=0;i<sizeof(DATATYPE);++i,++strb_ptr) {
                assert(*strb_ptr == TLM_BYTE_ENABLED || *strb_ptr == TLM_BYTE_DISABLED);
                if(*strb_ptr == TLM_BYTE_ENABLED) {
                    strb |= (1<<i);
                }
            }
            *first = strb;
        }
    } else {
        // payload lacks strobes; generate some
        uint32_t strb = (1<<sizeof(DATATYPE))-1;
        std::fill(first,first+size(),strb);
    }
}

// constructor
template <typename MODULE, typename DATATYPE>
dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::transaction_state(
    dlsc_tlm_target_nb<MODULE,DATATYPE> *parent,
    tlm::tlm_generic_payload *payload,
    sc_core::sc_time ready_delay
) :
    parent(parent),
    payload(payload)
{
    assert(parent && payload);
    payload->acquire();
    complete_flag = false;
    ready_time = sc_core::sc_time_stamp() + ready_delay;
}

// destructor
template <typename MODULE, typename DATATYPE>
dlsc_tlm_target_nb<MODULE,DATATYPE>::transaction_state::~transaction_state() {
    payload->release();
}

#endif

