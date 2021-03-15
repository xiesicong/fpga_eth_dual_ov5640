`timescale  1ns/1ns


module  image_format
(
    input   wire            sys_clk     ,   //系统时钟
    input   wire            sys_rst_n   ,   //系统复位，低电平有效
    input   wire            eth_tx_req  ,   //以太网数据请求信号
    input   wire            eth_tx_done ,   //单包以太网数据发送完成信号

    output  reg             eth_tx_start,   //单包以太网发送数据开始信号
    output  reg     [31:0]  eth_tx_data ,   //以太网发送数据
    output  reg             i_config_end,   //图像格式指令包发送完成
    output  reg     [15:0]  eth_tx_data_num //以太网单包数据有效字节数

);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter     define
parameter   HEAD        =   32'h53_5a_48_59     ,   //包头
            ADDR        =   8'h00               ,   //设备地址
            DATA_NUM    =   32'h11_00_00_00     ,   //包长
            CMD         =   8'h01               ,   //指令
            FORMAT      =   8'h04               ,   //图像格式(RGB565)
            H_PIXEL     =   16'h80_02           ,   //行像素个数
            V_PIXEL     =   16'hE0_01           ,   //场像素个数
            CRC         =   16'h7C_0B           ;   //CRC-16校验

parameter   IDLE        =   4'b0001,    //初始状态
            CMD_SEND    =   4'b0010,    //发送格式配置
            CYCLE       =   4'b0100,    //循环配置
            END         =   4'b1000;    //结束

parameter   CNT_START_MAX   =   32'd125_000_00; //初始状态等待时钟周期数

//wire  define
wire    [31:0]  data_mem    [4:0]   ;   //待发送指令

//reg   define
reg     [3:0]   state       ;   //状态机状态
reg     [31:0]  cnt_start   ;   //初始状态等待计数器
reg     [3:0]   cnt_data    ;   //发送数据个数计数
reg     [15:0]  cnt_cycle   ;   //循环配置次数计数

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//data_mem:待发送指令
assign  data_mem[0]  =  HEAD;
assign  data_mem[1]  =  {ADDR,DATA_NUM[31:8]};
assign  data_mem[2]  =  {DATA_NUM[7:0],CMD,FORMAT,H_PIXEL[15:8]};
assign  data_mem[3]  =  {H_PIXEL[7:0],V_PIXEL,CRC[15:8]};
assign  data_mem[4]  =  {CRC[7:0],24'b0};

//state:状态机状态
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  IDLE;
    else    case(state)
        IDLE:
            if(cnt_start == CNT_START_MAX)
                state   <=  CMD_SEND;
            else
                state   <=  IDLE;
        CMD_SEND:
            if((cnt_data == 4'd5) && (eth_tx_done == 1'b1))
                state   <=  CYCLE;
            else
                state   <=  CMD_SEND;
        CYCLE:
            if(cnt_cycle == 16'd10)
                state   <=  END;
            else
                state   <=  IDLE;
        END:    state   <=  END;
        default:state   <=  IDLE;
    endcase

//cnt_start:初始状态等待计数器
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_start   <=  16'd0;
    else    if(state == IDLE)
        if(cnt_start < CNT_START_MAX)
            cnt_start   <=  cnt_start + 1'b1;
        else
            cnt_start   <=  16'd0;
    else
        cnt_start   <=  16'd0;

//eth_tx_start:以太网发送数据开始信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        eth_tx_start    <=  1'b0;
    else    if(cnt_start == CNT_START_MAX)
        eth_tx_start    <=  1'b1;
    else
        eth_tx_start    <=  1'b0;

//cnt_data:发送数据个数计数
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_data <= 4'd0;
    else    if(state == IDLE)
        cnt_data <= 4'd0;
    else    if(eth_tx_req == 1'b1)
        cnt_data <= cnt_data + 1'b1;
    else
        cnt_data <= cnt_data;

//eth_tx_data:以太网发送数据
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        eth_tx_data <=  32'h0;
    else    if(state == IDLE)
        eth_tx_data <=  32'h0;
    else    if(eth_tx_req == 1'b1)
        eth_tx_data <=  data_mem[cnt_data];
    else
        eth_tx_data <=  eth_tx_data;

//cnt_cycle:循环配置次数计数
always @(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_cycle   <=  16'd0;
    else    if(state == END)
        cnt_cycle   <=  16'd0;
    else    if((eth_tx_done == 1'b1) && (cnt_cycle < 16'd10))
        cnt_cycle   <=  cnt_cycle + 1'b1;
    else
        cnt_cycle   <=  cnt_cycle;

//i_config_end:图像格式配置完成
always @(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        i_config_end  <=  1'b0;
    else    if(state == END)
        i_config_end  <=  1'b1;
    else
        i_config_end  <=  1'b0;

//eth_tx_data_num:以太网单包数据有效字节数
always @(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        eth_tx_data_num <=  16'd0;
    else
        eth_tx_data_num <=  16'd17;

endmodule
