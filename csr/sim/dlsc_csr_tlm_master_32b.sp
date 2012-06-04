//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_csr_tlm_master_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<bool>       csr_cmd_valid;
    sc_core::sc_out<bool>       csr_cmd_write;
    sc_core::sc_out<uint32_t>   csr_cmd_addr;
    sc_core::sc_out<uint32_t>   csr_cmd_data;
    sc_core::sc_in<bool>        csr_rsp_valid;
    sc_core::sc_in<bool>        csr_rsp_error;
    sc_core::sc_in<uint32_t>    csr_rsp_data;

    typedef dlsc_csr_tlm_master_template<uint32_t,uint32_t>::socket_type socket_type;

    socket_type socket;
    
    /*AUTOMETHODS*/

private:
    dlsc_csr_tlm_master_template<uint32_t,uint32_t> *master;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    master = new dlsc_csr_tlm_master_template<uint32_t,uint32_t>("master");

    master->clk.bind(clk);
    master->rst.bind(rst);
    
    master->csr_cmd_valid.bind(csr_cmd_valid);
    master->csr_cmd_write.bind(csr_cmd_write);
    master->csr_cmd_addr.bind(csr_cmd_addr);
    master->csr_cmd_data.bind(csr_cmd_data);
    master->csr_rsp_valid.bind(csr_rsp_valid);
    master->csr_rsp_error.bind(csr_rsp_error);
    master->csr_rsp_data.bind(csr_rsp_data);

    socket.bind(master->socket);
}

/*AUTOTRACE(__MODULE__)*/

