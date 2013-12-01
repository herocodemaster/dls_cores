//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

// Verilog parameters
#define DISP_BITS       PARAM_DISP_BITS
#define DISPARITIES     PARAM_DISPARITIES
#define UNIQUE_MUL      PARAM_UNIQUE_MUL
#define UNIQUE_DIV      PARAM_UNIQUE_DIV
#define SUB_BITS        PARAM_SUB_BITS
#define SUB_BITS_EXTRA  PARAM_SUB_BITS_EXTRA
#define MULT_R          PARAM_MULT_R
#define SAD_BITS        PARAM_SAD_BITS

#define DISP_BITS_R (DISP_BITS*MULT_R)
#define SAD_BITS_R (SAD_BITS*MULT_R)

#define DISP_BITS_S (DISP_BITS+SUB_BITS)
#define DISP_BITS_SR (DISP_BITS_S*MULT_R)

#define SAD_MAX ((1<<SAD_BITS)-1)


/*AUTOSUBCELL_CLASS*/

struct in_type {
    int disp[MULT_R];
    int sad [MULT_R];
    int lo[MULT_R];
    int hi[MULT_R];
    int thresh[MULT_R];
    bool filtered[MULT_R];
};

struct check_type {
    int disp[MULT_R];
    int sad[MULT_R];
    bool filtered[MULT_R];
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    
    void send_px();

    void in_method();
    std::deque<in_type> in_vals;

    void check_method();
    std::deque<check_type> check_vals;

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

#include <vector>

#include "dlsc_main.cpp"

struct disp_pair {
    int disp;
    int sad;
};

bool compare_disp(const disp_pair &a, const disp_pair &b) {
    if(a.sad == b.sad) return (a.disp < b.disp);
    return (a.sad < b.sad);
}

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SC_METHOD(in_method);
        sensitive << clk.posedge_event();
    SC_METHOD(check_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::send_px() {

    disp_pair disps[DISPARITIES];
    disp_pair disps_sorted[DISPARITIES];

    in_type in;
    check_type chk;

    int r,d,mind,minsad;

    for(r=0;r<MULT_R;++r) {

        // ** generate input **

        // randomize disparities
        for(d=0;d<DISPARITIES;++d) {
            disps[d].disp   = d;
            disps[d].sad    = ((unsigned int)rand()) % SAD_MAX;
        }

        // sort disparities
        std::copy(disps,disps+DISPARITIES,disps_sorted);
        std::sort(disps_sorted,disps_sorted+DISPARITIES,compare_disp);

        // output best one 
        mind        = disps_sorted[0].disp;
        minsad      = disps_sorted[0].sad;
        in.disp[r]  = mind;
        in.sad[r]   = minsad;

        // output 2nd best one that isn't adjacent to best
        for(d=1;d<DISPARITIES;++d) {
            if( (disps_sorted[d].disp+1) < mind || disps_sorted[d].disp > (mind+1) ) {
                in.thresh[r] = disps_sorted[d].sad;
                break;
            }
        }

        // adjacencies
        if(mind > 0) {
            in.lo[r] = disps[mind-1].sad;
        } else {
            in.lo[r] = SAD_MAX;
        }
        if(mind < (DISPARITIES-1)) {
            in.hi[r] = disps[mind+1].sad;
        } else {
            in.hi[r] = SAD_MAX;
        }

        in.filtered[r] = ((rand()%10)==0);

        // ** compute expected result **
        chk.filtered[r] = in.filtered[r];
        chk.disp[r]     = mind << SUB_BITS;
#if UNIQUE_MUL>0
        // ** uniqueness filtering **
        int thresh = (minsad * (UNIQUE_MUL+UNIQUE_DIV))/UNIQUE_DIV;
        if(in.thresh[r] <= thresh) {
            chk.filtered[r] = true;
        }
#endif
#if SUB_BITS>0
        // ** sub-pixel approximation **
        if(mind > 0 && mind < (DISPARITIES-1)) {
            int lo = disps[mind-1].sad - minsad;
            int hi = disps[mind+1].sad - minsad;
            if( lo != hi ) {
                int a = (lo>hi) ? hi : lo;
                int b = (lo>hi) ? lo : hi;
                int d = ((b-a)<<(SUB_BITS+SUB_BITS_EXTRA-1))/b;
                if(lo > hi) {
                    chk.disp[r] += (short)( (d + ((1<<SUB_BITS_EXTRA)-1)) >> SUB_BITS_EXTRA );
                } else {
                    chk.disp[r] += (short)( (((1<<SUB_BITS_EXTRA)-1) - d) >> SUB_BITS_EXTRA );
                }
            }
        }
#endif
    }

    in_vals.push_back(in);
    check_vals.push_back(chk);
}

void __MODULE__::in_method() {
    if(!rst && !in_vals.empty() && rand()%30) {
        in_type chk = in_vals.front(); in_vals.pop_front();


#if DISP_BITS_R <= 64
        uint64_t disp  = 0;
        for(int r=0;r<MULT_R;++r) {
            disp |= (((uint64_t)(chk.disp[r])) << (r*DISP_BITS));
        }
#else
        sc_bv<DISP_BITS_R> disp  = 0;
        for(int r=0;r<MULT_R;++r) {
            disp.range( ((r+1)*DISP_BITS)-1 , (r*DISP_BITS) ) = (chk.disp[r][0]);
        }
#endif

#if SAD_BITS_R <= 64
        uint64_t sad    = 0;
        uint64_t lo     = 0;
        uint64_t hi     = 0;
        uint64_t thresh = 0;
        for(int r=0;r<MULT_R;++r) {
            sad     |= (((uint64_t)chk.sad   [r]) << (r*SAD_BITS));
            lo      |= (((uint64_t)chk.lo    [r]) << (r*SAD_BITS));
            hi      |= (((uint64_t)chk.hi    [r]) << (r*SAD_BITS));
            thresh  |= (((uint64_t)chk.thresh[r]) << (r*SAD_BITS));
        }
#else
        sc_bv<SAD_BITS_R> sad       = 0;
        sc_bv<SAD_BITS_R> lo        = 0;
        sc_bv<SAD_BITS_R> hi        = 0;
        sc_bv<SAD_BITS_R> thresh    = 0;
        for(int r=0;r<MULT_R;++r) {
            sad   .range( ((r+1)*SAD_BITS)-1 , (r*SAD_BITS) ) = chk.sad   [r];
            lo    .range( ((r+1)*SAD_BITS)-1 , (r*SAD_BITS) ) = chk.lo    [r];
            hi    .range( ((r+1)*SAD_BITS)-1 , (r*SAD_BITS) ) = chk.hi    [r];
            thresh.range( ((r+1)*SAD_BITS)-1 , (r*SAD_BITS) ) = chk.thresh[r];
        }
#endif

        uint64_t filtered = 0;
        for(int r=0;r<MULT_R;++r) {
            if(chk.filtered[r]) filtered |= (1<<r);
        }

        in_disp.write(disp);
        in_sad.write(sad);
        in_lo.write(lo);
        in_hi.write(hi);
        in_thresh.write(thresh);
        in_filtered.write(filtered);

        in_valid        = 1;

    } else {

        in_valid    = 0;
        in_disp     = 0;
        in_sad      = 0;
        in_lo       = 0;
        in_hi       = 0;
        in_thresh   = 0;

        if(rst) {
            in_vals.clear();
        }

    }
}


void __MODULE__::check_method() {
    if(rst) {
        check_vals.clear();
        return;
    }

    if(out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected output");
        } else {
            check_type chk = check_vals.front(); check_vals.pop_front();

            sc_bv<DISP_BITS_SR> disp     = out_disp    .read();
            sc_bv<      MULT_R> filtered = out_filtered.read();
                
            int d;
            bool f;

            for(int r=0;r<MULT_R;++r) {
                d = disp.range( ((r+1)*DISP_BITS_S)-1 , (r*DISP_BITS_S) ).to_uint();
                f = filtered[r].to_bool();

                dlsc_assert_equals(d,chk.disp[r]);
                dlsc_assert_equals(f,chk.filtered[r]);
            }
        }
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);

    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;

    for(int i=0;i<10000;++i) {
        send_px();
    }

    while(!check_vals.empty()) {
        wait(10,SC_US);
    }

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



