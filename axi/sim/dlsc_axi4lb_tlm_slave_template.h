
#ifndef DLSC_AXI4LB_TLM_SLAVE_TEMPLATE_INCLUDED
#define DLSC_AXI4LB_TLM_SLAVE_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_axi_types.h"
#include "dlsc_common.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_axi4lb_tlm_slave_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<bool>       axi_ar_ready;
    sc_core::sc_in<bool>        axi_ar_valid;
    sc_core::sc_in<ADDRTYPE>    axi_ar_addr;
    sc_core::sc_in<uint32_t>    axi_ar_len;
    
    sc_core::sc_in<bool>        axi_r_ready;
    sc_core::sc_out<bool>       axi_r_valid;
    sc_core::sc_out<bool>       axi_r_last;
    sc_core::sc_out<DATATYPE>   axi_r_data;
    sc_core::sc_out<uint32_t>   axi_r_resp;

    sc_core::sc_out<bool>       axi_aw_ready;
    sc_core::sc_in<bool>        axi_aw_valid;
    sc_core::sc_in<ADDRTYPE>    axi_aw_addr;
    sc_core::sc_in<uint32_t>    axi_aw_len;
    
    sc_core::sc_out<bool>       axi_w_ready;
    sc_core::sc_in<bool>        axi_w_valid;
    sc_core::sc_in<bool>        axi_w_last;
    sc_core::sc_in<DATATYPE>    axi_w_data;
    sc_core::sc_in<uint32_t>    axi_w_strb;
    
    sc_core::sc_in<bool>        axi_b_ready;
    sc_core::sc_out<bool>       axi_b_valid;
    sc_core::sc_out<uint32_t>   axi_b_resp;
    
    typename dlsc_tlm_initiator_nb<DATATYPE>::socket_type socket;

    dlsc_tlm_initiator_nb<DATATYPE> *initiator;

    dlsc_axi4lb_tlm_slave_template(const sc_core::sc_module_name &nm);

    SC_HAS_PROCESS(dlsc_axi4lb_tlm_slave_template);

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    struct aw_command;
    
    // config
    int                         ar_pct;
    int                         r_pct;
    int                         aw_pct;
    int                         w_pct;
    int                         b_pct;

    std::deque<transaction>     ar_queue;
    std::deque<DATATYPE>        r_queue;
    std::deque<aw_command>      aw_queue;
    std::deque<DATATYPE>        w_data_queue;
    std::deque<uint32_t>        w_strb_queue;
    std::deque<transaction>     b_queue;

    bool                        w_wait_aw; // waiting for an AW command for already received W data

    void clk_method();
    void rst_method();
    void ar_method();
    void r_method();
    void aw_method();
    void w_method();
    void b_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::dlsc_axi4lb_tlm_slave_template(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm),
    clk("clk"),
    rst("rst"),
    axi_ar_ready("axi_ar_ready"),
    axi_ar_valid("axi_ar_valid"),
    axi_ar_addr("axi_ar_addr"),
    axi_ar_len("axi_ar_len"),
    axi_r_ready("axi_r_ready"),
    axi_r_valid("axi_r_valid"),
    axi_r_last("axi_r_last"),
    axi_r_data("axi_r_data"),
    axi_r_resp("axi_r_resp"),
    axi_aw_ready("axi_aw_ready"),
    axi_aw_valid("axi_aw_valid"),
    axi_aw_addr("axi_aw_addr"),
    axi_aw_len("axi_aw_len"),
    axi_w_ready("axi_w_ready"),
    axi_w_valid("axi_w_valid"),
    axi_w_last("axi_w_last"),
    axi_w_data("axi_w_data"),
    axi_w_strb("axi_w_strb"),
    axi_b_ready("axi_b_ready"),
    axi_b_valid("axi_b_valid"),
    axi_b_resp("axi_b_resp"),
    socket("socket")
{
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator");
        initiator->socket.bind(socket);

    ar_pct      = 95;
    r_pct       = 95;
    aw_pct      = 95;
    w_pct       = 95;
    b_pct       = 95;

    SC_METHOD(clk_method);
        sensitive << clk.pos();

    w_wait_aw   = false;
}
    
template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        rst_method();
    } else {
        ar_method();
        r_method();
        aw_method();
        w_method();
        b_method();
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::rst_method() {
    axi_ar_ready    = 0;
    axi_r_valid     = 0;
    axi_r_last      = 0;
    axi_r_data      = 0;
    axi_r_resp      = 0;
    axi_aw_ready    = 0;
    axi_w_ready     = 0;
    axi_b_valid     = 0;
    axi_b_resp      = 0;

    w_wait_aw       = false;
    
    ar_queue.clear();
    r_queue.clear();
    aw_queue.clear();
    w_data_queue.clear();
    w_strb_queue.clear();
    b_queue.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::ar_method() {
    if(axi_ar_ready && axi_ar_valid) {
        ar_queue.push_back(initiator->nb_read(axi_ar_addr,axi_ar_len+1));
    }

    axi_ar_ready    = (rand()%100) < ar_pct;
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::r_method() {
    if(!axi_r_valid || axi_r_ready) {
        if(r_queue.empty() && !ar_queue.empty() && ar_queue.front()->nb_done()) {
            transaction ts = ar_queue.front();
            ts->b_read(r_queue);
            switch(ts->b_status()) {
                case tlm::TLM_OK_RESPONSE:              axi_r_resp = dlsc::AXI_RESP_OKAY; break;
                case tlm::TLM_ADDRESS_ERROR_RESPONSE:   axi_r_resp = dlsc::AXI_RESP_DECERR; break;
                default:                                axi_r_resp = dlsc::AXI_RESP_SLVERR;
            }
            ar_queue.pop_front();
        }

        if(!r_queue.empty() && (rand()%100) < r_pct) {
            axi_r_data      = r_queue.front();
            r_queue.pop_front();
            axi_r_last      = r_queue.empty();
            axi_r_valid     = 1;
        } else {
//          axi_r_resp      = 0;    // can't clear resp, since it's only set once up above
            axi_r_data      = 0;
            axi_r_last      = 0;
            axi_r_valid     = 0;
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::aw_method() {
    if(axi_aw_ready && axi_aw_valid) {
        aw_command cmd = { axi_aw_addr, axi_aw_len+1 };
        aw_queue.push_back(cmd);
    }

    axi_aw_ready    = (rand()%100) < aw_pct;
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::w_method() {
    if(axi_w_ready && axi_w_valid) {
        w_data_queue.push_back(axi_w_data);
        w_strb_queue.push_back(axi_w_strb);

        if(axi_w_last) {
            // have complete data
            // must wait until we get a command
            w_wait_aw       = true;
        }
    }

    if(w_wait_aw && !aw_queue.empty()) {
        // now we have a command for our previously received data
        aw_command cmd = aw_queue.front();
        aw_queue.pop_front();

        if(cmd.len != w_data_queue.size()) {
            dlsc_error("AW/W length mismatch");
            w_data_queue.resize(cmd.len);
            w_strb_queue.resize(cmd.len);
        }

        b_queue.push_back(initiator->nb_write(cmd.addr,w_data_queue,w_strb_queue));

        w_data_queue.clear();
        w_strb_queue.clear();

        w_wait_aw       = false;
    }

    if(w_wait_aw) {
        axi_w_ready     = 0;
    } else {
        axi_w_ready     = (rand()%100) < w_pct;
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::b_method() {
    if(!axi_b_valid || axi_b_ready) {
        if(!b_queue.empty() && b_queue.front()->nb_done() && (rand()%100) < b_pct) {
            transaction ts = b_queue.front();
            switch(ts->b_status()) {
                case tlm::TLM_OK_RESPONSE:              axi_b_resp = dlsc::AXI_RESP_OKAY; break;
                case tlm::TLM_ADDRESS_ERROR_RESPONSE:   axi_b_resp = dlsc::AXI_RESP_DECERR; break;
                default:                                axi_b_resp = dlsc::AXI_RESP_SLVERR;
            }
            axi_b_valid     = 1;
            b_queue.pop_front();
        } else {
            axi_b_resp      = 0;
            axi_b_valid     = 0;
        }
    }
}

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
struct dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::aw_command {
    uint64_t                    addr;
    unsigned int                len;
};

#endif

