
#ifndef DLSC_CSR_TLM_SLAVE_TEMPLATE_INCLUDED
#define DLSC_CSR_TLM_SLAVE_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_common.h"
#include "dlsc_util.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_csr_tlm_slave_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<bool>        csr_cmd_valid;
    sc_core::sc_in<bool>        csr_cmd_write;
    sc_core::sc_in<ADDRTYPE>    csr_cmd_addr;
    sc_core::sc_in<DATATYPE>    csr_cmd_data;
    sc_core::sc_out<bool>       csr_rsp_valid;
    sc_core::sc_out<bool>       csr_rsp_error;
    sc_core::sc_out<DATATYPE>   csr_rsp_data;
    
    typename dlsc_tlm_initiator_nb<DATATYPE>::socket_type socket;

    dlsc_tlm_initiator_nb<DATATYPE> *initiator;

    dlsc_csr_tlm_slave_template(const sc_core::sc_module_name &nm);

    SC_HAS_PROCESS(dlsc_csr_tlm_slave_template);

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    // configuration
    int                         valid_pct;

    transaction                 ts;

    void clk_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_csr_tlm_slave_template<DATATYPE,ADDRTYPE>::dlsc_csr_tlm_slave_template(
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
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator",1);
        initiator->socket.bind(socket);

    valid_pct   = 70;
    ts.reset();

    SC_METHOD(clk_method);
        sensitive << clk.pos();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_csr_tlm_slave_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        csr_rsp_valid   = 0;
        csr_rsp_error   = 0;
        csr_rsp_data    = 0;
        ts.reset();
    } else {

        // response is only valid for a single cycle
        csr_rsp_valid   = 0;
        csr_rsp_error   = 0;
        csr_rsp_data    = 0;

        // check for command
        if(csr_cmd_valid) {
            if(ts) {
                dlsc_error("additional transaction attempted before completion of 1st transaction (dropped)");
            } else {
                if(csr_cmd_write) {
                    std::deque<DATATYPE> data; data.push_back(csr_cmd_data);
                    ts = initiator->nb_write(csr_cmd_addr,data);
                } else {
                    ts = initiator->nb_read(csr_cmd_addr,1);
                }
            }
        }

        // generate response
        if(ts && ts->nb_done() && dlsc_rand_bool(valid_pct)) {
            csr_rsp_valid   = 1;
            csr_rsp_error   = (ts->b_status() != tlm::TLM_OK_RESPONSE);
            if(ts->is_read()) {
                DATATYPE data;
                ts->b_read(data);
                csr_rsp_data    = data;
            }
            ts.reset();
        }

    }
}

#endif

