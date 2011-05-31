//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

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

#define ALU_MODE_ADD    (0x0)
#define ALU_MODE_COMP   (0x1)
#define ALU_MODE_SHIFT  (0x2)
#define ALU_MODE_LOGIC  (0x3)

#define ALU_ADD_ADD     (0x0)
#define ALU_ADD_SUB     (0x1)
#define ALU_ADD_EQU     (0x2)
#define ALU_ADD_NEQU    (0x3)

#define ALU_LOGIC_AND   (0x0)
#define ALU_LOGIC_OR    (0x1)
#define ALU_LOGIC_XOR   (0x2)
#define ALU_LOGIC_NOR   (0x3)

#define ALU_SHIFT_LEFT  (0x0)
#define ALU_SHIFT_RIGHT (0x1)

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,Vdlsc_cpu1_alu);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {

    for(int i=0;i<100000;++i) {

        alu_mode            = rand()%4;
        alu_add_signed      = rand()%2;
        
        wait(SC_ZERO_TIME);

        alu_add_op          = (alu_mode == ALU_MODE_ADD) ? (rand()%2) : ((rand()%3)+1);
        alu_logic_op        = rand()%4;
        alu_logic_bypass    = rand()%2;
        alu_shift_op        = rand()%2;

        int64_t ia          = rand();
        int64_t ib          = rand();

        if(alu_add_signed) {
            ia                  = (rand()%2) ? ia : -ia;
            ib                  = (rand()%2) ? ib : -ib;
        }

        ia = ((int32_t)ia);
        ib = ((int32_t)ib);

        if(alu_add_signed) {
            in_a_sign           = (ia < 0) ? 1 : 0;
            in_b_sign           = (ib < 0) ? 1 : 0;
        } else {
            ia                  = ((uint32_t)ia);
            ib                  = ((uint32_t)ib);
            in_a_sign           = 0;
            in_b_sign           = 0;
        }

        in_a                = ((uint32_t)ia);
        in_b                = ((uint32_t)ib);
        in_bypass           = rand();

        wait(clk.posedge_event());

        if(alu_mode == ALU_MODE_ADD) {
            uint64_t add_d = (alu_add_op == ALU_ADD_ADD) ? (ia + ib) : (ia - ib);
            dlsc_assert_equals(out_d, ((uint32_t)add_d) );
            if(alu_add_signed) {
                int64_t d64 = ((int64_t)add_d);
                int64_t d32 = ((int32_t)add_d);
                dlsc_assert_equals(out_overflow,(d32!=d64));
            }
        }

        if(alu_mode == ALU_MODE_COMP) {
            switch(alu_add_op) {
                case ALU_ADD_SUB:   dlsc_assert_equals(out_flag,(ia< ib)); break;
                case ALU_ADD_EQU:   dlsc_assert_equals(out_flag,(ia==ib)); break;
                case ALU_ADD_NEQU:  dlsc_assert_equals(out_flag,(ia!=ib)); break;
            }
            dlsc_assert_equals(out_d,out_flag);
        }

        if(alu_mode == ALU_MODE_SHIFT) {
            unsigned int b = ib & 0x1F;
            int64_t shift_d = (alu_shift_op == ALU_SHIFT_LEFT) ? (ia << b) : (ia >> b);
            int64_t d = out_d.read();

            if(alu_add_signed) {
                shift_d = ((int32_t)shift_d);
                d = ((int32_t)d);
            } else {
                shift_d = ((uint32_t)shift_d);
            }
            
            dlsc_assert_equals(d, shift_d);
        }

        if(alu_mode == ALU_MODE_LOGIC) {
            if(alu_logic_bypass) {
                dlsc_assert_equals(out_d,in_bypass);
            } else {
                uint32_t a = ((uint32_t)ia);
                uint32_t b = ((uint32_t)ib);
                switch(alu_logic_op) {
                    case ALU_LOGIC_AND: dlsc_assert_equals(out_d,  (a & b)); break;
                    case ALU_LOGIC_OR : dlsc_assert_equals(out_d,  (a | b)); break;
                    case ALU_LOGIC_XOR: dlsc_assert_equals(out_d,  (a ^ b)); break;
                    case ALU_LOGIC_NOR: dlsc_assert_equals(out_d, ~(a | b)); break;
                }
            }
        }

    }

    wait(1,SC_US);
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



