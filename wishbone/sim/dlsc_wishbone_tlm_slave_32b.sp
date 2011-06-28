//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_wishbone_tlm_slave_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<bool>        wb_cyc_i;

    sc_core::sc_in<bool>        wb_stb_i;
    sc_core::sc_in<bool>        wb_we_i;
    sc_core::sc_in<uint32_t>    wb_adr_i;
    sc_core::sc_in<uint32_t>    wb_cti_i;

    sc_core::sc_in<uint32_t>    wb_dat_i;
    sc_core::sc_in<uint32_t>    wb_sel_i;

    sc_core::sc_out<bool>       wb_stall_o;
    sc_core::sc_out<bool>       wb_ack_o;
    sc_core::sc_out<bool>       wb_err_o;
    sc_core::sc_out<uint32_t>   wb_dat_o;

    dlsc_tlm_initiator_nb<uint32_t>::socket_type socket;
    
    void set_pipelined(const bool p) { slave->set_pipelined(p); }
    
    /*AUTOMETHODS*/

private:
    dlsc_wishbone_tlm_slave_template<uint32_t,uint32_t> *slave;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    slave = new dlsc_wishbone_tlm_slave_template<uint32_t,uint32_t>("slave");

    slave->clk.bind(clk);
    slave->rst.bind(rst);
    
    slave->wb_cyc_i.bind(wb_cyc_i);

    slave->wb_stb_i.bind(wb_stb_i);
    slave->wb_we_i.bind(wb_we_i);
    slave->wb_adr_i.bind(wb_adr_i);
    slave->wb_cti_i.bind(wb_cti_i);

    slave->wb_dat_i.bind(wb_dat_i);
    slave->wb_sel_i.bind(wb_sel_i);

    slave->wb_stall_o.bind(wb_stall_o);
    slave->wb_ack_o.bind(wb_ack_o);
    slave->wb_err_o.bind(wb_err_o);
    slave->wb_dat_o.bind(wb_dat_o);

    slave->socket.bind(socket);
}

/*AUTOTRACE(__MODULE__)*/

