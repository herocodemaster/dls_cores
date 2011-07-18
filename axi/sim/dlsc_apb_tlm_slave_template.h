
#ifndef DLSC_APB_TLM_SLAVE_TEMPLATE_INCLUDED
#define DLSC_APB_TLM_SLAVE_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_common.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_apb_tlm_slave_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<ADDRTYPE>    apb_addr;
    sc_core::sc_in<bool>        apb_sel;
    sc_core::sc_in<bool>        apb_enable;
    sc_core::sc_in<bool>        apb_write;
    sc_core::sc_in<DATATYPE>    apb_wdata;
    sc_core::sc_in<uint32_t>    apb_strb;
    sc_core::sc_out<bool>       apb_ready;
    sc_core::sc_out<DATATYPE>   apb_rdata;
    sc_core::sc_out<bool>       apb_slverr;
    
    typename dlsc_tlm_initiator_nb<DATATYPE>::socket_type socket;

    dlsc_tlm_initiator_nb<DATATYPE> *initiator;

    dlsc_apb_tlm_slave_template(const sc_core::sc_module_name &nm);

    SC_HAS_PROCESS(dlsc_apb_tlm_slave_template);

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    // configuration
    int                         ready_pct;

    transaction                 ts;

    void clk_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_apb_tlm_slave_template<DATATYPE,ADDRTYPE>::dlsc_apb_tlm_slave_template(
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
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator",1);
        initiator->socket.bind(socket);

    ready_pct   = 95;
    ts.reset();

    SC_METHOD(clk_method);
        sensitive << clk.pos();
}
    
template <typename DATATYPE, typename ADDRTYPE>
void dlsc_apb_tlm_slave_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        apb_ready   = 0;
        apb_rdata   = 0;
        apb_ready   = 0;
        ts.reset();
    } else {

        if(apb_ready) {
            apb_ready   = 0;
            apb_rdata   = 0;
            apb_slverr  = 0;
        }

        if(apb_sel) {
            if(!apb_enable) {
                if(ts) {
                    dlsc_error("should only have 1 cycle between assertion of sel and enable");
                } else {
                    if(apb_write) {
                        std::deque<DATATYPE> data; data.push_back(apb_wdata);
                        std::deque<uint32_t> strb; strb.push_back(apb_strb);
                        ts = initiator->nb_write(apb_addr,data,strb);
                    } else {
                        ts = initiator->nb_read(apb_addr,1);
                    }
                }
            } else if(!apb_ready && !ts) {
                dlsc_error("must have 1 cycle between asertion of sel and enable");
            }

            if(ts && ts->nb_done() && (rand()%100) < ready_pct) {
                apb_ready   = 1;
                apb_slverr  = (ts->b_status() != tlm::TLM_OK_RESPONSE);
                if(ts->is_read()) {
                    DATATYPE data;
                    ts->b_read(data);
                    apb_rdata = data;
                }
                ts.reset();
            }
        }
        
        if(apb_sel && !apb_write && apb_strb != 0) {
            dlsc_error("strb must be 0 on read");
        }

        if(!apb_sel && ts) {
            dlsc_error("sel deasserted before transaction completed");
            ts.reset();
        }
    }
}

#endif

