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

const uint32_t ALU_ADD      = 0x00;
const uint32_t ALU_SUB      = 0x01;
const uint32_t ALU_EQU      = 0x02;
const uint32_t ALU_NEQU     = 0x03;
const uint32_t ALU_AND      = 0x04;
const uint32_t ALU_OR       = 0x05;
const uint32_t ALU_XOR      = 0x06;
const uint32_t ALU_NOR      = 0x07;
const uint32_t ALU_SHIFTL   = 0x08;
const uint32_t ALU_SHIFTR   = 0x09;

const uint32_t ALU_COMP     = 0x11;

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {

    int64_t ia;
    int64_t ib;
    int64_t res;

    uint32_t mode;
    bool sign;

    for(int i=0;i<100000;++i) {

        sign          = dlsc_rand_u32(0,1);

        switch(dlsc_rand_u32(0,10)) {
            case  0: mode = ALU_ADD;                break;
            case  1: mode = ALU_SUB;                break;
            case  2: mode = ALU_COMP;               break;
            case  3: mode = ALU_EQU;    sign = 0;   break;
            case  4: mode = ALU_NEQU;   sign = 0;   break;
            case  5: mode = ALU_AND;    sign = 0;   break;
            case  6: mode = ALU_OR;     sign = 0;   break;
            case  7: mode = ALU_XOR;    sign = 0;   break;
            case  8: mode = ALU_NOR;    sign = 0;   break;
            case  9: mode = ALU_SHIFTL; sign = 0;   break;
            case 10: mode = ALU_SHIFTR;             break;
        }

        alu_signed          = sign;
        alu_op              = mode & 0xF;

        wait(SC_ZERO_TIME);

        if(sign) {
            ia                  = ((int32_t)dlsc_rand_u32());
            ib                  = ((int32_t)dlsc_rand_u32());
        } else {
            ia                  = ((uint32_t)dlsc_rand_u32());
            ib                  = ((uint32_t)dlsc_rand_u32());
        }
            
        in_a                = ((uint32_t)ia);
        in_b                = ((uint32_t)ib);

        if(mode == ALU_SHIFTL || mode == ALU_SHIFTR) {
            ib = ((uint32_t)ib) & 0x1F;
        }

        wait(clk.posedge_event());

        switch(mode) {
            case ALU_ADD:
            case ALU_SUB:
                res             = (mode == ALU_ADD) ? (ia + ib) : (ia - ib);
                dlsc_assert_equals( out_d, (uint32_t)res );
                if(sign) {
                    dlsc_assert_equals( out_overflow, ( ((int64_t)res) != ((int32_t)res)) );
                }
                break;
            case ALU_COMP:
                if(sign) {
                    dlsc_assert_equals(out_flag, ((( int32_t)ia) < (( int32_t)ib)) );
                } else {
                    dlsc_assert_equals(out_flag, (((uint32_t)ia) < ((uint32_t)ib)) );
                }
                break;
            case ALU_EQU:       dlsc_assert_equals( out_flag, (ia == ib) ); break;
            case ALU_NEQU:      dlsc_assert_equals( out_flag, (ia != ib) ); break;
            case ALU_AND:       dlsc_assert_equals( out_d, (uint32_t)(ia & ib) ); break;
            case ALU_OR :       dlsc_assert_equals( out_d, (uint32_t)(ia | ib) ); break;
            case ALU_XOR:       dlsc_assert_equals( out_d, (uint32_t)(ia ^ ib) ); break;
            case ALU_NOR:       dlsc_assert_equals( out_d, (uint32_t)(~(ia | ib) )); break;
            case ALU_SHIFTL:    dlsc_assert_equals( out_d, (uint32_t)(ia << ib) ); break;
            case ALU_SHIFTR:    dlsc_assert_equals( out_d, (uint32_t)(ia >> ib) ); break;
        }

        if(mode == ALU_COMP || mode == ALU_EQU || mode == ALU_NEQU) {
//            dlsc_assert_equals( out_d, out_flag ); // TODO
        }


//        if(mode == ALU_MODE_ADD) {
//            int64_t add_d = (alu_add_op == ALU_ADD_ADD) ? (ia + ib) : (ia - ib);
//            dlsc_assert_equals(out_d, ((uint32_t)add_d) );
//            if(alu_add_signed) {
//                int64_t d32 = ((int32_t)add_d);
//                dlsc_assert_equals(out_overflow,(add_d!=d32));
//            }
//        }
//
//        if(mode == ALU_MODE_COMP) {
//            switch(alu_add_op) {
//                case ALU_ADD_EQU:   dlsc_assert_equals(out_flag,(ia==ib)); break;
//                case ALU_ADD_NEQU:  dlsc_assert_equals(out_flag,(ia!=ib)); break;
//                case ALU_ADD_SUB:
//                    if(alu_add_signed) {
//                        dlsc_assert_equals(out_flag, ((( int32_t)ia) < (( int32_t)ib)) );
//                    } else {
//                        dlsc_assert_equals(out_flag, (((uint32_t)ia) < ((uint32_t)ib)) );
//                    }
//                    break;
//            }
//            dlsc_assert_equals(out_d,out_flag);
//        }
//
//        if(mode == ALU_MODE_SHIFT) {
//            unsigned int b = ib & 0x1F;
//            int64_t shift_d = (alu_shift_op == ALU_SHIFT_LEFT) ? (ia << b) : (ia >> b);
//            int64_t d = out_d.read();
//
//            if(alu_add_signed) {
//                shift_d = ((int32_t)shift_d);
//                d = ((int32_t)d);
//            } else {
//                shift_d = ((uint32_t)shift_d);
//            }
//            
//            dlsc_assert_equals(d, shift_d);
//        }
//
//        if(mode == ALU_MODE_LOGIC) {
//            if(alu_logic_bypass) {
//                dlsc_assert_equals(out_d,in_bypass);
//            } else {
//                uint32_t a = ((uint32_t)ia);
//                uint32_t b = ((uint32_t)ib);
//                switch(alu_logic_op) {
//                    case ALU_LOGIC_AND: dlsc_assert_equals(out_d,  (a & b)); break;
//                    case ALU_LOGIC_OR : dlsc_assert_equals(out_d,  (a | b)); break;
//                    case ALU_LOGIC_XOR: dlsc_assert_equals(out_d,  (a ^ b)); break;
//                    case ALU_LOGIC_NOR: dlsc_assert_equals(out_d, ~(a | b)); break;
//                }
//            }
//        }

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



