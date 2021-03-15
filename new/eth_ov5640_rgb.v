`timescale  1ns/1ns


module eth_ov5640_rgb(
    input              sys_clk   , //系统时钟
    input              sys_rst_n , //系统复位信号，低电平有效 
    //PL以太网RGMII接口   
    input              eth_rxc   , //RGMII接收数据时钟
    input              eth_rx_ctl, //RGMII输入数据有效信号
    input       [3:0]  eth_rxd   , //RGMII输入数据
    output             eth_txc   , //RGMII发送数据时钟    
    output             eth_tx_ctl, //RGMII输出数据有效信号
    output      [3:0]  eth_txd   , //RGMII输出数据          
    output             eth_rst_n , //以太网芯片复位信号，低电平有效
    //摄像头接口
    input   wire            cam1_pclk   ,  //摄像头数据像素时钟
    input   wire            cam1_vsync  ,  //摄像头场同步信号
    input   wire            cam1_href   ,  //摄像头行同步信号
    input   wire    [7:0]   cam1_data   ,  //摄像头数据
    output  wire            cam1_scl    ,  //摄像头SCCB_SCL线
    inout   wire            cam1_sda    ,  //摄像头SCCB_SDA线
    
    output  wire            cam_rst_n   ,  //摄像头复位信号，低电平有效
    output  wire            cam_pwdn    ,  //摄像头时钟选择信号
    //摄像头2接口
    input   wire            cam2_pclk   ,  //摄像头数据像素时钟
    input   wire            cam2_vsync  ,  //摄像头场同步信号
    input   wire            cam2_href   ,  //摄像头行同步信号
    input   wire    [7:0]   cam2_data   ,  //摄像头数据
    output  wire            cam2_scl    ,  //摄像头SCCB_SCL线
    inout   wire            cam2_sda    ,  //摄像头SCCB_SDA线
//DDR接口

    inout [31:0]       ddr3_dq,
    inout [3:0]        ddr3_dqs_n,
    inout [3:0]        ddr3_dqs_p,
    output [14:0]      ddr3_addr,
    output [2:0]       ddr3_ba,
    output             ddr3_ras_n,
    output             ddr3_cas_n,
    output             ddr3_we_n,
    output             ddr3_reset_n,
    output [0:0]       ddr3_ck_p,
    output [0:0]       ddr3_ck_n,
    output [0:0]       ddr3_cke,
    output [0:0]       ddr3_cs_n,
    output [3:0]       ddr3_dm,
    output [0:0]       ddr3_odt
    );




//parameter define
//开发板MAC地址 12_34_56_78_9a_bc
parameter  BOARD_MAC = 48'h12_34_56_78_9a_bc;     
//开发板IP地址 192.168.0.234
parameter  BOARD_IP  = {8'd192,8'd168,8'd0,8'd234};  
//目的MAC地址 ff_ff_ff_ff_ff_ff
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//目的IP地址 192.168.0.145     
parameter  DES_IP    = {8'd192,8'd168,8'd0,8'd145};  

parameter  H_PIXEL    = 30'd640       ;  //CMOS水平方向像素个数
parameter  V_PIXEL    = 30'd480       ;  //CMOS垂直方向像素个数
//wire define
wire          clk_phase   ; //用于IO延时的时钟 
              
wire          gmii_rx_clk; //GMII接收时钟
wire          gmii_rx_dv ; //GMII接收数据有效信号
wire  [7:0]   gmii_rxd   ; //GMII接收数据
wire          gmii_tx_clk; //GMII发送时钟
wire          gmii_tx_en ; //GMII发送数据使能信号
wire  [7:0]   gmii_txd   ; //GMII发送数据     

wire  [47:0]  des_mac       ; //发送的目标MAC地址
wire  [31:0]  des_ip        ; //发送的目标IP地址   

wire          rec_pkt_done  ; //UDP单包数据接收完成信号
wire          rec_en        ; //UDP接收的数据使能信号
wire  [31:0]  rec_data      ; //UDP接收的数据
wire  [15:0]  rec_byte_num  ; //UDP接收的有效字节数 单位:byte 
wire  [15:0]  tx_byte_num   ; //UDP发送的有效字节数 单位:byte 
wire          udp_tx_done   ; //UDP发送完成信号
wire          tx_req        ; //UDP读数据请求信号
wire  [31:0]  tx_data       ; //UDP待发送数据

//以太网
wire            i_config_end    ;   //图像格式包发送完成
wire            eth_tx_start    ;   //以太网开始发送信号
wire            eth_tx_start_i  ;   //以太网开始发送信号(图像)
wire            eth_tx_start_f  ;   //以太网开始发送信号(格式)
wire    [31:0]  eth_tx_data     ;   //以太网发送的数据
wire    [31:0]  eth_tx_data_f   ;   //以太网发送的数据(格式)
wire    [31:0]  eth_tx_data_i   ;   //以太网发送的数据(图像)
wire    [15:0]  eth_tx_data_num ;   //以太网单包发送的有效字节数
wire    [15:0]  eth_tx_data_num_i;  //以太网单包发送的有效字节数(图像)
wire    [15:0]  eth_tx_data_num_f;  //以太网单包发送的有效字节数(格式)

//ddr读写数据
wire rst_n;
wire c3_rst0;
wire clk_25m;
wire clk_320m;
wire sys_init_done;
wire cfg_done1;
wire cfg_done2;
wire locked;
wire locked_1;
reg  wr_en_reg;
wire wr_en;
wire [15:0]wr_data;
wire wr_en1;
wire [15:0]wr_data1;
wire wr_en2;
wire [15:0]wr_data2;
wire rd_en;
wire [15:0]rd_data;


reg [29:0] addr_cnt;
//*****************************************************
//**                    main code
//*****************************************************

assign eth_rst_n = 1'b1;
//系统初始化完成
assign sys_init_done =!c3_rst0 & cfg_done1 & cfg_done2 & c3_calib_done;
//系统复位完成
assign rst_n=sys_rst_n & !c3_rst0 & locked & locked_1;
//------------- cam1_top_inst -------------

assign cam_rst_n    =  1'b1;
assign cam_pwdn     =  1'b0;

ov5640_top  cam1_top_inst(

    .sys_clk        (clk_25m        ),   //系统时钟
    .sys_rst_n      (!c3_rst0       ),   //复位信号
    .sys_init_done  (sys_init_done  ),   //系统初始化完成(DDR + 摄像头)

    .ov5640_pclk    (cam1_pclk      ),   //摄像头像素时钟
    .ov5640_href    (cam1_href      ),   //摄像头行同步信号
    .ov5640_vsync   (cam1_vsync     ),   //摄像头场同步信号
    .ov5640_data    (cam1_data      ),   //摄像头图像数据

    .cfg_done       (cfg_done1       ),   //寄存器配置完成
    .sccb_scl       (cam1_scl       ),   //SCL
    .sccb_sda       (cam1_sda       ),   //SDA
    .ov5640_wr_en   (wr_en1         ),   //图像数据有效使能信号
    .ov5640_data_out(wr_data1       )    //图像数据
);
ov5640_top  cam2_top_inst(

    .sys_clk        (clk_25m        ),   //系统时钟
    .sys_rst_n      (!c3_rst0       ),   //复位信号
    .sys_init_done  (sys_init_done  ),   //系统初始化完成(DDR + 摄像头)

    .ov5640_pclk    (cam2_pclk      ),   //摄像头像素时钟
    .ov5640_href    (cam2_href      ),   //摄像头行同步信号
    .ov5640_vsync   (cam2_vsync     ),   //摄像头场同步信号
    .ov5640_data    (cam2_data      ),   //摄像头图像数据

    .cfg_done       (cfg_done2      ),   //寄存器配置完成
    .sccb_scl       (cam2_scl       ),   //SCL
    .sccb_sda       (cam2_sda       ),   //SDA
    .ov5640_wr_en   (wr_en2         ),   //图像数据有效使能信号
    .ov5640_data_out(wr_data2       )    //图像数据
);


assign wr_en    = (addr_cnt%640)<320 ? wr_en1 : wr_en2;
assign wr_data  = (addr_cnt%640)<320 ? wr_data1 : wr_data2;

always@(posedge cam1_pclk or negedge sys_rst_n)begin
    if(sys_rst_n == 1'b0)
        wr_en_reg <= 1'b0;
    else 
        wr_en_reg <= wr_en;
end

always@(posedge cam1_pclk or negedge sys_rst_n)begin
    if(sys_rst_n == 1'b0)
        addr_cnt <= 30'd0;
    else if(addr_cnt == H_PIXEL*V_PIXEL)
        addr_cnt <= 30'd0;
    else if(wr_en == 1'b1 && wr_en_reg == 1'b0)
        addr_cnt <= addr_cnt + 30'd1;
end


clk_wiz_0 u_clk_wiz_0
(
    // Clock out ports
    .clk_out1   (clk_25m    ),     // output clk_out1
    .clk_out2   (clk_320m   ),     // output clk_out2
    .clk_out3   (           ),     // output clk_out3
    // Status and control signals
    .reset      (~sys_rst_n ), // input resetn
    .locked     (locked     ),       // output locked
   // Clock in ports
    .clk_in1    (sys_clk    )      // input clk_in1
);


//PLL时钟偏移
clk_wiz_phase u_clk_wiz_phase
(
    .clk_in1   (eth_rxc     ),  //PLL输入信号，以太网接收时钟
    .clk_out1  (clk_phase   ),  //PLL输出信号，偏移一定的相位
    .reset     (~sys_rst_n  ),  //PLL复位，高电平有效
    .locked    (locked_1    )   //PLL稳定锁定信号
);


//------------- ddr_rw_inst -------------
//DDR读写控制部分
axi_ddr_top 
#(
.DDR_WR_LEN(64),//写突发长度 最大128个64bit
.DDR_RD_LEN(64)//读突发长度 最大128个64bit
)
ddr_rw_inst(
  .ddr3_clk     (clk_320m       ),
  .sys_rst_n    (sys_rst_n&locked),
  .pingpang     (0              ),
   //写用户接口
  .user_wr_clk  (cam1_pclk      ), //写时钟
  .data_wren    (wr_en          ), //写使能，高电平有效
  .data_wr      ({wr_data[7:0],wr_data[15:8]}), //写数据16位wr_data
  .wr_b_addr    (30'd0          ), //写起始地址
  .wr_e_addr    (H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址，16位x2
  .wr_rst       (1'b0           ), //写地址复位 wr_rst
  //读用户接口   
  .user_rd_clk  (gmii_tx_clk    ), //读时钟
  .data_rden    (rd_en          ), //读使能，高电平有效
  .data_rd      (rd_data        ), //读数据16位
  .rd_b_addr    (30'd0          ), //读起始地址
  .rd_e_addr    (H_PIXEL*V_PIXEL*2  ), //写结束地址,8位一字节对应一个地址,16位x2
  .rd_rst       (1'b0           ), //读地址复位 rd_rst
  .read_enable  (1'b1           ),
   
  .ui_rst       (c3_rst0        ), //ddr产生的复位信号
  .ui_clk       (c3_clk0        ), //ddr操作时钟125m
  .calib_done   (c3_calib_done  ), //代表ddr初始化完成
  
  //物理接口
  .ddr3_dq      (ddr3_dq        ),
  .ddr3_dqs_n   (ddr3_dqs_n     ),
  .ddr3_dqs_p   (ddr3_dqs_p     ),
  .ddr3_addr    (ddr3_addr      ),
  .ddr3_ba      (ddr3_ba        ),
  .ddr3_ras_n   (ddr3_ras_n     ),
  .ddr3_cas_n   (ddr3_cas_n     ),
  .ddr3_we_n    (ddr3_we_n      ),
  .ddr3_reset_n (ddr3_reset_n   ),
  .ddr3_ck_p    (ddr3_ck_p      ),
  .ddr3_ck_n    (ddr3_ck_n      ),
  .ddr3_cke     (ddr3_cke       ),
  .ddr3_cs_n    (ddr3_cs_n      ),
  .ddr3_dm      (ddr3_dm        ),
  .ddr3_odt     (ddr3_odt       )

);




//GMII接口转RGMII接口
gmii_to_rgmii u_gmii_to_rgmii(
    .gmii_rx_clk   (gmii_rx_clk ),  //gmii接收时钟
    .gmii_rx_dv    (gmii_rx_dv  ),  //gmii接收有效信号
    .gmii_rxd      (gmii_rxd    ),  //gmii接收数据
    .gmii_tx_clk   (gmii_tx_clk ),  //gmii发送时钟
    .gmii_tx_en    (gmii_tx_en  ),  //gmii发送有效信号
    .gmii_txd      (gmii_txd    ),  //gmii发送数据

    .rgmii_rxc     (clk_phase   ),  //rgmii接收时钟
    .rgmii_rx_ctl  (eth_rx_ctl  ),  //rgmii接收有效信号
    .rgmii_rxd     (eth_rxd     ),  //rgmii接收数据
    .rgmii_txc     (eth_txc     ),  //rgmii发送时钟
    .rgmii_tx_ctl  (eth_tx_ctl  ),  //rgmii发送有效信号
    .rgmii_txd     (eth_txd     )   //rgmii发送数据
    );


//UDP通信
udp                                             
   #(
    .BOARD_MAC     (BOARD_MAC   ),      //参数例化
    .BOARD_IP      (BOARD_IP    ),
    .DES_MAC       (DES_MAC     ),
    .DES_IP        (DES_IP      )
    )
   u_udp(
    .rst_n         (rst_n       ),  //UDP模块复位
    
    .gmii_rx_clk   (gmii_rx_clk ),  //gmii接收时钟
    .gmii_rx_dv    (gmii_rx_dv  ),  //gmii接收有效信号
    .gmii_rxd      (gmii_rxd    ),  //gmii接收数据
    .gmii_tx_clk   (gmii_tx_clk ),  //gmii发送时钟
    .gmii_tx_en    (gmii_tx_en  ),  //gmii发送有效信号
    .gmii_txd      (gmii_txd    ),  //gmii发送数据

    .rec_pkt_done  (rec_pkt_done),  //UDP单包数据接收完成信号
    .rec_en        (rec_en      ),  //UDP接收的数据使能信号
    .rec_data      (rec_data    ),  //UDP接收的数据
    .rec_byte_num  (rec_byte_num),  //UDP接收的有效字节数 单位:byte
    .tx_start_en   (eth_tx_start),  //UDP发送开始
    .tx_data       (eth_tx_data ),  //UDP待发送数据
    .tx_byte_num   (eth_tx_data_num),  //UDP发送的有效字节数
    .des_mac       (des_mac     ),  //PC_MAC
    .des_ip        (des_ip      ),  //PC_IP
    .tx_done       (udp_tx_done ),  //UDP发送完成信号
    .tx_req        (tx_req      )   //UDP读数据请求信号
    ); 

assign  eth_tx_start    = (i_config_end == 1'b1) ? eth_tx_start_i : eth_tx_start_f;
assign  eth_tx_data     = (i_config_end == 1'b1) ? eth_tx_data_i  : eth_tx_data_f;
assign  eth_tx_data_num = (i_config_end == 1'b1) ? eth_tx_data_num_i : eth_tx_data_num_f;

image_format    image_format_inst
(
    .sys_clk            (gmii_tx_clk            ),  //系统时钟
    .sys_rst_n          (rst_n                  ),  //系统复位，低电平有效
    .eth_tx_req         (tx_req&&(~i_config_end)),  //以太网数据请求信号
    .eth_tx_done        (udp_tx_done            ),  //单包以太网数据发送完成信号

    .eth_tx_start       (eth_tx_start_f         ),  //以太网发送数据开始信号
    .eth_tx_data        (eth_tx_data_f          ),  //以太网发送数据
    .i_config_end       (i_config_end           ),  //图像格式包发送完成
    .eth_tx_data_num    (eth_tx_data_num_f      )   //以太网单包数据有效字节数
);

//------------- image_data_inst -------------

image_data
#(
    .H_PIXEL            (H_PIXEL            ),  //图像水平方向像素个数
    .V_PIXEL            (V_PIXEL            )   //图像竖直方向像素个数
)
image_data_inst
(
    .sys_clk            (gmii_tx_clk        ),  //系统时钟,频率25MHz
    .sys_rst_n          (rst_n && i_config_end),  //复位信号,低电平有效
    .image_data         (rd_data            ),  //自DDR中读取的16位图像数据
    .eth_tx_req         (tx_req             ),  //以太网发送数据请求信号
    .eth_tx_done        (udp_tx_done        ),  //以太网发送数据完成信号

    .data_rd_req_f      ( rd_en             ),  //图像数据请求信号 rd_en
    .eth_tx_start       (eth_tx_start_i     ),  //以太网发送数据开始信号
    .eth_tx_data        (eth_tx_data_i      ),  //以太网发送数据
    .eth_tx_data_num    (eth_tx_data_num_i  )   //以太网单包数据有效字节数
);


endmodule