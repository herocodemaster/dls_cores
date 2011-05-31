//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define ROW_WIDTH   PARAM_ROW_WIDTH
#define ROWS        PARAM_ROWS
#define DATA        PARAM_DATA

#define DATA_R      (DATA*ROWS)


/*AUTOSUBCELL_CLASS*/

struct check_type {
    unsigned int data[ROWS];
};

SC_MODULE (__MODULE__) {
private:
    sc_clock in_clk;
    sc_clock out_clk;
    
    void send_rows();

    void in_method();
    std::deque<check_type> in_vals;

    void check_method();
    std::deque<unsigned int> check_vals;

    void stim_thread();
    void watchdog_thread();

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include <algorithm>
#include <numeric>

#include <boost/shared_array.hpp>

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : in_clk("in_clk",PARAM_IN_CLK,SC_NS), out_clk("out_clk",PARAM_OUT_CLK,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
    
    SC_METHOD(in_method);
        sensitive << in_clk.posedge_event();
    SC_METHOD(check_method);
        sensitive << out_clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::send_rows() {

    check_type *chk = new check_type[ROW_WIDTH];

    for(int r=0;r<ROWS;++r) {
        for(int x=0;x<ROW_WIDTH;++x) {
            chk[x].data[r] = rand() % ((1<<DATA)-1);
            check_vals.push_back(chk[x].data[r]);
        }
    }

    for(int x=0;x<ROW_WIDTH;++x) {
        in_vals.push_back(chk[x]);
    }

    delete chk;
}

void __MODULE__::in_method() {
    if(in_rst || in_ready) {
        in_valid    = 0;
        in_data     = 0;

        if(in_rst) {
            in_vals.clear();
            return;
        }
    }

    if((!in_valid||in_ready) && !in_vals.empty() && rand()%30) {
        check_type in = in_vals.front(); in_vals.pop_front();
        
#if DATA_R <= 64
        uint64_t data = 0;
        for(unsigned int i=0;i<ROWS;++i) {
            data  |= ( ((uint64_t)in.data[i])  << (i*DATA) );
        }
#else
        sc_bv<DATA_R> data = 0;
        for(unsigned int i=0;i<ROWS;++i) {
            data.range ( (i*DATA)+DATA-1 , (i*DATA) ) = in.data[i];
        }
#endif
        
        in_valid    = 1;
        in_data.write(data);
    }
}


void __MODULE__::check_method() {
    if(out_rst || out_valid) {
        out_ready   = 0;
        if(out_rst) {
            check_vals.clear();
            return;
        }
    }

    if(out_ready && out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected output");
        } else {
            dlsc_assert_equals(check_vals.front(),out_data.read());
            check_vals.pop_front();
        }
    }

    if( (rand()%5) != 0 ) {
        out_ready   = 1;
    }
}

void __MODULE__::stim_thread() {
    in_rst  = 1;
    out_rst = 1;
    wait(1,SC_US);

    wait(in_clk.posedge_event());
    in_rst  = 0;
    wait(out_clk.posedge_event());
    out_rst = 0;

    for(int i=0;i<100;++i) {
        send_rows();
    }

    while(!check_vals.empty()) {
        wait(10,SC_US);
    }

    dlsc_info("done");

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



