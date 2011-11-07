
`ifndef _DLSC_SP605_REGISTERS_H
`define _DLSC_SP605_REGISTERS_H

/* devices on register bus */
localparam REG_PCIE = 0;
localparam REG_PCIE_CONFIG = 1;
localparam REG_DMA_RD = 2;
localparam REG_DMA_WR = 3;
localparam REG_VGA = 4;
localparam REG_I2C = 5;
localparam REG_CLKGEN = 6;

/* registers for PCIe device */
localparam REG_PCIE_CONTROL = 10'h0;
localparam REG_PCIE_STATUS = 10'h1;
localparam REG_PCIE_INT_FLAGS = 10'h2;
localparam REG_PCIE_INT_SELECT = 10'h3;
localparam REG_PCIE_OBINT_FORCE = 10'h4;
localparam REG_PCIE_OBINT_FLAGS = 10'h5;
localparam REG_PCIE_OBINT_SELECT = 10'h6;
localparam REG_PCIE_OBINT_ACK = 10'h7;

/* registers for DMA devices */
localparam REG_DMA_CONTROL = 10'h0;
localparam REG_DMA_STATUS = 10'h1;
localparam REG_DMA_INT_FLAGS = 10'h2;
localparam REG_DMA_INT_SELECT = 10'h3;
localparam REG_DMA_COUNTS = 10'h4;
localparam REG_DMA_TRIG_IN = 10'h8;
localparam REG_DMA_TRIG_OUT = 10'h9;
localparam REG_DMA_TRIG_IN_ACK = 10'hA;
localparam REG_DMA_TRIG_OUT_ACK = 10'hB;
localparam REG_DMA_FRD_LO = 10'hC;
localparam REG_DMA_FRD_HI = 10'hD;
localparam REG_DMA_FWR_LO = 10'hE;
localparam REG_DMA_FWR_HI = 10'hF;

/* registers for VGA */
localparam REG_VGA_CONTROL = 10'h0;
localparam REG_VGA_STATUS = 10'h1;
localparam REG_VGA_INT_FLAGS = 10'h2;
localparam REG_VGA_INT_SELECT = 10'h3;
localparam REG_VGA_BUF_ADDR = 10'h4;
localparam REG_VGA_BPR = 10'h5;
localparam REG_VGA_STEP = 10'h6;
localparam REG_VGA_PXCFG = 10'h7;
localparam REG_VGA_HDISP = 10'h8;
localparam REG_VGA_HSYNCSTART = 10'h9;
localparam REG_VGA_HSYNCEND = 10'hA;
localparam REG_VGA_HTOTAL = 10'hB;
localparam REG_VGA_VDISP = 10'hC;
localparam REG_VGA_VSYNCSTART = 10'hD;
localparam REG_VGA_VSYNCEND = 10'hE;
localparam REG_VGA_VTOTAL = 10'hF;

/* registers for I2C */
localparam REG_I2C_PRE_LO = 10'h0;
localparam REG_I2C_PRE_HI = 10'h1;

localparam REG_I2C_CTR = 10'h2;
localparam REG_I2C_CTR_EN = (1<<7);
localparam REG_I2C_CTR_IEN = (1<<6);

localparam REG_I2C_TXR = 10'h3;
localparam REG_I2C_RXR = 10'h3;

localparam REG_I2C_CR = 10'h4;
localparam REG_I2C_CR_STA = (1<<7);
localparam REG_I2C_CR_STO = (1<<6);
localparam REG_I2C_CR_RD = (1<<5);
localparam REG_I2C_CR_WR = (1<<4);
localparam REG_I2C_CR_ACK = (1<<3);
localparam REG_I2C_CR_IACK = (1<<0);

localparam REG_I2C_SR = 10'h4;
localparam REG_I2C_SR_RXACK = (1<<7);
localparam REG_I2C_SR_BUSY = (1<<6);
localparam REG_I2C_SR_AL = (1<<5);
localparam REG_I2C_SR_TIP = (1<<1);
localparam REG_I2C_SR_IF = (1<<0);

/* registers for clkgen */
localparam REG_CLKGEN_CONTROL = 10'h0;
localparam REG_CLKGEN_STATUS = 10'h1;
localparam REG_CLKGEN_INT_FLAGS = 10'h2;
localparam REG_CLKGEN_INT_SELECT = 10'h3;
localparam REG_CLKGEN_MULTIPLY = 10'h4;
localparam REG_CLKGEN_DIVIDE = 10'h5;

`endif

