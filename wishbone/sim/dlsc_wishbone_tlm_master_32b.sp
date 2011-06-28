//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_wishbone_tlm_master_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<bool>       wb_cyc_o;

    sc_core::sc_out<bool>       wb_stb_o;
    sc_core::sc_out<bool>       wb_we_o;
    sc_core::sc_out<uint32_t>   wb_adr_o;
    sc_core::sc_out<uint32_t>   wb_cti_o;

    sc_core::sc_out<uint32_t>   wb_dat_o;
    sc_core::sc_out<uint32_t>   wb_sel_o;

    sc_core::sc_in<bool>        wb_stall_i;
    sc_core::sc_in<bool>        wb_ack_i;
    sc_core::sc_in<bool>        wb_err_i;
    sc_core::sc_in<uint32_t>    wb_dat_i;

    tlm::tlm_target_socket<32>  socket;
    
    void set_pipelined(const bool p) { master->set_pipelined(p); }
    
    /*AUTOMETHODS*/

private:
    dlsc_wishbone_tlm_master_template<uint32_t,uint32_t> *master;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    master = new dlsc_wishbone_tlm_master_template<uint32_t,uint32_t>("master");

    master->clk.bind(clk);
    master->rst.bind(rst);
    
    master->wb_cyc_o.bind(wb_cyc_o);

    master->wb_stb_o.bind(wb_stb_o);
    master->wb_we_o.bind(wb_we_o);
    master->wb_adr_o.bind(wb_adr_o);
    master->wb_cti_o.bind(wb_cti_o);

    master->wb_dat_o.bind(wb_dat_o);
    master->wb_sel_o.bind(wb_sel_o);

    master->wb_stall_i.bind(wb_stall_i);
    master->wb_ack_i.bind(wb_ack_i);
    master->wb_err_i.bind(wb_err_i);
    master->wb_dat_i.bind(wb_dat_i);

    socket.bind(master->socket);
}

/*AUTOTRACE(__MODULE__)*/

