`timescale  1ns/1ns


module rgmii_rx(
    //以太网RGMII接口
    input              rgmii_rxc   , //RGMII接收时钟
    input              rgmii_rx_ctl, //RGMII接收数据控制信号
    input       [3:0]  rgmii_rxd   , //RGMII接收数据    

    //以太网GMII接口
    output             gmii_rx_clk , //GMII接收时钟
    output             gmii_rx_dv  , //GMII接收数据有效信号
    output      [7:0]  gmii_rxd      //GMII接收数据   
    );

//wire define
wire         rgmii_rxc_bufg;     //全局时钟缓存
wire         rgmii_rxc_bufio;    //全局时钟IO缓存
wire  [3:0]  rgmii_rxd_delay;    //rgmii_rxd输入延时
wire         rgmii_rx_ctl_delay; //rgmii_rx_ctl输入延时
wire  [1:0]  gmii_rxdv_t;        //两位GMII接收有效信号 

//*****************************************************
//**                    main code
//*****************************************************

assign gmii_rx_clk = rgmii_rxc;
assign gmii_rx_dv = gmii_rxdv_t[0] & gmii_rxdv_t[1];


IDDR2 #(
   .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1" 
   .INIT_Q0(1'b0), // Sets initial state of the Q0 output to 1'b0 or 1'b1
   .INIT_Q1(1'b0), // Sets initial state of the Q1 output to 1'b0 or 1'b1
   .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) u_iddr_rx_ctl (
   .Q0(gmii_rxdv_t[0]), // 1-bit output captured with C0 clock
   .Q1(gmii_rxdv_t[1]), // 1-bit output captured with C1 clock
   .C0(rgmii_rxc), // 1-bit clock input
   .C1(~rgmii_rxc), // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D(rgmii_rx_ctl),   // 1-bit DDR data input
   .R(1'b0),   // 1-bit reset input
   .S(1'b0)    // 1-bit set input
);


//rgmii_rxd输入延时与双沿采样
genvar i;
generate for (i=0; i<4; i=i+1)
    begin : rxdata_bus

IDDR2 #(
   .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1" 
   .INIT_Q0(1'b0), // Sets initial state of the Q0 output to 1'b0 or 1'b1
   .INIT_Q1(1'b0), // Sets initial state of the Q1 output to 1'b0 or 1'b1
   .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) u_iddr_rxd (
   .Q0(gmii_rxd[4+i]), // 1-bit output captured with C0 clock
   .Q1(gmii_rxd[i]), // 1-bit output captured with C1 clock
   .C0(rgmii_rxc), // 1-bit clock input
   .C1(~rgmii_rxc), // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D(rgmii_rxd[i]),   // 1-bit DDR data input
   .R(1'b0),   // 1-bit reset input
   .S(1'b0)    // 1-bit set input
);
    end
endgenerate

endmodule