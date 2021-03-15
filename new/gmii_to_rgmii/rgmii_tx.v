`timescale  1ns/1ns


module rgmii_tx(
    //GMII发送端口
    input              gmii_tx_clk , //GMII发送时钟    
    input              gmii_tx_en  , //GMII输出数据有效信号
    input       [7:0]  gmii_txd    , //GMII输出数据        
    
    //RGMII发送端口
    output             rgmii_txc   , //RGMII发送数据时钟    
    output             rgmii_tx_ctl, //RGMII输出数据有效信号
    output      [3:0]  rgmii_txd     //RGMII输出数据     
    );

//*****************************************************
//**                    main code
//*****************************************************

assign rgmii_txc = gmii_tx_clk;

ODDR2 #(
   .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1" 
   .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
   .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) ODDR_inst (
   .Q(rgmii_tx_ctl),   // 1-bit DDR output data
   .C0(gmii_tx_clk),   // 1-bit clock input
   .C1(~gmii_tx_clk),   // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D0(gmii_tx_en), // 1-bit data input (associated with C0)
   .D1(gmii_tx_en), // 1-bit data input (associated with C1)
   .R(1'b0),   // 1-bit reset input
   .S(1'b0)    // 1-bit set input
);

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus

ODDR2 #(
   .DDR_ALIGNMENT("C0"), // Sets output alignment to "NONE", "C0" or "C1" 
   .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
   .SRTYPE("ASYNC") // Specifies "SYNC" or "ASYNC" set/reset
) ODDR_inst (
   .Q(rgmii_txd[i]),   // 1-bit DDR output data
   .C0(gmii_tx_clk),   // 1-bit clock input
   .C1(~gmii_tx_clk),   // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D0(gmii_txd[i]), // 1-bit data input (associated with C0)
   .D1(gmii_txd[4+i]), // 1-bit data input (associated with C1)
   .R(1'b0),   // 1-bit reset input
   .S(1'b0)    // 1-bit set input
);        
    end
endgenerate

endmodule