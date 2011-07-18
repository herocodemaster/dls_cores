//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_apb_tlm_slave_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_in<uint32_t>    apb_addr;
    sc_core::sc_in<bool>        apb_sel;
    sc_core::sc_in<bool>        apb_enable;
    sc_core::sc_in<bool>        apb_write;
    sc_core::sc_in<uint32_t>    apb_wdata;
    sc_core::sc_in<uint32_t>    apb_strb;
    sc_core::sc_out<bool>       apb_ready;
    sc_core::sc_out<uint32_t>   apb_rdata;
    sc_core::sc_out<bool>       apb_slverr;

    dlsc_tlm_initiator_nb<uint32_t>::socket_type socket;
    
    /*AUTOMETHODS*/

private:
    dlsc_apb_tlm_slave_template<uint32_t,uint32_t> *slave;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    slave = new dlsc_apb_tlm_slave_template<uint32_t,uint32_t>("slave");

    slave->clk.bind(clk);
    slave->rst.bind(rst);
    
    slave->apb_addr.bind(apb_addr);
    slave->apb_sel.bind(apb_sel);
    slave->apb_enable.bind(apb_enable);
    slave->apb_write.bind(apb_write);
    slave->apb_wdata.bind(apb_wdata);
    slave->apb_strb.bind(apb_strb);
    slave->apb_ready.bind(apb_ready);
    slave->apb_rdata.bind(apb_rdata);
    slave->apb_slverr.bind(apb_slverr);

    slave->socket.bind(socket);
}

/*AUTOTRACE(__MODULE__)*/

