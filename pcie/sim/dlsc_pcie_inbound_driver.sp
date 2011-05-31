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
public:
    sc_in<bool>         clk;

    sc_in<bool>         ready;
    sc_out<bool>        valid;
    sc_out<bool>        last;
    sc_out<uint32_t>    data;
    
    sc_port<sc_fifo_in_if<dlsc::pcie::pcie_tlp> > tlp_fifo;

    /*AUTOMETHODS*/

private:
    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/
    
    void tlp_thread();
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include <vector>
#include "dlsc_pcie_tlp.h"

using namespace std;
using namespace dlsc::pcie;

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    SC_THREAD(tlp_thread);
}

void __MODULE__::tlp_thread() {
    pcie_tlp tlp;
    vector<uint32_t> dw;
    vector<uint32_t>::iterator it;

    // safe default values
    data    = 0;
    valid   = 0;
    last    = 0;
    
    // make sure we start aligned to clock edge
    wait(clk.posedge_event());

    while(1) {
        // if available, output next packet immediately
        if(!tlp_fifo->nb_read(tlp)) {
            // if not available, wait for next packet
            data    = 0;
            valid   = 0;
            last    = 0;
            tlp_fifo->read(tlp);
            // re-align to clock edge (in case packet arrives un-aligned)
            wait(clk.posedge_event());
        }

        // convert packet to 32-bit words
        dw.clear();
        tlp.serialize(dw);
        it = dw.begin();
  
        while(1) {
            // must be aligned to edge at this point
            data    = *it;
            valid   = 1;
            last    = (it == dw.end()-1);

            wait(clk.posedge_event());

            if(ready && valid && (++it == dw.end())) {
                // after final word is accepted, immediately break and try
                // to accept next packet
                break;
            }
        }
    }
}

/*AUTOTRACE(__MODULE__)*/


