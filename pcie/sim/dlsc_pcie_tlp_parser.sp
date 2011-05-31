//######################################################################
#sp interface

#include <systemperl.h>

namespace dlsc {
    namespace pcie {
        class pcie_tlp;
    }
}

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    sc_fifo<dlsc::pcie::pcie_tlp> tlp_fifo;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/
    
    void stim_thread();

public:
    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

//#include "dlsc_common.h"

#include <iostream>
#include <iomanip>

#define DLSC_TB dlsc_pcie_tlp_parser
#include "dlsc_main.cpp"

#include "dlsc_pcie_tlp.h"

using namespace dlsc::pcie;
using namespace std;

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL (dut,Vdlsc_pcie);
        /*AUTOINST*/

    SP_CELL (inbound_driver,dlsc_pcie_inbound_driver);
        inbound_driver->tlp_fifo(tlp_fifo);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
}

void __MODULE__::stim_thread() {

    pcie_tlp tlp, tlp_post;

    vector<uint32_t> data;
    data.push_back(0xDEADBEEF);
    data.push_back(0x12345678);
    data.push_back(0xFEEDFACE);

    tlp.set_type(TYPE_CPL);
    tlp.set_data(data);
    tlp.set_address(0x42001200);

    tlp.set_traffic_class(4);
    tlp.set_digest(0xABCDEF01);
    tlp.set_attributes(false,true);
    tlp.set_source(0x4274);
    tlp.set_byte_enables(0xE,0x7);

    cout << tlp;

    data.clear();
    tlp.serialize(data);

    for(int i=0;i<data.size();i=i+1) {
        cout << " Data[" << setw(4) << i << "]:         0x" << hex << setw(8) << setfill('0') << data.at(i) << endl;
    }

    tlp_post.deserialize(data);

    dlsc_assert(tlp == tlp_post);

    cout << tlp_post;

    wait(100,SC_NS);

    tlp_fifo.write(tlp_post);
    tlp_fifo.write(tlp_post);
    
    wait(503,SC_NS);

    tlp_fifo.write(tlp_post);

    wait(1000,SC_NS);

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

