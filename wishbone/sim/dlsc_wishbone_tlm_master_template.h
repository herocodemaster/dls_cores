
#ifndef DLSC_WISHBONE_TLM_MASTER_TEMPLATE_INCLUDED
#define DLSC_WISHBONE_TLM_MASTER_TEMPLATE_INCLUDED

#include <systemc>
#include <tlm.h>

#include <deque>

#include "dlsc_tlm_target_nb.h"
#include "dlsc_wishbone_types.h"
#include "dlsc_common.h"

template <typename DATATYPE = uint32_t, typename ADDRTYPE = uint32_t>
class dlsc_wishbone_tlm_master_template : public sc_core::sc_module {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<bool>       wb_cyc_o;

    sc_core::sc_out<bool>       wb_stb_o;
    sc_core::sc_out<bool>       wb_we_o;
    sc_core::sc_out<ADDRTYPE>   wb_adr_o;
    sc_core::sc_out<uint32_t>   wb_cti_o;

    sc_core::sc_out<DATATYPE>   wb_dat_o;
    sc_core::sc_out<uint32_t>   wb_sel_o;

    sc_core::sc_in<bool>        wb_stall_i;
    sc_core::sc_in<bool>        wb_ack_i;
    sc_core::sc_in<bool>        wb_err_i;
    sc_core::sc_in<DATATYPE>    wb_dat_i;
    
    typedef typename dlsc_tlm_target_nb<dlsc_wishbone_tlm_master_template,DATATYPE>::socket_type socket_type;

    socket_type socket;
    
    dlsc_tlm_target_nb<dlsc_wishbone_tlm_master_template,DATATYPE> *target;

    dlsc_wishbone_tlm_master_template(const sc_core::sc_module_name &nm);
    
    typedef typename dlsc_tlm_target_nb<dlsc_wishbone_tlm_master_template,DATATYPE>::transaction transaction;
    
    virtual void target_callback(transaction ts);
    
    SC_HAS_PROCESS(dlsc_wishbone_tlm_master_template);

    void set_pipelined(const bool p) { pipelined = p; }

private:
    struct cmd_data;
    
    // configuration
    bool                        pipelined;
    bool                        registered;
    int                         cmd_pct;

    std::deque<cmd_data>        cmd_data_queue;

    std::deque<transaction>     resp_ts_queue;
    std::deque<DATATYPE>        resp_data_queue;

    void clk_method();
    void rst_method();
    void cmd_method();
    void resp_method();
    void cyc_method();
};

template <typename DATATYPE, typename ADDRTYPE>
dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::dlsc_wishbone_tlm_master_template(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm),
    clk("clk"),
    rst("rst"),
    wb_cyc_o("wb_cyc_o"),
    wb_stb_o("wb_stb_o"),
    wb_we_o("wb_we_o"),
    wb_adr_o("wb_adr_o"),
    wb_cti_o("wb_cti_o"),
    wb_dat_o("wb_dat_o"),
    wb_sel_o("wb_sel_o"),
    wb_stall_i("wb_stall_i"),
    wb_ack_i("wb_ack_i"),
    wb_err_i("wb_err_i"),
    wb_dat_i("wb_dat_i"),
    socket("socket")
{
    target = new dlsc_tlm_target_nb<dlsc_wishbone_tlm_master_template,DATATYPE>(
        "target", this, &dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback);
    socket.bind(target->socket);

    pipelined       = false;
    registered      = true;

    cmd_pct         = 95;

    SC_METHOD(clk_method);
        sensitive << clk.pos();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::target_callback(transaction ts) {
    // default to OK; will be set to something else on error
    ts->set_response_status(tlm::TLM_OK_RESPONSE);

    cmd_data cmd;
    
    cmd.we_o        = ts->is_write();
    cmd.adr_o       = ts->get_address();
    cmd.cti_o       = dlsc::WB_CTI_INCR;

    std::deque<DATATYPE> data;
    std::deque<uint32_t> strb;

    ts->get_strobes(strb);

    if(ts->is_write()) {
        ts->get_data(data);
    } else {
        data.resize(ts->size());
        std::fill(data.begin(),data.end(),0);
    }

    assert(ts->size() == data.size());
    assert(ts->size() == strb.size());

    while(!data.empty()) {
        cmd.dat_o       = data.front(); data.pop_front();
        cmd.sel_o       = strb.front(); strb.pop_front();
        if(data.empty()) {
            cmd.cti_o       = dlsc::WB_CTI_END;
        }
        cmd_data_queue.push_back(cmd);
        cmd.adr_o       += sizeof(DATATYPE);
    }

    resp_ts_queue.push_back(ts);
}
    
template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::clk_method() {
    if(rst) {
        rst_method();
    } else {
        cmd_method();
        resp_method();
        cyc_method();
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::rst_method() {
    wb_cyc_o        = 0;
    wb_stb_o        = 0;
    wb_we_o         = 0;
    wb_adr_o        = 0;
    wb_cti_o        = 0;
    wb_dat_o        = 0;
    wb_sel_o        = 0;
    
    while(!resp_ts_queue.empty()) {
        transaction ts = resp_ts_queue.front(); resp_ts_queue.pop_front();
        dlsc_verb("lost transaction to reset");
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
    }

    cmd_data_queue.clear();
    resp_ts_queue.clear();
    resp_data_queue.clear();
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::cmd_method() {

    if(!wb_stb_o || (pipelined ? !wb_stall_i : wb_ack_i) ) {        
        if( !cmd_data_queue.empty() && (rand()%100) < cmd_pct ) {
            // drive new command
            cmd_data cmd = cmd_data_queue.front(); cmd_data_queue.pop_front();

            wb_stb_o        = 1;
            wb_we_o         = cmd.we_o;
            wb_adr_o        = cmd.adr_o;
            wb_cti_o        = cmd.cti_o;
            wb_dat_o        = cmd.dat_o;
            wb_sel_o        = cmd.sel_o;

        } else {

            wb_stb_o        = 0;
            wb_we_o         = 0;
            wb_adr_o        = 0;
            wb_cti_o        = 0;
            wb_dat_o        = 0;
            wb_sel_o        = 0;

        }
    }

}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::resp_method() {

    if(wb_cyc_o && wb_ack_i && (pipelined || wb_stb_o)) {
        if(resp_ts_queue.empty()) {
            dlsc_error("unexpected response");
        } else {
            transaction ts = resp_ts_queue.front();

            if(wb_err_i) {
                ts->set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
            }

            resp_data_queue.push_back(wb_dat_i);

            if(resp_data_queue.size() == ts->size()) {
                if(ts->is_read()) {
                    ts->set_data(resp_data_queue);
                }

                ts->complete();
                resp_ts_queue.pop_front();

                resp_data_queue.clear();
            }
        }
    }
}

template <typename DATATYPE, typename ADDRTYPE>
void dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::cyc_method() {
    wb_cyc_o        = !resp_ts_queue.empty();
}

template <typename DATATYPE, typename ADDRTYPE>
struct dlsc_wishbone_tlm_master_template<DATATYPE,ADDRTYPE>::cmd_data {
    bool                        we_o;
    ADDRTYPE                    adr_o;
    uint32_t                    cti_o;
    DATATYPE                    dat_o;
    uint32_t                    sel_o;
};

#endif

