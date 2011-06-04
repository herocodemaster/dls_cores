
#include <iostream>
#include <iomanip>
#include <fstream>
#include <string>

#include <boost/program_options.hpp>
namespace po = boost::program_options;

#include <cv.h>
#include <highgui.h>

#include "dlsc_stereobm_models.h"

int img_to_memh(const std::string &filename, const cv::Mat &img) {

    std::ofstream memh;
    memh.open(filename.c_str());
    
    memh << "// " << std::dec << img.cols << "x" << img.rows << std::endl;

    if(img.type() == CV_8UC1) {

        memh << "// 8-bit" << std::endl;

        for(int y=0;y<img.rows;++y) {
            memh << "// row: " << std::dec << y << std::endl;
            const uint8_t *row = img.ptr<uint8_t>(y);
            for(int x=0;x<img.cols;++x) {
                memh << std::setw(2) << std::setfill('0') << std::hex << (unsigned int)(row[x]) << " ";
            }
            memh << std::endl;
        }

    } else {
        
        memh << "// 16-bit" << std::endl;

        for(int y=0;y<img.rows;++y) {
            memh << "// row: " << std::dec << y << std::endl;
            const uint16_t *row = img.ptr<uint16_t>(y);
            for(int x=0;x<img.cols;++x) {
                memh << std::setw(4) << std::setfill('0') << std::hex << (unsigned int)(row[x]) << " ";
            }
            memh << std::endl;
        }

    }

    memh.close();

    return 0;
}

int main(int argc, char *argv[]) {

    bool xsobel;

    dlsc_stereobm_params params;

    std::string leftfile;
    std::string rightfile;
    std::string outfile;

    bool use_readmemh;
    int width;
    int height;
    
    po::options_description desc("Allowed options");
    desc.add_options()
        ("xsobel",          po::value<bool>(&xsobel)->default_value(true),              "Use XSOBEL pre-filtering")
        ("data-max",        po::value<int>(&params.data_max)->default_value(14),        "Maximum XSOBEL output")
        ("disparities",     po::value<int>(&params.disparities)->default_value(64),     "Disparity levels")
        ("sad-window",      po::value<int>(&params.sad_window)->default_value(17),      "Sum-of-absolute-differences window")
        ("texture",         po::value<int>(&params.texture)->default_value(0),          "Texture filtering")
        ("sub-bits",        po::value<int>(&params.sub_bits)->default_value(4),         "Bits for sub-pixel interpolation")
        ("sub-bits-extra",  po::value<int>(&params.sub_bits_extra)->default_value(4),   "Extra bits for sub-pixel interpolation")
        ("unique-mul",      po::value<int>(&params.unique_mul)->default_value(0),       "Uniqueness ratio filtering multiplier")
        ("unique-div",      po::value<int>(&params.unique_div)->default_value(4),       "Uniqueness ratio filtering divisor")
        ("left",            po::value<std::string>(&leftfile),                          "Left image file input")
        ("right",           po::value<std::string>(&rightfile),                         "Right image file input")
        ("output",          po::value<std::string>(&outfile)->default_value("stereo"),  "Output files prefix")
        ("readmemh",        po::value<bool>(&use_readmemh)->default_value(false),       "Use Verilog $readmemh format for output")
        ("width",           po::value<int>(&width)->default_value(-1),                  "Width of output image")
        ("height",          po::value<int>(&height)->default_value(-1),                 "Height of output image")
    ;
    
    po::variables_map vm;
    po::store(po::parse_command_line(argc,argv,desc),vm);
    po::notify(vm);

    std::string of_inleft,of_inright,of_outleft,of_outright,of_disp,of_valid,of_filtered;

    std::string ext = use_readmemh ? ".memh" : ".jpg";

    of_inleft   = outfile + "_in_left"  + ext;
    of_inright  = outfile + "_in_right" + ext;
    of_outleft  = outfile + "_left"     + ext;
    of_outright = outfile + "_right"    + ext;
    of_disp     = outfile + "_disp"     + ext;
    of_valid    = outfile + "_valid"    + ext;
    of_filtered = outfile + "_filtered" + ext;

    cv::Mat il = cv::imread(leftfile,0);
    cv::Mat ir = cv::imread(rightfile,0);

    if(!il.data || !ir.data) {
        std::cerr << "failed to open input file(s)" << std::endl;
        return 1;
    }

    if(width <=0) width  = il.cols;
    if(height<=0) height = il.rows;

    cv::Mat ilf = il.clone();
    cv::Mat irf = ir.clone();

    if(xsobel) {
        dlsc_xsobel(il,ilf,params);
        dlsc_xsobel(ir,irf,params);
    }

    cv::Mat id,valid,filtered;
    dlsc_stereobm(ilf,irf,id,valid,filtered,params);

    if(use_readmemh) {
        
        // write output
        img_to_memh(of_inleft,      il);
        img_to_memh(of_inright,     ir);
        img_to_memh(of_outleft,     ilf);
        img_to_memh(of_outright,    irf);
        img_to_memh(of_disp,        id);
        img_to_memh(of_valid,       valid);
        img_to_memh(of_filtered,    filtered);

    } else {

        // normalize for viewing
        ilf.convertTo(ilf,CV_8U,256.0/(1.0*params.data_max));
        irf.convertTo(irf,CV_8U,256.0/(1.0*params.data_max));
        id .convertTo(id, CV_8U,256.0/(1.0*params.disparities*(1<<params.sub_bits)));

        // mask out filtered pixels
        id &= ~filtered;

        // write output
        cv::imwrite(of_inleft,      il);
        cv::imwrite(of_inright,     ir);
        cv::imwrite(of_outleft,     ilf);
        cv::imwrite(of_outright,    irf);
        cv::imwrite(of_disp,        id);
        cv::imwrite(of_valid,       valid);
        cv::imwrite(of_filtered,    filtered);

    }

    return 0;
}

