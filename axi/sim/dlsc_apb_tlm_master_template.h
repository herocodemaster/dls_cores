
#ifndef DLSC_APB_TLM_MASTER_TEMPLATE_INCLUDED
#define DLSC_APB_TLM_MASTER_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_target_nb.h"
#include "dlsc_common.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_apb_tlm_master_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<ADDRTYPE>   apb_addr;
    sc_core::sc_out<bool>       apb_sel;
    sc_core::sc_out<bool>       apb_enable;
    sc_core::sc_out<bool>       apb_write;
    sc_core::sc_out<DATATYPE>   apb_wdata;
    sc_core::sc_out<uint32_t>   apb_strb;
    sc_core::sc_in<bool>        apb_ready;
    sc_core::sc_in<DATATYPE>    apb_rdata;
    sc_core::sc_in<bool>        apb_slverr;
    
    tlm::tlm_target_socket<sizeof(DATATYPE)*8> socket;
    
    dlsc_tlm_target_nb<dlsc_apb_tlm_master_template,DATATYPE> *target;

    dlsc_apb_tlm_master_template(const sc_core::sc_module_name &nm);
    
    typedef typename dlsc_tlm_target_nb<dlsc_apb_tlm_master_template,DATATYPE>::transaction transaction;
    
    virtual void target_callback(transaction ts);
    
    SC_HAS_PROCESS(dlsc_apb_tlm_master_template);

private:

    struct burst_state;

    std::deque<burst_state>     bt_queue;

    int                         sel_pct;

    void clk_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_apb_tlm_master_template<DATATYPE,ADDRTYPE>::dlsc_apb_tlm_master_template(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm),
    clk("clk"),
    rst("rst"),
    apb_addr("apb_addr"),
    apb_sel("apb_sel"),
    apb_enable("apb_enable"),
    apb_write("apb_write"),
    apb_wdata("apb_wdata"),
    apb_strb("apb_strb"),
    apb_ready("apb_ready"),
    apb_rdata("apb_rdata"),
    apb_slverr("apb_slverr"),
    socket("socket")
{
    target = new dlsc_tlm_target_nb<dlsc_apb_tlm_master_template,DATATYPE>(
        "target", this, &dlsc_apb_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback);
    socket.bind(target->socket);

    SC_METHOD(clk_method);
        sensitive << clk.pos();

    sel_pct         = 95;
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_apb_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback(transaction ts) {
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
void dlsc_apb_tlm_master_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        apb_addr        = 0;
        apb_sel         = 0;
        apb_enable      = 0;
        apb_write       = 0;
        apb_wdata       = 0;
        apb_strb        = 0;
        while(!bt_queue.empty()) {
            transaction ts = bt_queue.front().ts; bt_queue.pop_front();
            dlsc_verb("lost transaction to reset");
            ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
            ts->complete();
        }
        bt_queue.clear();
    } else {

        if(apb_sel) {
            // continue ongoing transaction
            assert(!bt_queue.empty());
            burst_state &bt = bt_queue.front();
            if(!apb_enable) {
                // completed setup phase; prepare for response
                apb_enable      = 1;
            } else if(apb_ready) {
                // got response; end transaction
                apb_sel         = 0;
                apb_enable      = 0;
                
                if(apb_slverr) {
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
                    bt.data.push_back(apb_rdata);
                    if(bt.data.size() == bt.ts->size()) {
                        bt.ts->set_data(bt.data);
                        bt.ts->complete();
                        bt_queue.pop_front();
                    }
                }
            }
        }

        if( (!apb_sel || (apb_enable && apb_ready)) && !bt_queue.empty() && (rand()%100) < sel_pct) {
            // can start new transaction
            burst_state &bt = bt_queue.front();
            assert(!bt.addr.empty());
            apb_addr    = bt.addr.front(); bt.addr.pop_front();
            if(bt.ts->is_write()) {
                assert(!bt.data.empty() && !bt.strb.empty());
                apb_wdata   = bt.data.front(); bt.data.pop_front();
                apb_strb    = bt.strb.front(); bt.strb.pop_front();
                apb_write   = 1;
            } else {
                apb_strb    = 0;
                apb_write   = 0;
            }
            apb_sel     = 1;
        }
        
        if(!apb_sel) {
            // check idle state
            if(apb_ready) {
                dlsc_warn("apb_ready should idle low");
            }
            if(apb_rdata) {
                dlsc_warn("apb_rdata should idle low");
            }
            if(apb_slverr) {
                dlsc_warn("apb_slverr should idle low");
            }
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
struct dlsc_apb_tlm_master_template<DATATYPE,ADDRTYPE>::burst_state {
    transaction             ts;
    std::deque<uint64_t>    addr;
    std::deque<DATATYPE>    data;
    std::deque<uint32_t>    strb;
};

#endif

