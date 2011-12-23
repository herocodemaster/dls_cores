//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

     int64_t mults( int32_t a,  int32_t b);
    uint64_t multu(uint32_t a, uint32_t b);
    uint64_t mult (uint32_t a, uint32_t b, bool s = false);

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

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

int64_t __MODULE__::mults( int32_t a,  int32_t b) {
    int64_t res = (int64_t)mult((uint32_t)a,(uint32_t)b, true);
    int64_t exps = ((int64_t)a) * ((int64_t)b);
    dlsc_assert_equals(res,exps);
    return res;
}

uint64_t __MODULE__::multu(uint32_t a, uint32_t b) {
    uint64_t res = (uint64_t)mult((uint32_t)a,(uint32_t)b, false);
    uint64_t expu = ((uint64_t)a) * ((uint64_t)b);
    dlsc_assert_equals(res,expu);
    return res;
}

uint64_t __MODULE__::mult(uint32_t a, uint32_t b, bool s) {

    // assume we're already synchronized to a clock edge
    in0     = a;
    in1     = b;
    sign    = s;
    start   = 1;
        
    wait(clk.posedge_event());
    start   = 0;

    do {
        wait(clk.posedge_event());
    } while(!done.read());

    return out.read();
}

void __MODULE__::stim_thread() {

    wait(clk.posedge_event());
    wait(clk.posedge_event());

    multu(0,1);
    multu(3,7);
    multu(2,1000000);
    multu(1000000,2);
    multu(1000000,1000000);

    for(int i=0;i<100000;++i) {

        if(rand()%2) {
            int32_t a, b;
            a = rand(); b = rand();
            mults(a,b);
        } else {
            uint32_t a, b;
            a = rand(); b = rand();
            multu(a,b);
        }

        if(rand()%10 == 0) {
            wait(rand()%1000,SC_NS);
            wait(clk.posedge_event());
        }

    }

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(100,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



