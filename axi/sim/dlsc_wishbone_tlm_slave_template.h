
#ifndef DLSC_WISHBONE_TLM_SLAVE_TEMPLATE_INCLUDED
#define DLSC_WISHBONE_TLM_SLAVE_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_wishbone_types.h"
#include "dlsc_common.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_wishbone_tlm_slave_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<bool>        wb_cyc_i;

    sc_core::sc_in<bool>        wb_stb_i;
    sc_core::sc_in<bool>        wb_we_i;
    sc_core::sc_in<ADDRTYPE>    wb_adr_i;
    sc_core::sc_in<uint32_t>    wb_cti_i;

    sc_core::sc_in<DATATYPE>    wb_dat_i;
    sc_core::sc_in<uint32_t>    wb_sel_i;

    sc_core::sc_out<bool>       wb_stall_o;
    sc_core::sc_out<bool>       wb_ack_o;
    sc_core::sc_out<bool>       wb_err_o;
    sc_core::sc_out<DATATYPE>   wb_dat_o;
    
    typename dlsc_tlm_initiator_nb<DATATYPE>::socket_type socket;

    dlsc_tlm_initiator_nb<DATATYPE> *initiator;

    dlsc_wishbone_tlm_slave_template(const sc_core::sc_module_name &nm, const bool wb_pipelined = true);

    SC_HAS_PROCESS(dlsc_wishbone_tlm_slave_template);

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    const bool                  pipelined;

    std::deque<transaction>     resp_queue;

    int                         cmd_ack;

    int                         max_outstanding;
    int                         outstanding;

    void clk_method();
    void rst_method();
    void cmd_method();
    void resp_method();
    void stall_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::dlsc_wishbone_tlm_slave_template(
    const sc_core::sc_module_name &nm,
    const bool wb_pipelined
) :
    sc_module(nm),
    clk("clk"),
    rst("rst"),
    wb_cyc_i("wb_cyc_i"),
    wb_stb_i("wb_stb_i"),
    wb_we_i("wb_we_i"),
    wb_adr_i("wb_adr_i"),
    wb_cti_i("wb_cti_i"),
    wb_dat_i("wb_dat_i"),
    wb_sel_i("wb_sel_i"),
    wb_stall_o("wb_stall_o"),
    wb_ack_o("wb_ack_o"),
    wb_err_o("wb_err_o"),
    wb_dat_o("wb_dat_o"),
    socket("socket"),
    pipelined(wb_pipelined)
{
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator");
        initiator->socket.bind(socket);
    
    max_outstanding = 4;

    cmd_ack         = 0;

    outstanding     = 0;

    SC_METHOD(clk_method);
        sensitive << clk.pos();
}
    
template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        rst_method();
    } else {
        cmd_method();
        resp_method();
        stall_method();
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::rst_method() {
    wb_stall_o      = 0;
    wb_ack_o        = 0;
    wb_err_o        = 0;
    wb_dat_o        = 0;

    cmd_ack         = 0;

    outstanding     = 0;
    
    resp_queue.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::cmd_method() {

    if(wb_cyc_i && wb_stb_i && !wb_stall_o) {

        if(wb_we_i && !cmd_ack) {
            // got new write command
            ++cmd_ack;
            ++outstanding;
            std::deque<DATATYPE> data;
            data.push_back(wb_dat_i);
            std::deque<DATATYPE> strb;
            strb.push_back(wb_sel_i);
            resp_queue.push_back(initiator->nb_write(wb_adr_i,data,strb));
        }
        
        if(!wb_we_i && !cmd_ack) {
            // got new read command
            ++cmd_ack;
            ++outstanding;
            resp_queue.push_back(initiator->nb_read(wb_adr_i,1));
        }

//        if(!wb_we_i && wb_cti_i == dlsc::WB_CTI_INCR && cmd_ack <= 1) {
//            // got next read command
//            ++cmd_ack;
//            ++outstanding;
//            resp_queue.push_back(initiator->nb_read(wb_adr_i+(sizeof(DATATYPE)/8),1));
//        }

    }

    if(wb_cyc_i && wb_stb_i && ( pipelined ? !wb_stall_o : wb_ack_o )) {
        // acknowledged command
        --cmd_ack;
    }

    if(!wb_cyc_i && cmd_ack) {
        dlsc_error("cycle terminated before command acknowledged");
    }

}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::resp_method() {

    if(!wb_cyc_i && !resp_queue.empty()) {
        dlsc_error("cycle terminated with outstanding transactions");
    }

    if(pipelined || wb_stb_i) {
        if(!resp_queue.empty() && resp_queue.front()->nb_done()) {
            transaction ts = resp_queue.front(); resp_queue.pop_front();

            wb_ack_o        = 1;
            wb_err_o        = (ts->b_status() == tlm::TLM_OK_RESPONSE) ? 0 : 1;

            std::deque<DATATYPE> data;

            if(ts->is_read() && ts->b_read(data)) {
                assert(data.size() == 1);
                wb_dat_o        = data.front();
            } else {
                wb_dat_o        = 0;
            }

            --outstanding;

        } else {

            wb_ack_o        = 0;
            wb_err_o        = 0;
            wb_dat_o        = 0;

        }
    }

}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::stall_method() {

    wb_stall_o      = (outstanding >= max_outstanding) ? 1 : 0;

}

#endif

