`timescale  1ns/1ns


module udp(
    input                rst_n       , //复位信号，低电平有效
    //GMII接口
    input                gmii_rx_clk , //GMII接收数据时钟
    input                gmii_rx_dv  , //GMII输入数据有效信号
    input        [7:0]   gmii_rxd    , //GMII输入数据
    input                gmii_tx_clk , //GMII发送数据时钟    
    output               gmii_tx_en  , //GMII输出数据有效信号
    output       [7:0]   gmii_txd    , //GMII输出数据 
    //用户接口
    output               rec_pkt_done, //以太网单包数据接收完成信号
    output               rec_en      , //以太网接收的数据使能信号
    output       [31:0]  rec_data    , //以太网接收的数据
    output       [15:0]  rec_byte_num, //以太网接收的有效字节数 单位:byte     
    input                tx_start_en , //以太网开始发送信号
    input        [31:0]  tx_data     , //以太网待发送数据  
    input        [15:0]  tx_byte_num , //以太网发送的有效字节数 单位:byte  
    input        [47:0]  des_mac     , //发送的目标MAC地址
    input        [31:0]  des_ip      , //发送的目标IP地址    
    output               tx_done     , //以太网发送完成信号
    output               tx_req        //读数据请求信号    
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

//wire define
wire          crc_en  ; //CRC开始校验使能
wire          crc_clr ; //CRC数据复位信号 
wire  [7:0]   crc_d8  ; //输入待校验8位数据

wire  [31:0]  crc_data; //CRC校验数据
wire  [31:0]  crc_next; //CRC下次校验完成数据

//*****************************************************
//**                    main code
//*****************************************************

assign  crc_d8 = gmii_txd;  //将要发送的数据赋值给CRC校验

//以太网接收模块    
udp_rx 
   #(
    .BOARD_MAC       (BOARD_MAC),         //参数例化
    .BOARD_IP        (BOARD_IP )
    )
   u_udp_rx(
    .clk             (gmii_rx_clk ),    //时钟信号
    .rst_n           (rst_n       ),    //复位信号,低电平有效
    .gmii_rx_dv      (gmii_rx_dv  ),    //数据有效信号
    .gmii_rxd        (gmii_rxd    ),    //输入数据
    .rec_pkt_done    (rec_pkt_done),    //数据包接收完成信号
    .rec_en          (rec_en      ),    //数据接收使能信号
    .rec_data        (rec_data    ),    //接收数据
    .rec_byte_num    (rec_byte_num)     //接收数据字节数
    );

//以太网发送模块
udp_tx
   #(
    .BOARD_MAC       (BOARD_MAC),         //参数例化
    .BOARD_IP        (BOARD_IP ),
    .DES_MAC         (DES_MAC  ),
    .DES_IP          (DES_IP   )
    )
   u_udp_tx(
    .clk             (gmii_tx_clk), //时钟信号
    .rst_n           (rst_n      ), //复位信号,低电平有效
    .tx_start_en     (tx_start_en), //数据发送开始信号
    .tx_data         (tx_data    ), //发送数据
    .tx_byte_num     (tx_byte_num), //发送数据有效字节数
    .des_mac         (des_mac    ), //PC_MAC
    .des_ip          (des_ip     ), //PC_IP
    .crc_data        (crc_data   ), //CRC校验数据
    .crc_next        (crc_next[31:24]), //CRC下次校验完成数据
    .tx_done         (tx_done    ), //单包数据发送完成标志信号
    .tx_req          (tx_req     ), //读使能信号
    .gmii_tx_en      (gmii_tx_en ), //输出数据有效信号
    .gmii_txd        (gmii_txd   ), //输出数据
    .crc_en          (crc_en     ), //CRC开始校验使能
    .crc_clr         (crc_clr    )  //crc复位信号
    );

//以太网发送CRC校验模块
crc32_d8   u_crc32_d8(
    .clk             (gmii_tx_clk), //时钟信号
    .rst_n           (rst_n      ), //复位信号,低电平有效
    .data            (crc_d8     ), //待校验数据
    .crc_en          (crc_en     ), //crc使能,校验开始标志
    .crc_clr         (crc_clr    ), //crc数据复位信号
    .crc_data        (crc_data   ), //CRC校验数据
    .crc_next        (crc_next   )  //CRC下次校验完成数据
    );

endmodule