
#include <iostream>
#include <deque>
#include <algorithm>
#include <numeric>
#include <boost/shared_array.hpp>

#include <cv.h>
#include <highgui.h>

#include "dlsc_stereobm_tb_common.h"

using namespace cv;

void dlsc_stereobm(cv::Mat &il, cv::Mat &ir, cv::Mat &id, cv::Mat &valid, cv::Mat &filtered) {
    std::deque<uint8_t*> rowsl;         // pointers to rows within current window
    std::deque<uint8_t*> rowsr;         // ""

    std::deque<int> sad_delay;          // delay-line for accumulating column sums into a window
    
    int *disps      = new int[il.cols];
    int *sads       = new int[il.cols];
    int *sads_thresh= new int[il.cols];
    int *sads_prev  = new int[il.cols]; // sad[d-1]
    int *sads_lo    = new int[il.cols]; // sad[mind-1]
    int *sads_hi    = new int[il.cols]; // sad[mind+1]

    // initialize to zero, so values outside of usable area are zeroed
    id          = cv::Mat::zeros(il.rows,il.cols,CV_16S);
    valid       = cv::Mat::zeros(il.rows,il.cols,CV_8UC1);
    filtered    = cv::Mat::zeros(il.rows,il.cols,CV_8UC1);

    // process all rows
    for(int y = 0; y < il.rows; ++y) {
        // crude progress indicator
        if(y%(il.rows/10)==0) std::cout << "." << std::endl;

        // accumulate pointers to rows within the SAD window
        rowsl.push_back(il.ptr<uint8_t>(y));
        rowsr.push_back(ir.ptr<uint8_t>(y));

        // can only compute disparities once we have enough rows for a complete SAD window
        if(y >= (SAD-1)) {
            short *dptr = id.ptr<short>(y-(SAD/2));
            uint8_t *vptr = valid.ptr<uint8_t>(y-(SAD/2));
            uint8_t *fptr = filtered.ptr<uint8_t>(y-(SAD/2));

            // initialize row disparity buffer
            for(int x=0;x<il.cols;++x) {
                disps[x]        = 0;
                sads[x]         = INT_MAX/256;
                sads_thresh[x]  = INT_MAX/256;
                sads_prev[x]    = INT_MAX/256;
                sads_lo[x]      = INT_MAX/256;
                sads_hi[x]      = INT_MAX/256;
            }

            // process one disparity level at a time
            for(int d=0;d<DISPARITIES;++d) {
                int sad_accum = 0;
                sad_delay.clear();
                // process whole row at this disparity
//                for(int x=DISPARITIES-1;x<il.cols;++x) {
                for(int x=0;x<il.cols;++x) {
                    if(d>x) continue;
                    // sum column
                    int sad = 0;
                    for(int ys=0;ys<SAD;++ys)
                        sad += abs((int)(rowsl[ys][x]) - (int)(rowsr[ys][x-d]));
                    
                    // accumulate window
                    sad_accum += sad;
                    sad_delay.push_back(sad);

                    // once window is filled, produce output
                    if(sad_delay.size()==SAD) {
                        int xd          = x - (SAD/2);

                        // ** keep track of best sad **
                        if(sad_accum <= sads[xd]) { // favors newer/higher disparities
                            // update thresh
                            if(disps[xd] != (d-1)) {
                                // previous disp is not within exclusion window, so we can use it
                                sads_thresh[xd] = sads[xd];
                            } else {
                                // find best of previous disps's thresh and lo
                                if(sads_lo[xd] < sads_thresh[xd]) {
                                    sads_thresh[xd] = sads_lo[xd];
                                }
                            }
                            // update disp/sad
                            disps[xd]       = d;
                            sads[xd]        = sad_accum;
                        } else if(sad_accum < sads_thresh[xd] && disps[xd] != (d-1)) {
                            sads_thresh[xd] = sad_accum;
                        }

                        // ** keep track of adjacent sads **
                        if(disps[xd] == d) {
                            // capture sad[mind-1]
                            sads_lo[xd]     = sads_prev[xd];
                        }                        
                        if(disps[xd] == (d-1)) {
                            // capture sad[mind+1]
                            sads_hi[xd]     = sad_accum;
                        }
                        sads_prev[xd]   = sad_accum;

                        // subtract column sums falling outside of window
                        sad_accum -= sad_delay.front(); sad_delay.pop_front();
                    }
                } // for(x..
            } // for(d..

#if TEXTURE>0
            // texture filtering
            // (reuse SAD logic)
            int sad_accum = 0;
            sad_delay.clear();
            // process whole row
            for(int x=0;x<il.cols;++x) {
                // sum column
                int sad = 0;
                for(int ys=0;ys<SAD;++ys)
                    sad += abs((int)(rowsl[ys][x]) - DATA_MAX/2);
                
                // accumulate window
                sad_accum += sad;
                sad_delay.push_back(sad);

                // once window is filled, produce output
                if(sad_delay.size()==SAD) {
                    int xd          = x - (SAD/2);

                    if(sad_accum < TEXTURE) {
                        // below threshold; filtered
                        fptr[xd] = 0xFF;
                    }

                    // subtract column sums falling outside of window
                    sad_accum -= sad_delay.front(); sad_delay.pop_front();
                }
            } // for(x..
#endif

            // ** post-process **
            for(int x=(DISPARITIES-1+(SAD/2));x<(il.cols-(SAD/2));++x) {
//            for(int x=(SAD/2);x<(il.cols-(SAD/2));++x) {

                vptr[x] = 0xFF;
                dptr[x] = (short)(disps[x] << SUB_BITS);
#if SUB_BITS>0
                // ** sub-pixel approximation **
                if(disps[x] > 0 && disps[x] < (DISPARITIES-1)) {
                    int lo = sads_lo[x] - sads[x];
                    int hi = sads_hi[x] - sads[x];
                    if( lo != hi ) {
                        int t = (lo>hi) ? (lo-hi) : (hi-lo);
                        int b = (lo>hi) ?  lo     :  hi;
                        int d = (t<<(SUB_BITS+SUB_BITS_EXTRA-1))/b;
                        if(lo > hi) {
                            dptr[x] += (short)( (d + ((1<<SUB_BITS_EXTRA)-1)) >> SUB_BITS_EXTRA );
                        } else {
                            dptr[x] += (short)( (((1<<SUB_BITS_EXTRA)-1) - d) >> SUB_BITS_EXTRA );
                        }
                    }
                }
#endif
#if UNIQUE_MUL>0
                // ** uniqueness filtering **
                int thresh = (sads[x] * (UNIQUE_MUL+UNIQUE_DIV))/UNIQUE_DIV;
                if(sads_thresh[x] <= thresh) {
                    fptr[x] = 0xFF;
                }
#endif
//                // zero output if filtered
//                if(fptr[x]) dptr[x] = 0;
            }

            // remove rows falling outside of window
            rowsl.pop_front();
            rowsr.pop_front();
        } // if(y..
    } // for(y..

    // clean up
    delete disps;
    delete sads;
    delete sads_thresh;
    delete sads_prev;
    delete sads_lo;
    delete sads_hi;
}

void dlsc_xsobel(const cv::Mat &in, cv::Mat &out) {

    for(int y=0;y<in.rows;++y) {

        const uint8_t *r0 = y > 0             ? in.ptr<uint8_t>(y-1) : in.ptr<uint8_t>(y+1);
        const uint8_t *r1 = in.ptr<uint8_t>(y);
        const uint8_t *r2 = y < (in.rows-1)   ? in.ptr<uint8_t>(y+1) : in.ptr<uint8_t>(y-1);

        uint8_t *d      = out.ptr<uint8_t>(y);

        d[0]            = (uint8_t)(DATA_MAX/2);
        d[in.cols-1]    = (uint8_t)(DATA_MAX/2);

        for(int x=1;x<(in.cols-1);++x) {
            
            int d0  = r0[x+1] - r0[x-1];
            int d1  = r1[x+1] - r1[x-1];
            int d2  = r2[x+1] - r2[x-1];

            int v   = d0 + 2*d1 + d2 + (DATA_MAX/2);

            if(v < 0) v = 0;
            else if(v > DATA_MAX) v = DATA_MAX;

            d[x]    = (uint8_t)v;

        }

    }

}

void dlsc_stereobm_run_test_cv(
    cv::Mat &il,
    cv::Mat &ir,
    std::deque<in_type> &in_vals,
    std::deque<out_type> &out_vals,
    const bool use_xsobel
) {
    assert(il.cols >= IMG_WIDTH && il.rows >= IMG_HEIGHT && il.cols == ir.cols && il.rows == ir.rows);

    // crop
    if(il.cols != IMG_WIDTH || il.rows != IMG_HEIGHT) {
        il = il(Range(0,IMG_HEIGHT),Range(0,IMG_WIDTH));
        ir = ir(Range(0,IMG_HEIGHT),Range(0,IMG_WIDTH));
    }

    assert(il.cols == IMG_WIDTH && il.rows == IMG_HEIGHT);
    
    cv::Mat id,valid,filtered,ilf,irf;

    ilf = il.clone();
    irf = ir.clone();

    if(use_xsobel) {
        dlsc_xsobel(il,ilf);
        dlsc_xsobel(ir,irf);
    }

    dlsc_stereobm(ilf,irf,id,valid,filtered);

    out_type chk;
    in_type in;

    for(unsigned int yr=0;yr<IMG_HEIGHT;yr+=MULT_R) {
        for(unsigned int x=0;x<IMG_WIDTH;++x) {
            chk.disp_valid_any = false;
            for(unsigned int i=0;i<MULT_R;++i) {
                unsigned int y = yr+i;

                uint8_t *rows_l  = il.ptr<uint8_t>(y);
                uint8_t *rows_r  = ir.ptr<uint8_t>(y);
                uint8_t *rows_lf = ilf.ptr<uint8_t>(y);
                uint8_t *rows_rf = irf.ptr<uint8_t>(y);
                short   *rows_d  = id.ptr<short>(y);
                uint8_t *rows_v  = valid.ptr<uint8_t>(y);
                uint8_t *rows_f  = filtered.ptr<uint8_t>(y);

                chk.disp[i]         = rows_d[x];
                chk.disp_valid[i]   = rows_v[x];
                chk.disp_filtered[i]= rows_f[x];

                // output is filtered
                chk.left[i]     = rows_lf[x];
                chk.right[i]    = rows_rf[x];

                // input is unfiltered
                in.left[i]      = rows_l[x];
                in.right[i]     = rows_r[x];
                    
                if(chk.disp_valid[i])
                    chk.disp_valid_any = true;
            }
                
            chk.frame_first = (x == 0 && yr == 0);
            chk.frame_last  = (x == (IMG_WIDTH-1) && yr == (IMG_HEIGHT-MULT_R));
            chk.row_first   = (x == 0);
            chk.row_last    = (x == (IMG_WIDTH-1));
            chk.x           = x;
            chk.y           = yr;
            
            out_vals.push_back(chk);
            in_vals.push_back(in);
        }
    }
}

void dlsc_stereobm_run_test(
    const char *left_image,
    const char *right_image,
    std::deque<in_type> &in_vals,
    std::deque<out_type> &out_vals,
    const bool use_xsobel
) {
    cv::Mat il = imread(left_image,0);
    cv::Mat ir = imread(right_image,0);

    dlsc_stereobm_run_test_cv(il,ir,in_vals,out_vals,use_xsobel);
}
