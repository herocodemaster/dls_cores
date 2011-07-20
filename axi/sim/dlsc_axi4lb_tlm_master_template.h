
#ifndef DLSC_AXI4LB_TLM_MASTER_TEMPLATE_INCLUDED
#define DLSC_AXI4LB_TLM_MASTER_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>
#include <map>

#include "dlsc_tlm_target_nb.h"
#include "dlsc_axi_types.h"
#include "dlsc_common.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_axi4lb_tlm_master_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<bool>        axi_ar_ready;
    sc_core::sc_out<bool>       axi_ar_valid;
    sc_core::sc_out<uint32_t>   axi_ar_id;
    sc_core::sc_out<ADDRTYPE>   axi_ar_addr;
    sc_core::sc_out<uint32_t>   axi_ar_len;
    
    sc_core::sc_out<bool>       axi_r_ready;
    sc_core::sc_in<bool>        axi_r_valid;
    sc_core::sc_in<bool>        axi_r_last;
    sc_core::sc_in<uint32_t>    axi_r_id;
    sc_core::sc_in<DATATYPE>    axi_r_data;
    sc_core::sc_in<uint32_t>    axi_r_resp;

    sc_core::sc_in<bool>        axi_aw_ready;
    sc_core::sc_out<bool>       axi_aw_valid;
    sc_core::sc_out<uint32_t>   axi_aw_id;
    sc_core::sc_out<ADDRTYPE>   axi_aw_addr;
    sc_core::sc_out<uint32_t>   axi_aw_len;
    
    sc_core::sc_in<bool>        axi_w_ready;
    sc_core::sc_out<bool>       axi_w_valid;
    sc_core::sc_out<bool>       axi_w_last;
    sc_core::sc_out<uint32_t>   axi_w_id;
    sc_core::sc_out<DATATYPE>   axi_w_data;
    sc_core::sc_out<uint32_t>   axi_w_strb;
    
    sc_core::sc_out<bool>       axi_b_ready;
    sc_core::sc_in<bool>        axi_b_valid;
    sc_core::sc_in<uint32_t>    axi_b_id;
    sc_core::sc_in<uint32_t>    axi_b_resp;

    typedef typename dlsc_tlm_target_nb<dlsc_axi4lb_tlm_master_template,DATATYPE>::socket_type socket_type;

    socket_type socket;
    
    dlsc_tlm_target_nb<dlsc_axi4lb_tlm_master_template,DATATYPE> *target;

    dlsc_axi4lb_tlm_master_template(const sc_core::sc_module_name &nm);
    
    typedef typename dlsc_tlm_target_nb<dlsc_axi4lb_tlm_master_template,DATATYPE>::transaction transaction;
    
    virtual void target_callback(transaction ts);
    
    SC_HAS_PROCESS(dlsc_axi4lb_tlm_master_template);

private:
    // config
    int                         ar_pct;
    int                         r_pct;
    int                         aw_pct;
    int                         w_pct;
    int                         b_pct;

    std::deque<transaction>                     ar_queue;
    std::map<uint32_t,std::deque<transaction> > r_queue;
    std::map<uint32_t,std::deque<DATATYPE> >    r_data_queue;
    std::deque<transaction>                     aw_queue;
    std::deque<transaction>                     w_queue;
    std::deque<DATATYPE>                        w_data_queue;
    std::deque<uint32_t>                        w_strb_queue;
    std::map<uint32_t,std::deque<transaction> > b_queue;

    void reset_queue(std::deque<transaction> &queue);
    void reset_map(std::map<uint32_t,std::deque<transaction> > &map);
    
    void clk_method();
    void rst_method();
    void ar_method();
    void r_method();
    void aw_method();
    void w_method();
    void b_method();
};



template <typename DATATYPE, typename ADDRTYPE>
dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::dlsc_axi4lb_tlm_master_template(
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
    axi_w_id("axi_w_id"),
    axi_w_data("axi_w_data"),
    axi_w_strb("axi_w_strb"),
    axi_b_ready("axi_b_ready"),
    axi_b_valid("axi_b_valid"),
    axi_b_id("axi_b_id"),
    axi_b_resp("axi_b_resp"),
    socket("socket")
{
    target = new dlsc_tlm_target_nb<dlsc_axi4lb_tlm_master_template,DATATYPE>(
        "target", this, &dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback, 256);
    socket.bind(target->socket);

    ar_pct      = 95;
    r_pct       = 95;
    aw_pct      = 95;
    w_pct       = 95;
    b_pct       = 95;

    SC_METHOD(clk_method);
        sensitive << clk.pos();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback(transaction ts) {
    // default to OK; will be set to something else on error
    ts->set_response_status(tlm::TLM_OK_RESPONSE);

    if(ts->is_write()) {
        aw_queue.push_back(ts);
    } else {
        ar_queue.push_back(ts);
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::clk_method() {
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
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::reset_queue(
    std::deque<transaction> &queue)
{
    while(!queue.empty()) {
        transaction ts = queue.front(); queue.pop_front();
        dlsc_verb("lost transaction to reset");
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::reset_map(
    std::map<uint32_t,std::deque<transaction> > &map)
{
    typename std::map<uint32_t,std::deque<transaction> >::iterator it = map.begin();
    for(;it!=map.end();it++) {
        reset_queue(it->second);
    }
    map.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::rst_method() {
    axi_ar_valid    = 0;
    axi_ar_id       = 0;
    axi_ar_addr     = 0;
    axi_ar_len      = 0;
    axi_r_ready     = 0;
    axi_aw_valid    = 0;
    axi_aw_id       = 0;
    axi_aw_addr     = 0;
    axi_aw_len      = 0;
    axi_w_valid     = 0;
    axi_w_last      = 0;
    axi_w_id        = 0;
    axi_w_data      = 0;
    axi_w_strb      = 0;
    axi_b_ready     = 0;

    reset_queue(ar_queue);
    reset_map  (r_queue);
    reset_queue(aw_queue);
    reset_queue(w_queue);
    reset_map  (b_queue);
    
    r_data_queue.clear();
    w_data_queue.clear();
    w_strb_queue.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::ar_method() {
    if(!axi_ar_valid || axi_ar_ready) {
        if(!ar_queue.empty() && (rand()%100) < ar_pct) {
            transaction ts  = ar_queue.front(); ar_queue.pop_front();
            axi_ar_id       = ts->get_socket_id();
            axi_ar_addr     = ts->get_address();
            axi_ar_len      = ts->size() - 1;
            axi_ar_valid    = 1;
            r_queue[ts->get_socket_id()].push_back(ts);

        } else {
            axi_ar_id       = 0;
            axi_ar_addr     = 0;
            axi_ar_len      = 0;
            axi_ar_valid    = 0;
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::r_method() {
    if(axi_r_valid && axi_r_ready) {
        uint32_t id = axi_r_id.read();
        if(r_queue[id].empty()) {
            dlsc_error("unexpected R data (ID: " << std::dec << id << ")");
        } else {
            transaction ts = r_queue[id].front();
            r_data_queue[id].push_back(axi_r_data);
            if(axi_r_resp != dlsc::AXI_RESP_OKAY) {
                switch(axi_r_resp) {
                    case dlsc::AXI_RESP_SLVERR: ts->set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE); break;
                    case dlsc::AXI_RESP_DECERR: ts->set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE); break;
                    default:                    ts->set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
                }
            }
            if(axi_r_last || r_data_queue[id].size() >= ts->size()) {
                if(!axi_r_last || r_data_queue[id].size() != ts->size()) {
                    dlsc_error("AR/R length mismatch (expecting " << std::dec << ts->size() << " but got " << r_data_queue[id].size() << ")");
                    r_data_queue[id].resize(ts->size());
                }
                ts->set_data(r_data_queue[id]);
                ts->complete();
                r_queue[id].pop_front();
                r_data_queue[id].clear();
            }
        }
    }

    axi_r_ready     = (rand()%100) < r_pct;
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::aw_method() {
    if(!axi_aw_valid || axi_aw_ready) {
        if(!aw_queue.empty() && (rand()%100) < aw_pct) {
            transaction ts  = aw_queue.front(); aw_queue.pop_front();
            axi_aw_id       = ts->get_socket_id();
            axi_aw_addr     = ts->get_address();
            axi_aw_len      = ts->size() - 1;
            axi_aw_valid    = 1;
            w_queue.push_back(ts);

        } else {
            axi_aw_addr     = 0;
            axi_aw_len      = 0;
            axi_aw_valid    = 0;
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::w_method() {
    if(!axi_w_valid || axi_w_ready) {
        if(w_data_queue.empty() && !w_queue.empty()) {
            transaction ts  = w_queue.front(); w_queue.pop_front();
            axi_w_id        = ts->get_socket_id();
            ts->get_data(w_data_queue);
            ts->get_strobes(w_strb_queue);
            b_queue[ts->get_socket_id()].push_back(ts);
        }

        if(!w_data_queue.empty() && (rand()%100) < w_pct) {
            axi_w_data      = w_data_queue.front(); w_data_queue.pop_front();
            axi_w_strb      = w_strb_queue.front(); w_strb_queue.pop_front();
            axi_w_last      = w_data_queue.empty();
            axi_w_valid     = 1;
        } else {
//          axi_w_id        = 0;    // can't clear, since it's only set once above
            axi_w_data      = 0;
            axi_w_strb      = 0;
            axi_w_last      = 0;
            axi_w_valid     = 0;
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_axi4lb_tlm_master_template<DATATYPE,ADDRTYPE>::b_method() {
    if(axi_b_valid && axi_b_ready) {
        uint32_t id = axi_b_id.read();
        if(b_queue[id].empty()) {
            dlsc_error("unexpected B data (ID: " << std::dec << id << ")");
        } else {
            transaction ts = b_queue[id].front();
            if(axi_b_resp != dlsc::AXI_RESP_OKAY) {
                switch(axi_b_resp) {
                    case dlsc::AXI_RESP_SLVERR: ts->set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE); break;
                    case dlsc::AXI_RESP_DECERR: ts->set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE); break;
                    default:                    ts->set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
                }
            }
            ts->complete();
            b_queue[id].pop_front();
        }
    }
    
    axi_b_ready     = (rand()%100) < b_pct;
}


#endif

