`timescale  1ns/1ns


module udp(
    input                rst_n       , //��λ�źţ��͵�ƽ��Ч
    //GMII�ӿ�
    input                gmii_rx_clk , //GMII��������ʱ��
    input                gmii_rx_dv  , //GMII����������Ч�ź�
    input        [7:0]   gmii_rxd    , //GMII��������
    input                gmii_tx_clk , //GMII��������ʱ��    
    output               gmii_tx_en  , //GMII���������Ч�ź�
    output       [7:0]   gmii_txd    , //GMII������� 
    //�û��ӿ�
    output               rec_pkt_done, //��̫���������ݽ�������ź�
    output               rec_en      , //��̫�����յ�����ʹ���ź�
    output       [31:0]  rec_data    , //��̫�����յ�����
    output       [15:0]  rec_byte_num, //��̫�����յ���Ч�ֽ��� ��λ:byte     
    input                tx_start_en , //��̫����ʼ�����ź�
    input        [31:0]  tx_data     , //��̫������������  
    input        [15:0]  tx_byte_num , //��̫�����͵���Ч�ֽ��� ��λ:byte  
    input        [47:0]  des_mac     , //���͵�Ŀ��MAC��ַ
    input        [31:0]  des_ip      , //���͵�Ŀ��IP��ַ    
    output               tx_done     , //��̫����������ź�
    output               tx_req        //�����������ź�    
    );

//parameter define
//������MAC��ַ 12_34_56_78_9a_bc
parameter  BOARD_MAC = 48'h12_34_56_78_9a_bc;     
//������IP��ַ 192.168.0.234
parameter  BOARD_IP  = {8'd192,8'd168,8'd0,8'd234};  
//Ŀ��MAC��ַ ff_ff_ff_ff_ff_ff
parameter  DES_MAC   = 48'hff_ff_ff_ff_ff_ff;    
//Ŀ��IP��ַ 192.168.0.145     
parameter  DES_IP    = {8'd192,8'd168,8'd0,8'd145};  

//wire define
wire          crc_en  ; //CRC��ʼУ��ʹ��
wire          crc_clr ; //CRC���ݸ�λ�ź� 
wire  [7:0]   crc_d8  ; //�����У��8λ����

wire  [31:0]  crc_data; //CRCУ������
wire  [31:0]  crc_next; //CRC�´�У���������

//*****************************************************
//**                    main code
//*****************************************************

assign  crc_d8 = gmii_txd;  //��Ҫ���͵����ݸ�ֵ��CRCУ��

//��̫������ģ��    
udp_rx 
   #(
    .BOARD_MAC       (BOARD_MAC),         //��������
    .BOARD_IP        (BOARD_IP )
    )
   u_udp_rx(
    .clk             (gmii_rx_clk ),    //ʱ���ź�
    .rst_n           (rst_n       ),    //��λ�ź�,�͵�ƽ��Ч
    .gmii_rx_dv      (gmii_rx_dv  ),    //������Ч�ź�
    .gmii_rxd        (gmii_rxd    ),    //��������
    .rec_pkt_done    (rec_pkt_done),    //���ݰ���������ź�
    .rec_en          (rec_en      ),    //���ݽ���ʹ���ź�
    .rec_data        (rec_data    ),    //��������
    .rec_byte_num    (rec_byte_num)     //���������ֽ���
    );

//��̫������ģ��
udp_tx
   #(
    .BOARD_MAC       (BOARD_MAC),         //��������
    .BOARD_IP        (BOARD_IP ),
    .DES_MAC         (DES_MAC  ),
    .DES_IP          (DES_IP   )
    )
   u_udp_tx(
    .clk             (gmii_tx_clk), //ʱ���ź�
    .rst_n           (rst_n      ), //��λ�ź�,�͵�ƽ��Ч
    .tx_start_en     (tx_start_en), //���ݷ��Ϳ�ʼ�ź�
    .tx_data         (tx_data    ), //��������
    .tx_byte_num     (tx_byte_num), //����������Ч�ֽ���
    .des_mac         (des_mac    ), //PC_MAC
    .des_ip          (des_ip     ), //PC_IP
    .crc_data        (crc_data   ), //CRCУ������
    .crc_next        (crc_next[31:24]), //CRC�´�У���������
    .tx_done         (tx_done    ), //�������ݷ�����ɱ�־�ź�
    .tx_req          (tx_req     ), //��ʹ���ź�
    .gmii_tx_en      (gmii_tx_en ), //���������Ч�ź�
    .gmii_txd        (gmii_txd   ), //�������
    .crc_en          (crc_en     ), //CRC��ʼУ��ʹ��
    .crc_clr         (crc_clr    )  //crc��λ�ź�
    );

//��̫������CRCУ��ģ��
crc32_d8   u_crc32_d8(
    .clk             (gmii_tx_clk), //ʱ���ź�
    .rst_n           (rst_n      ), //��λ�ź�,�͵�ƽ��Ч
    .data            (crc_d8     ), //��У������
    .crc_en          (crc_en     ), //crcʹ��,У�鿪ʼ��־
    .crc_clr         (crc_clr    ), //crc���ݸ�λ�ź�
    .crc_data        (crc_data   ), //CRCУ������
    .crc_next        (crc_next   )  //CRC�´�У���������
    );

endmodule