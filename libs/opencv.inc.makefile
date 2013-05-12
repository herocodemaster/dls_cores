
# reference libraries for OpenCV 2.4 built from source
# (per http://karytech.blogspot.com/2012/05/opencv-24-on-ubuntu-1204.html)
H_SYS_DIRS  += /usr/local/include/opencv
LDLIBS      += -l:libopencv_core.so.2.4 -l:libopencv_highgui.so.2.4 -l:libopencv_imgproc.so.2.4

#H_SYS_DIRS  += /usr/include/opencv
#LDLIBS      += -lcv -lcvaux -lhighgui -lcxcore
#H_SYS_DIRS  += /usr/include/opencv-2.3.1 /usr/include/opencv-2.3.1/opencv /usr/include/opencv-2.3.1/opencv2
#LDLIBS      += -lopencv_core -lopencv_highgui

