
#ifndef DLSC_TLM_INITIATOR_NB_INCLUDED
#define DLSC_TLM_INITIATOR_NB_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/peq_with_get.h>
#include <tlm_utils/multi_passthrough_initiator_socket.h>

#include <vector>
#include <deque>
#include <map>
#include <algorithm>
#include <boost/shared_ptr.hpp>

#include "dlsc_tlm_mm.h"
#include "dlsc_tlm_utils.h"

#include "dlsc_common.h"

template <typename DATATYPE = uint32_t>
class dlsc_tlm_initiator_nb : public sc_core::sc_module {
public:

    typedef tlm_utils::multi_passthrough_initiator_socket<dlsc_tlm_initiator_nb<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> socket_type;

    socket_type socket;

    class transaction_state;
    typedef boost::shared_ptr<transaction_state> transaction;

    // constructor
    dlsc_tlm_initiator_nb(const sc_core::sc_module_name &nm, const unsigned int max_length = 16);
    void end_of_elaboration();
    
    // sets socket to use for subsequent transactions
    void set_socket(int id);
    inline unsigned int get_socket_size() { return socket.size(); }

    // *** Read ***
    transaction nb_read(
        const uint64_t addr,
        const unsigned int length,
        sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME);

    // *** Writes (data only) ***
    template <class InputIterator>
    transaction nb_write(
        const uint64_t addr,
        InputIterator first,
        const InputIterator last,
        sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME);
    
    inline transaction nb_write(
        const uint64_t addr,
        std::vector<DATATYPE> &data,
        sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME)
    {
        return nb_write(addr,data.begin(),data.end(),delay_initial);
    }
    
    inline transaction nb_write(
        const uint64_t addr,
        std::deque<DATATYPE> &data,
        sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME)
    {
        return nb_write(addr,data.begin(),data.end(),delay_initial);
    }
    
    // *** Writes (data and strobes) ***
    template <class DataIterator,class StrbIterator>
    transaction nb_write(
        const uint64_t      addr,
        DataIterator        data_first,
        const DataIterator  data_last,
        StrbIterator        strb_first,
        const StrbIterator  strb_last,
        sc_core::sc_time    delay_initial = sc_core::SC_ZERO_TIME);
    
    inline transaction nb_write(
        const uint64_t addr,
        std::vector<DATATYPE> &data,
        std::vector<uint32_t> &strb,
        sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME)
    {
        return nb_write(addr,data.begin(),data.end(),strb.begin(),strb.end(),delay_initial);
    }
    
    inline transaction nb_write(
        const uint64_t addr,
        std::deque<DATATYPE> &data,
        std::deque<uint32_t> &strb,
        sc_core::sc_time delay_initial = sc_core::SC_ZERO_TIME)
    {
        return nb_write(addr,data.begin(),data.end(),strb.begin(),strb.end(),delay_initial);
    }

    // methods to wait for completions
    void wait();
    void wait(sc_core::sc_time &delay);

    // callback for simple_initiator_socket
    virtual tlm::tlm_sync_enum nb_transport_bw(int id,tlm::tlm_generic_payload &trans,tlm::tlm_phase &phase,sc_time &delay);
    
    SC_HAS_PROCESS(dlsc_tlm_initiator_nb);

private:
    // no copying/assigning
    dlsc_tlm_initiator_nb(const dlsc_tlm_initiator_nb&);
    dlsc_tlm_initiator_nb& operator= (const dlsc_tlm_initiator_nb&);
    
    // parameters
    const unsigned int bus_width;
    const unsigned int max_length;
    const unsigned int max_lengthb;

    int current_socket_id;

    // non-blocking
    dlsc_tlm_mm         mm;

    bool                        launch_outstanding;
    std::deque<transaction>     launch_queue;
    std::map<tlm::tlm_generic_payload*,transaction> outstanding;

    tlm_utils::peq_with_get<tlm::tlm_generic_payload> complete_queue;

    sc_core::sc_event           launch_event;

    transaction launch(tlm::tlm_generic_payload *trans, sc_core::sc_time &delay);
    void launch_update(sc_core::sc_time &delay);
    void launch_method();

    void complete_local(transaction ts, sc_core::sc_time &delay);
    void complete_final(transaction ts);
    void complete_method();
};
   

// *** dlsc_tlm_initiator_nb public functions ***

template <typename DATATYPE>
dlsc_tlm_initiator_nb<DATATYPE>::dlsc_tlm_initiator_nb(
    const sc_core::sc_module_name &nm,
    const unsigned int max_length
) :
    sc_module(nm),
    socket("socket"),
    bus_width(sizeof(DATATYPE)),
    max_length(max_length),
    max_lengthb(max_length*bus_width),
    mm(20,max_lengthb),
    complete_queue("complete_queue")
{
    launch_outstanding  = false;
    current_socket_id   = 0;

    socket.register_nb_transport_bw(this,&dlsc_tlm_initiator_nb<DATATYPE>::nb_transport_bw);

    SC_METHOD(launch_method);
        sensitive << launch_event;
    
    SC_METHOD(complete_method);
        sensitive << complete_queue.get_event();
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::end_of_elaboration() {
    dlsc_info("targets bound: " << get_socket_size());
    assert(get_socket_size() > 0);
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::set_socket(int id) {
    assert(id >= 0 && id < static_cast<int>(socket.size()));
    current_socket_id = id;
}

// *** Read ***
template <typename DATATYPE>
typename dlsc_tlm_initiator_nb<DATATYPE>::transaction
dlsc_tlm_initiator_nb<DATATYPE>::nb_read(
    const uint64_t addr,
    const unsigned int length,
    sc_core::sc_time delay_initial
) {
    assert(length <= max_length);

    tlm::tlm_generic_payload *trans = mm.alloc();
    trans->set_command(tlm::TLM_READ_COMMAND);
    trans->set_address(addr);
    trans->set_data_length(length*bus_width);
    trans->set_byte_enable_length(0);
    trans->set_streaming_width(trans->get_data_length());

    // delay_initial is pass-by-value, so initiator's delay will NOT be modified
    // any delay annotated by the transaction will be accounted for on completion
    return launch(trans,delay_initial);
}

// *** Writes (data only) ***
template <typename DATATYPE> template <class InputIterator>
typename dlsc_tlm_initiator_nb<DATATYPE>::transaction
dlsc_tlm_initiator_nb<DATATYPE>::nb_write(
    const uint64_t addr,
    InputIterator first,
    const InputIterator last,
    sc_core::sc_time delay_initial
) {
    unsigned int lengthb = (last - first) * bus_width;
    assert(first != last && lengthb <= max_lengthb);

    tlm::tlm_generic_payload *trans = mm.alloc();
    trans->set_command(tlm::TLM_WRITE_COMMAND);
    trans->set_address(addr);
    trans->set_data_length(lengthb);
    trans->set_byte_enable_length(0);
    trans->set_streaming_width(lengthb);

    std::copy(first,last,reinterpret_cast<DATATYPE*>(trans->get_data_ptr()));

    // delay_initial is pass-by-value, so initiator's delay will NOT be modified
    // any delay annotated by the transaction will be accounted for on completion
    return launch(trans,delay_initial);
}

// *** Writes (data and strobes) ***
template <typename DATATYPE> template <class DataIterator,class StrbIterator>
typename dlsc_tlm_initiator_nb<DATATYPE>::transaction
dlsc_tlm_initiator_nb<DATATYPE>::nb_write(
    const uint64_t      addr,
    DataIterator        data_first,
    const DataIterator  data_last,
    StrbIterator        strb_first,
    const StrbIterator  strb_last,
    sc_core::sc_time    delay_initial
) {
    assert(data_last != data_first && (data_last-data_first) == (strb_last-strb_first));
    unsigned int lengthb = (data_last - data_first) * bus_width;
    assert(lengthb <= max_lengthb);

    tlm::tlm_generic_payload *trans = mm.alloc();
    trans->set_command(tlm::TLM_WRITE_COMMAND);
    trans->set_address(addr);
    trans->set_data_length(lengthb);
    trans->set_byte_enable_length(lengthb);
    trans->set_streaming_width(lengthb);

    // set data
    std::copy(data_first,data_last,reinterpret_cast<DATATYPE*>(trans->get_data_ptr()));

    // set strobes
    bool all_enabled = true;
    uint8_t *strb_ptr = trans->get_byte_enable_ptr();
    for(;strb_first!=strb_last;++strb_first) {
        uint32_t strb = *strb_first;
        for(unsigned int i=0;i<sizeof(DATATYPE);++i,++strb_ptr) {
            if(strb & (1<<i)) {
                *strb_ptr = TLM_BYTE_ENABLED;
            } else {
                *strb_ptr = TLM_BYTE_DISABLED;
                all_enabled = false;
            }
        }
    }

    // if all strobes were enabled, remove them from transaction
    if(all_enabled) {
        trans->set_byte_enable_length(0);
    }

    // delay_initial is pass-by-value, so initiator's delay will NOT be modified
    // any delay annotated by the transaction will be accounted for on completion
    return launch(trans,delay_initial);
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::wait() {
    while(!outstanding.empty()) {
        transaction ts = (*(outstanding.begin())).second;
        ts->wait();
    }
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::wait(sc_core::sc_time &delay) {
    while(!outstanding.empty()) {
        transaction ts = (*(outstanding.begin())).second;
        ts->wait(delay);
    }
}

template <typename DATATYPE>
tlm::tlm_sync_enum dlsc_tlm_initiator_nb<DATATYPE>::nb_transport_bw(
    int id,
    tlm::tlm_generic_payload &trans,
    tlm::tlm_phase &phase,
    sc_time &delay)
{
    assert(phase != tlm::BEGIN_REQ && phase != tlm::END_RESP); // we generate these phases

    if(phase == tlm::END_REQ) {
        assert(launch_outstanding && !launch_queue.empty() && launch_queue.front()->payload == &trans);

        launch_queue.pop_front();
        launch_outstanding = false;
        launch_event.notify();
        
        return tlm::TLM_ACCEPTED;
    }

    if(phase == tlm::BEGIN_RESP) {
        transaction ts = outstanding[&trans];
        assert(ts && ts->get_socket_id() == id);
        complete_local(ts,delay);

        phase = tlm::END_RESP;
        return tlm::TLM_COMPLETED;
    }

    dlsc_info("ignored unexpected phase");

    return tlm::TLM_ACCEPTED;
}


// *** dlsc_tlm_initiator_nb private functions ***

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::launch_method() {
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
    launch_update(delay);
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::launch_update(sc_core::sc_time &delay) {
    while(!launch_outstanding && !launch_queue.empty()) {
        transaction ts = launch_queue.front();
        
        tlm::tlm_phase phase = tlm::BEGIN_REQ;
        tlm::tlm_sync_enum r = socket[ts->get_socket_id()]->nb_transport_fw(*(ts->get_payload()),phase,delay);

        if(r == tlm::TLM_ACCEPTED || phase == tlm::BEGIN_REQ) {
            // waiting for END_REQ
            launch_outstanding = true;
            return;
        } else {
            // request accepted; remove from queue
            launch_queue.pop_front();
        }

        if(r != tlm::TLM_COMPLETED && phase == tlm::BEGIN_RESP) {
            // target expects END_RESP; generate it
            phase = tlm::END_RESP;
            socket[ts->get_socket_id()]->nb_transport_fw(*(ts->get_payload()),phase,delay);
        }

        if(r == tlm::TLM_COMPLETED || phase == tlm::BEGIN_RESP) {
            // response received; complete transaction
            complete_local(ts,delay);
        }
    }
}

template <typename DATATYPE>
typename dlsc_tlm_initiator_nb<DATATYPE>::transaction dlsc_tlm_initiator_nb<DATATYPE>::launch(tlm::tlm_generic_payload *trans, sc_core::sc_time &delay) {
    transaction ts(new transaction_state(trans,delay!=sc_core::SC_ZERO_TIME,current_socket_id));
    launch_queue.push_back(ts);
    outstanding[trans] = ts;
    launch_update(delay);
    return ts;
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::complete_local(transaction ts, sc_core::sc_time &delay) {
    ts->notify_local(sc_core::sc_time_stamp() + delay);

    if(delay == sc_core::SC_ZERO_TIME) {
        complete_final(ts); // will notify
    } else {
        complete_queue.notify(*(ts->get_payload()),delay);
    }
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::complete_final(transaction ts) {
    outstanding.erase(ts->get_payload());
    ts->notify();
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::complete_method() {
    tlm::tlm_generic_payload *trans;
    while( (trans = complete_queue.get_next_transaction()) ) {
        transaction ts = outstanding[trans];
        assert(ts);
        complete_final(ts);
    }
}




template <typename DATATYPE = uint32_t>
class dlsc_tlm_initiator_nb<DATATYPE>::transaction_state {
public:

    void wait();
    void wait(sc_core::sc_time &delay);

    inline bool nb_done();
    bool nb_done(sc_core::sc_time &delay);

    // *** Blocking Reads (annotated) ***

    template<class InputIterator>
    bool b_read(InputIterator first, sc_core::sc_time &delay);

    inline bool b_read(DATATYPE &data, sc_core::sc_time &delay);
    inline bool b_read(std::vector<DATATYPE> &data, sc_core::sc_time &delay);
    inline bool b_read(std::deque<DATATYPE> &data, sc_core::sc_time &delay);
    
    tlm::tlm_response_status b_status(sc_core::sc_time &delay);

    // *** Blocking Reads (unannotated) ***

    template<class InputIterator>
    bool b_read(InputIterator first);

    inline bool b_read(DATATYPE &data);
    inline bool b_read(std::vector<DATATYPE> &data);
    inline bool b_read(std::deque<DATATYPE> &data);

    tlm::tlm_response_status b_status();
    
    inline bool is_read() { return payload->is_read(); }
    inline bool is_write() { return payload->is_write(); }
    inline uint64_t get_address() { return payload->get_address(); }
    inline unsigned int size() { return payload->get_data_length()/sizeof(DATATYPE); }
    inline int get_socket_id() { return socket_id; }

    ~transaction_state();

private:
    // no copying/assigning
    transaction_state(const transaction_state&);
    transaction_state& operator= (const transaction_state&);

    transaction_state(tlm::tlm_generic_payload *payload, bool tann, int socket_id);

    void notify_local(sc_core::sc_time dt);
    void notify();

    inline tlm::tlm_generic_payload* get_payload();

    tlm::tlm_generic_payload            *payload;

    sc_core::sc_event                   done_event;

    sc_core::sc_time                    done_time;          // time that transaction actually completes

    bool                                done_flag;          // transaction actually complete (done_time reached)
    bool                                done_flag_local;    // transaction complete (response received)

    const bool                          was_annotated;      // indicates transaction was created with a timing-annotated call

    const int                           socket_id;

    friend class dlsc_tlm_initiator_nb<DATATYPE>;
};

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::wait() {
    // only reasonable to use wait() on an un-annotated transaction
    assert(!was_annotated);

    while(!done_flag) {
        // done_event may fire twice (once for done_flag_local; once for done_flag)
        sc_core::wait(done_event);
    }
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::wait(sc_core::sc_time &delay) {
    // compute the effective local_time
    sc_core::sc_time local_time = sc_core::sc_time_stamp() + delay;

    if(!done_flag_local) {
        // transaction hasn't been completed by target yet; wait for it to complete
        sc_core::wait(done_event);
        assert(done_flag_local); // must be done now...

        // adjust delay for time spent sleeping
        if(local_time > sc_core::sc_time_stamp()) {
            delay = local_time - sc_core::sc_time_stamp();
        } else {
            delay = sc_core::SC_ZERO_TIME;
        }

        // compute new local_time
        local_time = sc_core::sc_time_stamp() + delay;
    }

    // transaction is now complete, but it may still have effectively completed in the future
    if(local_time < done_time) {
        // advance delay so local_time == done_time
        delay += (done_time - local_time);
    }

    // check for quantum boundary
    dlsc_tlm_quantum_wait(delay);
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::nb_done() {
    return done_flag;
}

template <typename DATATYPE>
bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::nb_done(sc_core::sc_time &delay) {
    return done_flag_local && !(sc_core::sc_time_stamp() + delay < done_time);
}

// *** Blocking Reads (annotated) ***

template <typename DATATYPE> template <class InputIterator>
bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(InputIterator first, sc_core::sc_time &delay) {
    this->wait(delay);
    if(payload->get_response_status() != tlm::TLM_OK_RESPONSE) {
        return false;
    }
    DATATYPE *src_ptr = reinterpret_cast<DATATYPE*>(payload->get_data_ptr());
    std::copy(src_ptr,src_ptr+size(),first);
    return true;
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(DATATYPE &data, sc_core::sc_time &delay) {
    return b_read(&data,delay);
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(std::vector<DATATYPE> &data, sc_core::sc_time &delay) {
    data.resize(size());
    return b_read(data.begin(),delay);
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(std::deque<DATATYPE> &data, sc_core::sc_time &delay) {
    data.resize(size());
    return b_read(data.begin(),delay);
}

template <typename DATATYPE>
tlm::tlm_response_status dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_status(sc_core::sc_time &delay) {
    this->wait(delay);
    return payload->get_response_status();
}

// *** Blocking Reads (unannotated) ***

template <typename DATATYPE> template <class InputIterator>
bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(InputIterator first) {
    this->wait();
    if(payload->get_response_status() != tlm::TLM_OK_RESPONSE) {
        return false;
    }
    DATATYPE *src_ptr = reinterpret_cast<DATATYPE*>(payload->get_data_ptr());
    std::copy(src_ptr,src_ptr+size(),first);
    return true;
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(DATATYPE &data) {
    return b_read(&data);
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(std::vector<DATATYPE> &data) {
    data.resize(size());
    return b_read(data.begin());
}

template <typename DATATYPE>
inline bool dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_read(std::deque<DATATYPE> &data) {
    data.resize(size());
    return b_read(data.begin());
}

template <typename DATATYPE>
tlm::tlm_response_status dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::b_status() {
    this->wait();
    return payload->get_response_status();
}


template <typename DATATYPE>
dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::~transaction_state() {
    payload->release();
}

// *** private functions ***

template <typename DATATYPE>
dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::transaction_state(
    tlm::tlm_generic_payload *payload,
    bool tann,
    int socket_id
) :
    payload(payload),
    was_annotated(tann),
    socket_id(socket_id)
{
    payload->acquire();
    done_time       = sc_core::SC_ZERO_TIME;
    done_flag       = false;
    done_flag_local = false;
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::notify_local(sc_core::sc_time dt) {
    done_flag_local = true;
    done_time       = dt;
    done_event.notify();
}

template <typename DATATYPE>
void dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::notify() {
    assert(done_flag_local); // shouldn't be invoked until after notify_local() is
    done_flag       = true;
    done_event.notify();
}

template <typename DATATYPE>
inline tlm::tlm_generic_payload* dlsc_tlm_initiator_nb<DATATYPE>::transaction_state::get_payload() {
    return payload;
}

#endif

