
#ifndef DLSC_CSR_TLM_MASTER_TEMPLATE_INCLUDED
#define DLSC_CSR_TLM_MASTER_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_target_nb.h"
#include "dlsc_common.h"
#include "dlsc_util.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_csr_tlm_master_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<bool>       csr_cmd_valid;
    sc_core::sc_out<bool>       csr_cmd_write;
    sc_core::sc_out<ADDRTYPE>   csr_cmd_addr;
    sc_core::sc_out<DATATYPE>   csr_cmd_data;
    sc_core::sc_in<bool>        csr_rsp_valid;
    sc_core::sc_in<bool>        csr_rsp_error;
    sc_core::sc_in<DATATYPE>    csr_rsp_data;
    
    typedef typename dlsc_tlm_target_nb<dlsc_csr_tlm_master_template,DATATYPE>::socket_type socket_type;

    socket_type socket;
    
    dlsc_tlm_target_nb<dlsc_csr_tlm_master_template,DATATYPE> *target;

    dlsc_csr_tlm_master_template(const sc_core::sc_module_name &nm);
    
    typedef typename dlsc_tlm_target_nb<dlsc_csr_tlm_master_template,DATATYPE>::transaction transaction;
    
    virtual void target_callback(transaction ts);
    
    SC_HAS_PROCESS(dlsc_csr_tlm_master_template);

private:

    struct burst_state;

    bool                        active;     // in the middle of a transaction

    std::deque<burst_state>     bt_queue;

    int                         valid_pct;

    void clk_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_csr_tlm_master_template<DATATYPE,ADDRTYPE>::dlsc_csr_tlm_master_template(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm),
    clk("clk"),
    rst("rst"),
    csr_cmd_valid("csr_cmd_valid"),
    csr_cmd_write("csr_cmd_write"),
    csr_cmd_addr("csr_cmd_addr"),
    csr_cmd_data("csr_cmd_data"),
    csr_rsp_valid("csr_rsp_valid"),
    csr_rsp_error("csr_rsp_error"),
    csr_rsp_data("csr_rsp_data"),
    socket("socket")
{
    target = new dlsc_tlm_target_nb<dlsc_csr_tlm_master_template,DATATYPE>(
        "target", this, &dlsc_csr_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback);
    socket.bind(target->socket);

    SC_METHOD(clk_method);
        sensitive << clk.pos();

    active          = false;

    valid_pct       = 70;
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_csr_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback(transaction ts) {
    // default to OK; will be set to something else on error
    ts->set_response_status(tlm::TLM_OK_RESPONSE);

    burst_state bt;
    bt.ts = ts;

    uint64_t addr = ts->get_address() & ~((uint64_t)sizeof(DATATYPE)-1);

    for(unsigned int i=0;i<ts->size();++i) {
        bt.addr.push_back(addr);
        addr += sizeof(DATATYPE);
    }

    if(ts->is_write()) {
        ts->get_data(bt.data);
        ts->get_strobes(bt.strb);
    }

    bt_queue.push_back(bt);
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_csr_tlm_master_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        csr_cmd_valid   = 0;
        csr_cmd_write   = 0;
        csr_cmd_addr    = 0;
        csr_cmd_data    = 0;
        active          = false;
        while(!bt_queue.empty()) {
            transaction ts = bt_queue.front().ts; bt_queue.pop_front();
            dlsc_verb("lost transaction to reset");
            ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
            ts->complete();
        }
        bt_queue.clear();
    } else {

        // command is only valid for a single cycle
        csr_cmd_valid   = 0;

        // check for response
        if(csr_rsp_valid) {
            if(active) {
                // got response; end transaction
                active          = false;
                
                assert(!bt_queue.empty());
                burst_state &bt = bt_queue.front();
                
                if(csr_rsp_error) {
                    // got error
                    bt.ts->set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
                }

                if(bt.ts->is_write()) {
                    // write; check for completion
                    if(bt.data.empty()) {
                        bt.ts->complete();
                        bt_queue.pop_front();
                    }
                } else {
                    // read; push data; check for completion
                    bt.data.push_back(csr_rsp_data);
                    if(bt.data.size() == bt.ts->size()) {
                        bt.ts->set_data(bt.data);
                        bt.ts->complete();
                        bt_queue.pop_front();
                    }
                }
            } else {
                // unexpected
                dlsc_error("unexpected response");
            }
        } else {
            // check idle state
            if(csr_rsp_error) {
                dlsc_warn("csr_rsp_error should idle low");
            }
            if(csr_rsp_data) {
                dlsc_warn("csr_rsp_data should idle low");
            }
        }

        // drive new command
        if(!active && !bt_queue.empty() && dlsc_rand_bool(valid_pct)) {
            burst_state &bt = bt_queue.front();
            assert(!bt.addr.empty());
            csr_cmd_addr    = bt.addr.front(); bt.addr.pop_front();
            if(bt.ts->is_write()) {
                assert(!bt.data.empty() && !bt.strb.empty());
                csr_cmd_write   = 1;
                csr_cmd_data    = bt.data.front(); bt.data.pop_front();
            } else {
                csr_cmd_write   = 0;
            }
            csr_cmd_valid   = 1;
            active          = true;
        }

    }
}

template <typename DATATYPE, typename ADDRTYPE>
struct dlsc_csr_tlm_master_template<DATATYPE,ADDRTYPE>::burst_state {
    transaction             ts;
    std::deque<uint64_t>    addr;
    std::deque<DATATYPE>    data;
    std::deque<uint32_t>    strb;
};

#endif

