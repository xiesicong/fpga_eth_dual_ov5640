`timescale  1ns/1ns


module  image_data
#(
    parameter   H_PIXEL =   11'd640     ,   //图像水平方向像素个数
    parameter   V_PIXEL =   11'd480     ,   //图像竖直方向像素个数
    parameter   CNT_FRAME_WAIT = 24'h50_FF_FF , //单帧图像等待时间计数 h0E_FF_FF
    parameter   CNT_IDLE_WAIT  = 24'h00_10_49   //单包数据等待时间计数 h00_01_99 
)

(
    input   wire            sys_clk     ,   //系统时钟,频率25MHz
    input   wire            sys_rst_n   ,   //复位信号,低电平有效
    input   wire    [15:0]  image_data  ,   //自SDRAM中读取的16位图像数据
    input   wire            eth_tx_req  ,   //以太网发送数据请求信号
    input   wire            eth_tx_done ,   //以太网发送数据完成信号

    output  reg             data_rd_req_f , //图像数据请求信号
    output  reg             eth_tx_start,   //以太网发送数据开始信号
    output  wire    [31:0]  eth_tx_data ,   //以太网发送数据
    output  reg     [15:0]  eth_tx_data_num //以太网单包数据有效字节数
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
parameter   IDLE        =   6'b0000_01, //初始状态
            FIRST_BAG   =   6'b0000_10, //发送第一包数据(包含包头)
            COM_BAG     =   6'b0001_00, //发送普通包数据
            LAST_BAG    =   6'b0010_00, //发送最后一包数据(包含CRC-16)
            BAG_WAIT    =   6'b0100_00, //单包数据发送完成等待
            FRAME_END   =   6'b1000_00; //一帧图像发送完成等待

//wire  define
wire            fifo_empty      ;   //FIFO读空信号
wire            fifo_empty_fall ;   //FIFO读空信号下降沿

//reg       define
reg     [5:0]   state           ;   //状态机状态
reg     [23:0]  cnt_idle_wait   ;   //初始状态即单包间隔等待时间计数
reg     [10:0]  cnt_h           ;   //单包数据包含像素个数计数(一行图像)
reg             data_rd_req1    ;
reg             data_rd_req2    ;
reg             data_rd_req3    ;
reg             data_rd_req4    ;
reg             data_rd_req5    ;
reg             data_rd_req6    ;   //图像数据请求信号打拍(插入包头和CRC)
reg     [15:0]  image_data1     ;
reg     [15:0]  image_data2     ;
reg     [15:0]  image_data3     ;
reg     [15:0]  image_data4     ;
reg     [15:0]  image_data5     ;
reg     [15:0]  image_data6     ;   //图像数据打拍(目的是插入包头和CRC)
reg             data_valid      ;   //图像数据有效信号
reg             wr_fifo_en      ;   //FIFO写使能
reg     [15:0]  cnt_wr_data     ;   //写入FIFO数据个数(单位2字节)
reg     [31:0]  wr_fifo_data    ;   //写入FIFO数据
reg             fifo_empty_reg  ;   //fifo读空信号打一拍
reg     [10:0]  cnt_v           ;   //一帧图像发送包个数(一帧图像行数)
reg     [23:0]  cnt_frame_wait  ;   //单帧图像等待时间计数

//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//
//state:状态机状态变量
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        state   <=  IDLE;
    else    case(state)
        IDLE:
            if(cnt_idle_wait == CNT_IDLE_WAIT)
                state   <=  FIRST_BAG;
            else
                state   <=  IDLE;
        FIRST_BAG:
            if(eth_tx_done == 1'b1)
                state   <=  BAG_WAIT;
            else
                state   <=  FIRST_BAG;
        BAG_WAIT:
            if((cnt_v < V_PIXEL - 11'd1) && 
                (cnt_idle_wait == CNT_IDLE_WAIT))
                state   <=  COM_BAG;
            else    if((cnt_v == V_PIXEL - 11'd1) && 
                        (cnt_idle_wait == CNT_IDLE_WAIT))
                state   <=  LAST_BAG;
            else
                state   <=  BAG_WAIT;
        COM_BAG:
            if(eth_tx_done == 1'b1)
                state   <=  BAG_WAIT;
            else
                state   <=  COM_BAG;
        LAST_BAG:
            if(eth_tx_done == 1'b1)
                state   <=  FRAME_END;
            else
                state   <=  LAST_BAG;
        FRAME_END:
            if(cnt_frame_wait == CNT_FRAME_WAIT)
                state   <=  IDLE;
            else
                state   <=  FRAME_END;
        default:state   <=  IDLE;
    endcase

//cnt_idle_wait:初始状态即单包间隔等待时间计数
reg h_start;
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) begin
        cnt_idle_wait   <=  24'd0;
        h_start<=1'b0;
        end
    else    if(((state == IDLE) || (state == BAG_WAIT)) && (cnt_idle_wait < CNT_IDLE_WAIT)) begin
        cnt_idle_wait   <=  cnt_idle_wait + 1'b1;
        if(cnt_idle_wait==24'd1) begin
        h_start<=1'b1;
        end
        else begin
        h_start<=1'b0;
        end
        end
    else begin
        cnt_idle_wait   <=  24'd0;
        h_start<=1'b0;
        end

//cnt_h:单包数据包含像素个数计数(一行图像)

always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_h   <=  11'd0;
    else    if(cnt_h == 11'd0)
        if(cnt_idle_wait == CNT_IDLE_WAIT)
            cnt_h   <=  H_PIXEL;
        else
            cnt_h   <=  cnt_h;
    else
        cnt_h   <=  cnt_h - 1'b1;

//data_rd_req:图像数据请求信号
reg data_rd_req;
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_rd_req_f     <=  1'b0;
    
    else
        data_rd_req_f     <=data_rd_req;

always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_rd_req     <=  1'b0;
    else    if(cnt_h != 11'd0)
        data_rd_req     <=  1'b1;
    else
        data_rd_req     <=  1'b0;

//图像数据请求信号打拍,插入包头和CRC
always @(posedge sys_clk or negedge sys_rst_n)
    if(!sys_rst_n)
        begin
            data_rd_req1    <=  1'b0;
            data_rd_req2    <=  1'b0;
            data_rd_req3    <=  1'b0;
            data_rd_req4    <=  1'b0;
            data_rd_req5    <=  1'b0;
            data_rd_req6    <=  1'b0;
        end
    else
        begin
            data_rd_req1    <=  data_rd_req;
            data_rd_req2    <=  data_rd_req1;
            data_rd_req3    <=  data_rd_req2;
            data_rd_req4    <=  data_rd_req3;
            data_rd_req5    <=  data_rd_req4;
            data_rd_req6    <=  data_rd_req5;
        end

//图像数据打拍,方便插入包头和CRC
always@(posedge sys_clk or negedge sys_rst_n)
    if(!sys_rst_n)
        begin
            image_data1    <=  16'b0;
            image_data2    <=  16'b0;
            image_data3    <=  16'b0;
            image_data4    <=  16'b0;
            image_data5    <=  16'b0;
            image_data6    <=  16'b0;
        end
    else
        begin
            image_data1    <=  image_data;
            image_data2    <=  image_data1;
            image_data3    <=  image_data2;
            image_data4    <=  image_data3;
            image_data5    <=  image_data4;
            image_data6    <=  image_data5;
        end

//data_valid:图像数据有效信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        data_valid  <=  1'b0;
    else    if(state == FIRST_BAG)
        data_valid  <=  (data_rd_req1 || data_rd_req6);
    else    if(state == LAST_BAG)
        data_valid  <=  (data_rd_req4 || data_rd_req5);
    else
        data_valid  <=  data_rd_req1;

//wr_fifo_en:FIFO写使能
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_fifo_en   <=  1'b0;
    else    if(data_valid == 1'b1)
        wr_fifo_en   <=  ~wr_fifo_en;
    else
        wr_fifo_en   <=  1'b0;

//cnt_wr_data:写入FIFO数据个数
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_wr_data <=  16'd0;
    else    if(data_valid == 1'b1)
        if(wr_fifo_en == 1'b1)
            cnt_wr_data <=  cnt_wr_data + 1'b1;
        else
            cnt_wr_data <=  cnt_wr_data;
    else
        cnt_wr_data <=  16'd0;

//wr_fifo_data:写入FIFO数据
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        wr_fifo_data    <=  32'h0;
    else    if(wr_fifo_en == 1'b0)
        if(state == FIRST_BAG)
            if(cnt_wr_data == 16'd0)
                wr_fifo_data    <=  32'h53_5a_48_59;
            else    if(cnt_wr_data == 16'd1)
                wr_fifo_data    <=  32'h00_0C_60_09;
            else    if(cnt_wr_data == 16'd2)
                wr_fifo_data    <=  {16'h00_02,image_data5};
            else
                wr_fifo_data    <=  {image_data6,image_data5};
        else    if(state == COM_BAG)
            wr_fifo_data    <=  {image_data2,image_data1};
        else    if(state == LAST_BAG)
            if(cnt_wr_data == 16'd320)
                wr_fifo_data    <=  {16'h5A_A5,16'h00_00};
            else
                wr_fifo_data    <=  {image_data4,image_data3};
    else
        wr_fifo_data    <=  wr_fifo_data;

//fifo_empty:FIFO读空信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        fifo_empty_reg   <=  1'b1;
    else
        fifo_empty_reg   <=  fifo_empty;

//fifo_empty_fall:FIFO读空信号下降沿
assign  fifo_empty_fall = ((fifo_empty_reg == 1'b1) && (fifo_empty == 1'b0));

//eth_tx_start:以太网发送数据开始信号
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        eth_tx_start    <=  1'b0;
    else    if(fifo_empty_fall == 1'b1)
        eth_tx_start    <=  1'b1;  
    else
        eth_tx_start    <=  1'b0;

//eth_tx_data_num:以太网单包数据有效字节数
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        eth_tx_data_num     <=  16'd0;
    else    if(state == FIRST_BAG)
        eth_tx_data_num     <=  {H_PIXEL,1'b0} + 16'd10;
    else    if(state == COM_BAG)
        eth_tx_data_num     <=  {H_PIXEL,1'b0};
    else    if(state == LAST_BAG)
        eth_tx_data_num     <=  {H_PIXEL,1'b0} + 16'd2;
    else
        eth_tx_data_num     <=  eth_tx_data_num;

//cnt_v:一帧图像发送包个数(一帧图像行数)
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_v   <=  11'd0;
    else    if(state == IDLE)
        cnt_v   <=  11'd0;
    else    if(eth_tx_done == 1'b1)
        cnt_v   <=  cnt_v + 1'b1;
    else
        cnt_v   <=  cnt_v;

//cnt_frame_wait:单帧图像等待时间计数
reg frame_start;
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0) begin
        cnt_frame_wait  <=  24'd0;
        frame_start<=1'b0;
        end
    else    if((state == FRAME_END) && (cnt_frame_wait < CNT_FRAME_WAIT)) begin
        cnt_frame_wait  <=  cnt_frame_wait + 1'b1;
        if(cnt_frame_wait==24'd1) begin
        frame_start<=1'b1;
        end
        else begin
            frame_start<=1'b0;
        end
    end
    else begin
        cnt_frame_wait  <=  24'd0;
        frame_start<=1'b0;
        end

//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- fifo_image_inst -------------

fifo_generator_0 fifo_image_inst (
  .clk          (sys_clk        ), // input clk
  .srst          (~sys_rst_n     ), // input rst
  .din          (wr_fifo_data   ), // input [31 : 0] din
  .wr_en        (wr_fifo_en     ), // input wr_en
  .rd_en        (eth_tx_req     ), // input rd_en
  .dout         (eth_tx_data    ), // output [31 : 0] dout
  .full         (               ), // output full
  .empty        (fifo_empty     ) // output empty
);

endmodule
