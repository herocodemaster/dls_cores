//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

#include <deque>

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

struct in_type {
    uint32_t r;
    uint32_t g;
    uint32_t b;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    std::deque<in_type> in_queue[PARAM_CHANNELS];
    std::deque<uint32_t> out_queue[PARAM_CHANNELS];

    double mult_r;
    double mult_g;
    double mult_b;

    double in_rates[PARAM_CHANNELS];
    double out_rates[PARAM_CHANNELS];

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) :
    clk("clk",10,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
    
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        /*AUTOINST*/
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC      = 0x00;
const uint32_t REG_CORE_VERSION    = 0x01;
const uint32_t REG_CORE_INTERFACE  = 0x02;
const uint32_t REG_CORE_INSTANCE   = 0x03;
const uint32_t REG_CONTROL         = 0x04;
const uint32_t REG_MULT_R          = 0x05;
const uint32_t REG_MULT_G          = 0x06;
const uint32_t REG_MULT_B          = 0x07;

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = csr_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::clk_method() {
    if(rst) {
        in_valid    = 0;
        in_data_r   = 0;
        in_data_g   = 0;
        in_data_b   = 0;
        out_ready   = 0;
        for(int i=0;i<PARAM_CHANNELS;i++) {
            in_queue[i].clear();
            out_queue[i].clear();
        }
        return;
    }

    // ** inputs **

    uint32_t next_in_valid  = in_valid.read();
    uint64_t next_in_data_r = in_data_r.read();
    uint64_t next_in_data_g = in_data_g.read();
    uint64_t next_in_data_b = in_data_b.read();

    for(int i=0;i<PARAM_CHANNELS;i++) {

        if(in_ready & (1u<<i)) {
            // clear valid
            next_in_valid &= ~(1u<<i);
        }

        if(!(next_in_valid & (1u<<i)) && !in_queue[i].empty() && dlsc_rand_bool(in_rates[i])) {
            // set valid
            next_in_valid   |= (1u<<i);

            // clear input data
            next_in_data_r  &= ~( ((1ull<<PARAM_BITS)-1) << (i*PARAM_BITS) );
            next_in_data_g  &= ~( ((1ull<<PARAM_BITS)-1) << (i*PARAM_BITS) );
            next_in_data_b  &= ~( ((1ull<<PARAM_BITS)-1) << (i*PARAM_BITS) );

            // set input data
            in_type in = in_queue[i].front(); in_queue[i].pop_front();
            next_in_data_r  |= (in.r & ((1ull<<PARAM_BITS)-1)) << (i*PARAM_BITS);
            next_in_data_g  |= (in.g & ((1ull<<PARAM_BITS)-1)) << (i*PARAM_BITS);
            next_in_data_b  |= (in.b & ((1ull<<PARAM_BITS)-1)) << (i*PARAM_BITS);
        }
    }

    in_valid.write(next_in_valid);
    in_data_r.write(next_in_data_r);
    in_data_g.write(next_in_data_g);
    in_data_b.write(next_in_data_b);


    // ** outputs **

    uint32_t next_out_ready = out_ready.read();

    for(int i=0;i<PARAM_CHANNELS;i++) {
        // clear ready
        next_out_ready  &= ~(1u<<i);
        if(dlsc_rand_bool(out_rates[i])) {
            // set ready
            next_out_ready  |= (1u<<i);
        }

        if(out_valid & (1u<<i)) {
            if(out_queue[i].empty()) {
                dlsc_error("unexpected output: " << i);
            } else if(out_ready & (1u<<i)) {
                uint32_t data = out_queue[i].front(); out_queue[i].pop_front();
                dlsc_assert_equals( data , (out_data.read() >> (i*PARAM_BITS)) & ((1ull<<PARAM_BITS)-1) );
            }
        }
    }

    out_ready.write(next_out_ready);
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);

    uint32_t data;
    
    wait(clk.posedge_event());

    for(int iterations=0;iterations<20;iterations++) {
        rst     = 0;
        wait(clk.posedge_event());

        // randomize rates
        for(int i=0;i<PARAM_CHANNELS;i++) {
            in_rates[i] = 0.1 * dlsc_rand(1,1000);
            out_rates[i] = 0.1 * dlsc_rand(1,1000);
        }

        // randomize config
        mult_r = dlsc_rand(0,(1u<<PARAM_CBITS)-1) * 1.0/(1<<PARAM_CBITS);
        mult_g = dlsc_rand(0,(1u<<PARAM_CBITS)-1) * 1.0/(1<<PARAM_CBITS);
        mult_b = dlsc_rand(0,(1u<<PARAM_CBITS)-1) * 1.0/(1<<PARAM_CBITS);

        dlsc_info("mult_r: " << mult_r << ", mult_g: " << mult_g << ", mult_b: " << mult_b);

        // check common registers
        data = reg_read(REG_CORE_MAGIC);
        dlsc_assert_equals(data,0x926E9BD8);
        data = reg_read(REG_CORE_VERSION);
        dlsc_assert_equals(data,0x20120623);
        data = reg_read(REG_CORE_INTERFACE);
        dlsc_assert_equals(data,0x20120623);
        data = reg_read(REG_CORE_INSTANCE);
        dlsc_assert_equals(data,PARAM_CORE_INSTANCE);

        // set config
        reg_write(REG_MULT_R,(uint32_t)(mult_r * (1u<<PARAM_CBITS)));
        reg_write(REG_MULT_G,(uint32_t)(mult_g * (1u<<PARAM_CBITS)));
        reg_write(REG_MULT_B,(uint32_t)(mult_b * (1u<<PARAM_CBITS)));

        // enable
        reg_write(REG_CONTROL,0x1);

        // create stimulus
        for(int j=0;j<2000;j++) {
            for(int i=0;i<PARAM_CHANNELS;i++) {
                if(out_queue[i].size() > 25) continue;
                in_type in;
                in.r = dlsc_rand_u32(0,(1u<<PARAM_BITS)-1);
                in.g = dlsc_rand_u32(0,(1u<<PARAM_BITS)-1);
                in.b = dlsc_rand_u32(0,(1u<<PARAM_BITS)-1);
                in_queue[i].push_back(in);
                double outd = (in.r * mult_r) + (in.g * mult_g) + (in.b * mult_b) + 0.5;
                uint32_t out = (uint32_t)outd;
                if(out >= (1u<<PARAM_BITS)) out = (1u<<PARAM_BITS)-1;
                out_queue[i].push_back(out);
            }
            wait(clk.posedge_event());
        }

        // wait for completion
        for(int i=0;i<PARAM_CHANNELS;i++) {
            if(!out_queue[i].empty()) i--;
            wait(100,SC_NS);
        }

        // check config
        data = reg_read(REG_MULT_R);
        dlsc_assert_equals(data,(uint32_t)(mult_r * (1u<<PARAM_CBITS)));
        data = reg_read(REG_MULT_G);
        dlsc_assert_equals(data,(uint32_t)(mult_g * (1u<<PARAM_CBITS)));
        data = reg_read(REG_MULT_B);
        dlsc_assert_equals(data,(uint32_t)(mult_b * (1u<<PARAM_CBITS)));
        data = reg_read(REG_CONTROL);
        dlsc_assert_equals(data,0x1);

        // disable
        reg_write(REG_CONTROL,0x0);

        // reset
        if(dlsc_rand_bool(50.0)) {
            wait(clk.posedge_event());
            rst = 1;
            wait(clk.posedge_event());
        }
        
        // wait
        if(dlsc_rand_bool(50.0)) {
            wait(1,SC_US);
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

