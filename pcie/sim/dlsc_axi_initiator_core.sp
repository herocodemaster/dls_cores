//######################################################################
#sp interface

#include <systemperl.h>

/*AUTOSUBCELL_CLASS*/

template <typename T_trn, typename T_word> class __MODULE__ : public sc_module {
protected:
    sc_port<sc_fifo_in_if<T_trn> > trn;
    sc_in<bool>     clk;
    sc_in<bool>     ready;
    sc_out<bool>    valid;
    sc_out<bool>    last;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

    virtual void trn_to_words(const T_trn &t, vector<T_word> &w);
    virtual void clear_data();
    virtual void set_data(const T_word &w)=0;
    void transaction_thread();

public:
    /*AUTOMETHODS*/
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

//#include "dlsc_common.h"


SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/

    SC_THREAD(transaction_thread);
}

void __MODULE__::trn_to_words(const T_trn &t, vector<T_word> &w) {
    t.serialize(w);
}

void __MODULE__::clear_data() {

}

void __MODULE__::transaction_thread() {
    // safe default values
    valid   = 0;
    last    = 0;
    clear_data();

    // make sure we start aligned to clock edge
    wait(clk.posedge_event());

    while(true) {
        T_trn t;
        vector<T_word> w;
        vector<T_word>::iterator it;

        // if available, output next packet immediately
        if(!trn.nb_read(t)) {
            // if not available, wait for next packet
            valid   = 0;
            last    = 0;
            clear_data();
            trn.read(t);
            // re-align to clock edge (in case packet arrives un-aligned)
            wait(clk.posedge_event());
        }

        // convert packet to words
        trn_to_words(t,w);
        it = w.begin();
  
        while(true) {
            // must be aligned to edge at this point
            set_data(*it);
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
    tlp.set_address_type(AT_TRANSLATED);
    tlp.set_source(0x42,0x7,0x4);
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

    tlp_f.write(tlp_post);
    tlp_f.write(tlp_post);
    
    wait(503,SC_NS);

    tlp_f.write(tlp_post);

    wait(1000,SC_NS);

    dut->final();
    sc_stop();
}

