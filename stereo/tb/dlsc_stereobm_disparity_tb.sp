//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define IMG_WIDTH       PARAM_IMG_WIDTH
#define DISP_BITS       PARAM_DISP_BITS
#define DISPARITIES     PARAM_DISPARITIES
#define TEXTURE         PARAM_TEXTURE
#define SUB_BITS        PARAM_SUB_BITS
#define UNIQUE_MUL      PARAM_UNIQUE_MUL
#define MULT_D          PARAM_MULT_D
#define MULT_R          PARAM_MULT_R
#define SAD             PARAM_SAD
#define SAD_BITS        PARAM_SAD_BITS

#define PASSES (DISPARITIES/MULT_D)
#define END_WIDTH (IMG_WIDTH - (DISPARITIES-1) - (SAD-1))

#define DISP_BITS_R (DISP_BITS*MULT_R)
#define SAD_BITS_R (SAD_BITS*MULT_R)
#define SAD_BITS_RD (SAD_BITS_R*MULT_D)

#define SAD_MAX ((1<<SAD_BITS)-1)


/*AUTOSUBCELL_CLASS*/

struct in_type {
    bool    first;
    bool    last;
    int     sad   [MULT_R][MULT_D];
};

struct check_type {
    bool    first;
    bool    last;
    int     disp  [MULT_R];
    int     sad   [MULT_R];
    int     lo    [MULT_R];
    int     hi    [MULT_R];
    int     thresh[MULT_R];
    bool    filtered[MULT_R];
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    
    void send_row();

    void in_method();
    std::deque<in_type> in_vals;
    unsigned int rows_sent;

    void check_method();
    std::deque<check_type> check_vals;
    unsigned int rows_done;

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

struct disp_type {
    int sad[MULT_R][DISPARITIES];
};

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rows_sent = 0;
    rows_done = 0;
    
    SC_METHOD(in_method);
        sensitive << clk.posedge_event();
    SC_METHOD(check_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::send_row() {

    boost::shared_array<disp_type> row(new disp_type[END_WIDTH]);
    
    check_type chk;

    int d;

    // for each row, generate END_WIDTH*DISPARITIES disparities
    // and find the best ones
    for(int x=0;x<END_WIDTH;++x) {

        chk.first   = (x == 0);
        chk.last    = (x == (END_WIDTH-1));

        for(int r=0;r<MULT_R;++r) {

            chk.sad [r]     = SAD_MAX;
            chk.disp[r]     = 0;
            chk.filtered[r] = false;

            for(d=0;d<DISPARITIES;++d) {
                // create disparities
                row[x].sad[r][d] = ((unsigned int)rand()) % (SAD_MAX-1);
                // find best
                if(row[x].sad[r][d] <= chk.sad[r]) {
                    chk.sad [r]     = row[x].sad[r][d];
                    chk.disp[r]     = d;
                }
            }

            // find 2nd best outside of +-1 exclusion window (for uniqueness checking)
            chk.thresh[r]   = SAD_MAX;
            for(d=0;d<DISPARITIES;++d) {
                if(row[x].sad[r][d] < chk.thresh[r] && (d+1 < chk.disp[r] || d > chk.disp[r]+1 )) {
                    chk.thresh[r] = row[x].sad[r][d];
                }
            }

            // set adjacencies
            d = chk.disp[r];
            if( d > 0 ) {
                chk.lo[r] = row[x].sad[r][d-1];
            } else {
                chk.lo[r] = SAD_MAX;
            }
            if( d < (DISPARITIES-1) ) {
                chk.hi[r] = row[x].sad[r][d+1];
            } else {
                chk.hi[r] = SAD_MAX;
            }
        }

        check_vals.push_back(chk);
    }

    in_type in;

    // send down the pipeline
    for(int db=(DISPARITIES-MULT_D);db>=0;db-=MULT_D) {
        for(int x=0;x<END_WIDTH;++x) {
            for(int r=0;r<MULT_R;++r) {
                for(int p=0;p<MULT_D;++p) {
                    int d = db+p;
                    in.sad[r][p] = row[x].sad[r][d];
                }
            }

            in.first   = ((x == 0) && (db == (DISPARITIES-MULT_D)));
            in.last    = ((x == (END_WIDTH-1)) && (db == 0));

            in_vals.push_back(in);
        }
    }
}

void __MODULE__::in_method() {
    if(!rst && !in_vals.empty() && rand()%30) {
        in_type chk = in_vals.front(); in_vals.pop_front();


#if SAD_BITS_RD <= 64
        uint64_t sad  = 0;
        for(int r=0;r<MULT_R;++r) {
            for(int p=0;p<MULT_D;++p) {
                int j = (r*MULT_D) + p;
                sad  |= (((uint64_t)chk.sad[r][p]) << (j*SAD_BITS));
            }
        }
#else
        sc_bv<SAD_BITS_RD> sad  = 0;
        for(int r=0;r<MULT_R;++r) {
            for(int p=0;p<MULT_D;++p) {
                int j = (r*MULT_D) + p;
                sad.range( ((j+1)*SAD_BITS)-1 , (j*SAD_BITS) ) = chk.sad[r][p];
            }
        }
#endif

        in_sad    .write(sad);

        in_valid    = 1;

        if(chk.first) {
            dlsc_info("sending row " << rows_sent);
            rows_sent += MULT_R;
        }

    } else {

        in_valid        = 0;
        in_sad          = 0;

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

            sc_bv<DISP_BITS_R> disp         = out_disp  .read();
            sc_bv< SAD_BITS_R> sad          = out_sad   .read();
            sc_bv< SAD_BITS_R> sad_lo       = out_lo    .read();
            sc_bv< SAD_BITS_R> sad_hi       = out_hi    .read();
            sc_bv< SAD_BITS_R> sad_thresh   = out_thresh.read();
            sc_bv<     MULT_R> sad_filtered = out_filtered.read();
                
            int d,s,slo,shi,sthresh;
            bool sfiltered;

            for(int r=0;r<MULT_R;++r) {
                d       = disp      .range( ((r+1)*DISP_BITS)-1 , (r*DISP_BITS) ).to_uint();
                s       = sad       .range( ((r+1)* SAD_BITS)-1 , (r* SAD_BITS) ).to_uint();
                slo     = sad_lo    .range( ((r+1)* SAD_BITS)-1 , (r* SAD_BITS) ).to_uint();
                shi     = sad_hi    .range( ((r+1)* SAD_BITS)-1 , (r* SAD_BITS) ).to_uint();
                sthresh = sad_thresh.range( ((r+1)* SAD_BITS)-1 , (r* SAD_BITS) ).to_uint();
                sfiltered = sad_filtered[r].to_bool();

                dlsc_assert_equals(d,chk.disp[r]);
                dlsc_assert_equals(s,chk.sad [r]);
                dlsc_assert_equals(sfiltered,chk.filtered[r]);
#if SUB_BITS>0
                if(chk.disp[r] > 0) {
                    dlsc_assert_equals(slo,chk.lo[r]);
                }
                if(chk.disp[r] < (DISPARITIES-1)) {
                    dlsc_assert_equals(shi,chk.hi[r]);
                }
#endif
#if UNIQUE_MUL>0
                dlsc_assert_equals(sthresh,chk.thresh[r]);
#endif
            }

            if(chk.last) {
                dlsc_info("finished row " << rows_done);
                rows_done += MULT_R;
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

    for(int i=0;i<10;++i) {
        send_row();
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



