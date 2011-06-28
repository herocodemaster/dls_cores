
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

    dlsc_wishbone_tlm_slave_template(const sc_core::sc_module_name &nm);

    SC_HAS_PROCESS(dlsc_wishbone_tlm_slave_template);

    void set_pipelined(const bool p) { pipelined = p; }

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    // configuration
    bool                        pipelined;
    bool                        registered;
    int                         max_length;
    int                         max_outstanding;
    int                         cmd_pct;
    int                         resp_pct;

    std::deque<transaction>     resp_queue;
    std::deque<DATATYPE>        data_queue;

    bool                        cmd_ack;
    bool                        cmd_first;

    int                         outstanding;

    // accumulate pipelined commands
    bool                        pipe_we;
    ADDRTYPE                    pipe_addr;
    std::deque<DATATYPE>        pipe_data;
    std::deque<uint32_t>        pipe_strb;

    void pipe_submit();

    void clk_method();
    void rst_method();
    void cmd_method();
    void resp_method();
    void stall_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::dlsc_wishbone_tlm_slave_template(
    const sc_core::sc_module_name &nm
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
    socket("socket")
{
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator");
        initiator->socket.bind(socket);

    pipelined       = false;
    registered      = true;
    max_length      = 8;
    max_outstanding = 16;

    cmd_pct         = 95;
    resp_pct        = 95;

    cmd_ack         = false;
    cmd_first       = true;

    outstanding     = 0;

    pipe_we         = false;
    pipe_addr       = 0;

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

    cmd_ack         = false;
    cmd_first       = true;

    outstanding     = 0;

    pipe_we         = false;
    pipe_addr       = 0;
    pipe_data.clear();
    pipe_strb.clear();

    resp_queue.clear();
    data_queue.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::pipe_submit() {
    if(pipe_we) {
        resp_queue.push_back(initiator->nb_write(pipe_addr,pipe_data,pipe_strb));
    } else {
        resp_queue.push_back(initiator->nb_read(pipe_addr,pipe_data.size()));
    }
    pipe_we         = false;
    pipe_addr       = 0;
    pipe_data.clear();
    pipe_strb.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::cmd_method() {

    // ** Pipelined **
    if(pipelined) {
    
        if(wb_cyc_i && wb_stb_i && !wb_stall_o && !cmd_ack) {
            // new command
            
            if(!pipe_data.empty() && (
                pipe_we != wb_we_i ||
                (pipe_addr + sizeof(DATATYPE)*pipe_data.size()) != wb_adr_i)
            ) {
                // new command is incompatible; submit old one
                pipe_submit();
            }

            if(pipe_data.empty()) {
                pipe_we     = wb_we_i;
                pipe_addr   = wb_adr_i;
            }

            pipe_data.push_back(wb_we_i ? wb_dat_i : 0);
            pipe_strb.push_back(wb_sel_i);

            if(pipe_data.size() >= (unsigned int)max_length) {
                // command at maximum length; submit
                pipe_submit();
            }

        } else {
            // no new command
            if(!pipe_data.empty()) {
                // submit pending
                pipe_submit();
            }
        }

    }

    // ** Not Pipelined **
    if(!pipelined && wb_cyc_i && wb_stb_i && !cmd_ack) {
        if(wb_we_i) {
            // got new write command
            std::deque<DATATYPE> data;
            data.push_back(wb_dat_i);
            std::deque<uint32_t> strb;
            strb.push_back(wb_sel_i);
            resp_queue.push_back(initiator->nb_write(wb_adr_i,data,strb));
        } else {
            // got new read command
            if(cmd_first) {
                // first, so we must submit command for this cycle
                cmd_first   = false;
                resp_queue.push_back(initiator->nb_read(wb_adr_i,1));
            }
            if(registered && wb_cti_i == dlsc::WB_CTI_INCR) {
                // INCR; submit command for next cycle
                resp_queue.push_back(initiator->nb_read(wb_adr_i+sizeof(DATATYPE),1));
            } else {
                // not INCR, so must be last (next will be first)
                cmd_first   = true;
            }
        }
    }

    // ** Common **
    if(wb_cyc_i && wb_stb_i && (!pipelined || !wb_stall_o) && !cmd_ack) {
        cmd_ack     = true;
        ++outstanding;
    }

    if(wb_cyc_i && wb_stb_i && ( pipelined ? !wb_stall_o : wb_ack_o )) {
        cmd_ack     = false;
    }

    if(!wb_cyc_i && cmd_ack) {
        dlsc_error("cycle terminated before command acknowledged");
    }

}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::resp_method() {

    if( !wb_cyc_i && (!resp_queue.empty() || !data_queue.empty()) ) {
        dlsc_error("cycle terminated with outstanding transactions");
    }

    if(pipelined || wb_stb_i) {
        if(data_queue.empty() && !resp_queue.empty() && resp_queue.front()->nb_done()) {
            transaction ts = resp_queue.front(); resp_queue.pop_front();
            
            wb_err_o        = (ts->b_status() == tlm::TLM_OK_RESPONSE) ? 0 : 1;

            if(!ts->b_read(data_queue) || ts->is_write()) {
                std::fill(data_queue.begin(),data_queue.end(),0);
            }
        }

        if(!data_queue.empty()) {

            if( (rand()%100) <= resp_pct ) {
                wb_ack_o        = 1;
                wb_dat_o        = data_queue.front(); data_queue.pop_front();
                --outstanding;
            } else {
                wb_ack_o        = 0;
            }

        } else {

            wb_ack_o        = 0;
            wb_err_o        = 0;
            wb_dat_o        = 0;

        }
    }

}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_slave_template<DATATYPE,ADDRTYPE>::stall_method() {
    
    if(!pipelined) {
        wb_stall_o      = 0;
        return;
    }

    wb_stall_o      = ( outstanding >= max_outstanding || (rand()%100) > cmd_pct ) ? 1 : 0;

}

#endif

