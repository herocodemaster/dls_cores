//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_apb_tlm_master_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<uint32_t>   apb_addr;
    sc_core::sc_out<bool>       apb_sel;
    sc_core::sc_out<bool>       apb_enable;
    sc_core::sc_out<bool>       apb_write;
    sc_core::sc_out<uint32_t>   apb_wdata;
    sc_core::sc_out<uint32_t>   apb_strb;
    sc_core::sc_in<bool>        apb_ready;
    sc_core::sc_in<uint32_t>    apb_rdata;
    sc_core::sc_in<bool>        apb_slverr;

    tlm::tlm_target_socket<32>  socket;
    
    /*AUTOMETHODS*/

private:
    dlsc_apb_tlm_master_template<uint32_t,uint32_t> *master;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    master = new dlsc_apb_tlm_master_template<uint32_t,uint32_t>("master");

    master->clk.bind(clk);
    master->rst.bind(rst);
    
    master->apb_addr.bind(apb_addr);
    master->apb_sel.bind(apb_sel);
    master->apb_enable.bind(apb_enable);
    master->apb_write.bind(apb_write);
    master->apb_wdata.bind(apb_wdata);
    master->apb_strb.bind(apb_strb);
    master->apb_ready.bind(apb_ready);
    master->apb_rdata.bind(apb_rdata);
    master->apb_slverr.bind(apb_slverr);

    socket.bind(master->socket);
}

/*AUTOTRACE(__MODULE__)*/

