
#include <cv.h>
#include <highgui.h>

#include "dlsc_stereobm_models.h"
#include "dlsc_stereobm_models_sc.h"

void dlsc_stereobm_run_test_cv(
    cv::Mat &il,
    cv::Mat &ir,
    std::deque<in_type> &in_vals,
    std::deque<out_type> &out_vals
) {
    dlsc_stereobm_params params;

    params.xsobel           = USE_XSOBEL;
    params.disparities      = DISPARITIES;
    params.sad_window       = SAD;
    params.texture          = TEXTURE;
    params.data_max         = DATA_MAX;
    params.sub_bits         = SUB_BITS;
    params.sub_bits_extra   = SUB_BITS_EXTRA;
    params.unique_mul       = UNIQUE_MUL;
    params.unique_div       = UNIQUE_DIV;
    params.width            = IMG_WIDTH;
    params.height           = IMG_HEIGHT;
    params.scale            = true;
    
    cv::Mat id,valid,filtered,ilf,irf;

    dlsc_stereobm_invoker(il,ir,ilf,irf,id,valid,filtered,params);

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
    std::deque<out_type> &out_vals
) {
    cv::Mat il = cv::imread(left_image,0);
    cv::Mat ir = cv::imread(right_image,0);

    dlsc_stereobm_run_test_cv(il,ir,in_vals,out_vals);
}

