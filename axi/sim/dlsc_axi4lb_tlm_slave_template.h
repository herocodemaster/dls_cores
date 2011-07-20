
#ifndef DLSC_AXI4LB_TLM_SLAVE_TEMPLATE_INCLUDED
#define DLSC_AXI4LB_TLM_SLAVE_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>
#include <map>
#include <iterator>

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
    sc_core::sc_in<uint32_t>    axi_ar_id;
    sc_core::sc_in<ADDRTYPE>    axi_ar_addr;
    sc_core::sc_in<uint32_t>    axi_ar_len;
    
    sc_core::sc_in<bool>        axi_r_ready;
    sc_core::sc_out<bool>       axi_r_valid;
    sc_core::sc_out<bool>       axi_r_last;
    sc_core::sc_out<uint32_t>   axi_r_id;
    sc_core::sc_out<DATATYPE>   axi_r_data;
    sc_core::sc_out<uint32_t>   axi_r_resp;

    sc_core::sc_out<bool>       axi_aw_ready;
    sc_core::sc_in<bool>        axi_aw_valid;
    sc_core::sc_in<uint32_t>    axi_aw_id;
    sc_core::sc_in<ADDRTYPE>    axi_aw_addr;
    sc_core::sc_in<uint32_t>    axi_aw_len;
    
    sc_core::sc_out<bool>       axi_w_ready;
    sc_core::sc_in<bool>        axi_w_valid;
    sc_core::sc_in<bool>        axi_w_last;
    sc_core::sc_in<DATATYPE>    axi_w_data;
    sc_core::sc_in<uint32_t>    axi_w_strb;
    
    sc_core::sc_in<bool>        axi_b_ready;
    sc_core::sc_out<bool>       axi_b_valid;
    sc_core::sc_out<uint32_t>   axi_b_id;
    sc_core::sc_out<uint32_t>   axi_b_resp;
    
    typename dlsc_tlm_initiator_nb<DATATYPE>::socket_type socket;

    dlsc_tlm_initiator_nb<DATATYPE> *initiator;

    dlsc_axi4lb_tlm_slave_template(const sc_core::sc_module_name &nm);

    SC_HAS_PROCESS(dlsc_axi4lb_tlm_slave_template);

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    struct aw_command;

    struct r_type;
    
    // config
    int                         ar_pct;
    int                         r_pct;
    int                         aw_pct;
    int                         w_pct;
    int                         b_pct;

    std::map<uint32_t,std::deque<transaction> > ar_queue;

    std::map<uint32_t,std::deque<r_type> > r_queue;

    std::deque<aw_command>      aw_queue;
    std::deque<DATATYPE>        w_data_queue;
    std::deque<uint32_t>        w_strb_queue;

    std::map<uint32_t,std::deque<transaction> > bts_queue;

    std::map<uint32_t,std::deque<uint32_t> > b_queue;

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
    axi_ar_id("axi_ar_id"),
    axi_ar_addr("axi_ar_addr"),
    axi_ar_len("axi_ar_len"),
    axi_r_ready("axi_r_ready"),
    axi_r_valid("axi_r_valid"),
    axi_r_last("axi_r_last"),
    axi_r_id("axi_r_id"),
    axi_r_data("axi_r_data"),
    axi_r_resp("axi_r_resp"),
    axi_aw_ready("axi_aw_ready"),
    axi_aw_valid("axi_aw_valid"),
    axi_aw_id("axi_aw_id"),
    axi_aw_addr("axi_aw_addr"),
    axi_aw_len("axi_aw_len"),
    axi_w_ready("axi_w_ready"),
    axi_w_valid("axi_w_valid"),
    axi_w_last("axi_w_last"),
    axi_w_data("axi_w_data"),
    axi_w_strb("axi_w_strb"),
    axi_b_ready("axi_b_ready"),
    axi_b_valid("axi_b_valid"),
    axi_b_id("axi_b_id"),
    axi_b_resp("axi_b_resp"),
    socket("socket")
{
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator",256);
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
    axi_r_id        = 0;
    axi_r_data      = 0;
    axi_r_resp      = 0;
    axi_aw_ready    = 0;
    axi_w_ready     = 0;
    axi_b_valid     = 0;
    axi_b_id        = 0;
    axi_b_resp      = 0;

    w_wait_aw       = false;
    
    ar_queue.clear();
    r_queue.clear();
    aw_queue.clear();
    w_data_queue.clear();
    w_strb_queue.clear();
    bts_queue.clear();
    b_queue.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::ar_method() {
    if(axi_ar_ready && axi_ar_valid) {
        initiator->set_socket(axi_ar_id.read() % initiator->get_socket_size());
        ar_queue[axi_ar_id.read()].push_back(initiator->nb_read(axi_ar_addr,axi_ar_len+1));
    }

    typename std::map<uint32_t,std::deque<transaction> >::iterator it = ar_queue.begin();
    for(; it != ar_queue.end(); it++) {
        if(!it->second.empty() && it->second.front()->nb_done()) {
            transaction ts = it->second.front(); it->second.pop_front();
            r_type rt;
            ts->b_read(rt.data);
            switch(ts->b_status()) {
                case tlm::TLM_OK_RESPONSE:              rt.resp = dlsc::AXI_RESP_OKAY; break;
                case tlm::TLM_ADDRESS_ERROR_RESPONSE:   rt.resp = dlsc::AXI_RESP_DECERR; break;
                default:                                rt.resp = dlsc::AXI_RESP_SLVERR;
            }
            r_queue[it->first].push_back(rt);
        }
    }

    axi_ar_ready    = (rand()%100) < ar_pct;
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::r_method() {
    if(!axi_r_valid || axi_r_ready) {
        if(!r_queue.empty() && (rand()%100) < r_pct) {
            // select a random ID
            typename std::map<uint32_t,std::deque<r_type> >::iterator it = r_queue.begin();
            std::advance(it,(rand()%r_queue.size()));
            assert(!it->second.empty());

            r_type &rt = it->second.front();
            assert(!rt.data.empty());

            axi_r_id        = it->first;
            axi_r_resp      = rt.resp;
            axi_r_data      = rt.data.front(); rt.data.pop_front();
            axi_r_last      = rt.data.empty();
            axi_r_valid     = 1;

            if(rt.data.empty()) {
                // finished this response
                it->second.pop_front();
                if(it->second.empty()) {
                    // no more for this ID (for now)
                    r_queue.erase(it);
                }
            }
        } else {
            axi_r_id        = 0;
            axi_r_resp      = 0;
            axi_r_data      = 0;
            axi_r_last      = 0;
            axi_r_valid     = 0;
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::aw_method() {
    if(axi_aw_ready && axi_aw_valid) {
        aw_command cmd = { axi_aw_id, axi_aw_addr, axi_aw_len+1 };
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
            dlsc_error("AW/W length mismatch; expected: " << std::dec << cmd.len << ", but got: " << w_data_queue.size());
            w_data_queue.resize(cmd.len);
            w_strb_queue.resize(cmd.len);
        }

        initiator->set_socket(cmd.id % initiator->get_socket_size());
        bts_queue[cmd.id].push_back(initiator->nb_write(cmd.addr,w_data_queue,w_strb_queue));

        w_data_queue.clear();
        w_strb_queue.clear();

        w_wait_aw       = false;
    }

    if(w_wait_aw) {
        axi_w_ready     = 0;
    } else {
        axi_w_ready     = (rand()%100) < w_pct;
    }
    
    typename std::map<uint32_t,std::deque<transaction> >::iterator it = bts_queue.begin();
    for(; it != bts_queue.end(); it++) {
        if(!it->second.empty() && it->second.front()->nb_done()) {
            transaction ts = it->second.front(); it->second.pop_front();
            uint32_t resp;
            switch(ts->b_status()) {
                case tlm::TLM_OK_RESPONSE:              resp = dlsc::AXI_RESP_OKAY; break;
                case tlm::TLM_ADDRESS_ERROR_RESPONSE:   resp = dlsc::AXI_RESP_DECERR; break;
                default:                                resp = dlsc::AXI_RESP_SLVERR;
            }
            b_queue[it->first].push_back(resp);
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::b_method() {
    if(!axi_b_valid || axi_b_ready) {
        if(!b_queue.empty() && (rand()%100) < b_pct) {
            // select a random ID
            typename std::map<uint32_t,std::deque<uint32_t> >::iterator it = b_queue.begin();
            std::advance(it,(rand()%b_queue.size()));
            assert(!it->second.empty());

            axi_b_id        = it->first;
            axi_b_resp      = it->second.front();
            axi_b_valid     = 1;
                
            it->second.pop_front();
            if(it->second.empty()) {
                // no more for this ID (for now)
                b_queue.erase(it);
            }
        } else {
            axi_b_id        = 0;
            axi_b_resp      = 0;
            axi_b_valid     = 0;
        }
    }
}

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
struct dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::aw_command {
    uint32_t                    id;
    uint64_t                    addr;
    unsigned int                len;
};

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
struct dlsc_axi4lb_tlm_slave_template<DATATYPE,ADDRTYPE>::r_type {
    std::deque<DATATYPE>        data;
    uint32_t                    resp;
};

#endif

