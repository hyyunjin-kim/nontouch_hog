`timescale 1ns / 1ps

module OV7670_VGA_Display (
    // global signals
    input  logic       clk,
    input  logic       reset,
    input  logic       sw_gray,
    input  logic       sw_upscale,
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_v_sync,
    input  logic [7:0] ov7670_data,
    output logic       ov7670_scl,
    output logic       ov7670_sda,
    input  logic [8:0] hand_x,
    input  logic [7:0] hand_y,
    input  logic       hand_motion,
    // export
    output logic       h_sync,
    output logic       v_sync,
    output logic [4:0] red_port,
    output logic [5:0] green_port,
    output logic [4:0] blue_port,
    // output logic [7:0] gray_out,
    output logic [9:0] x_OV,
    output logic [9:0] y_OV,
      // Frame Buffer 포트 B (읽기 전용)
//   input logic [16:0] fb_addr,    // y_cur*WIDTH + x_cur
//   output  logic [7:0]  fb_gray,    // BRAM에서 읽혀 들어오는 픽셀

  output logic DE,
  output logic VGA_DE
);
    logic        we;
    logic [16:0] wAddr;
    logic [15:0] wData;
    //logic [16:0] rAddr;
    logic [15:0] rData;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    //logic        DE;
    logic        sccb_start;

    logic        oe;  // frame_buffer의 .oe 포트 (MUX 결과)
    logic [16:0] rAddr;  // frame_buffer의 .rAddr 포트 (MUX 결과)


    assign DE = oe;
    
    //-------------------------------------------------------------------------------------------------------//
    // filter for VGA output (to Monitor)
    // 원 데이터 비트폭
    // 원 데이터 비트폭




    // Grayscale 변환 (가중치: R77, G150, B29)


    // VGA 5:6:5 bit로 매핑
    // assign red_port   = red_data;
    // assign green_port = green_data;
    // assign blue_port  = blue_data;

   
    //--------------------------------------------------------------------------------------------------------------//

    // Upscale logic
    logic [9:0] x_pixel_up;
    logic [9:0] y_pixel_up;
    assign x_pixel_up = {1'b0, x_pixel[9:1]};
    assign y_pixel_up = {1'b0, y_pixel[9:1]};

    logic [9:0] x_pixel_mem;
    logic [9:0] y_pixel_mem;
    
    assign x_pixel_mem = (sw_upscale) ? x_pixel_up : x_pixel;
    assign y_pixel_mem = (sw_upscale) ? y_pixel_up : y_pixel;

    //-----------------------------------------------------------------------------------------------------------------------//

    pixel_clk_gen UOV7670_Clk_Gen (
        .clk  (clk),
        .reset(reset),
        .pclk (ov7670_xclk)
    );

    VGA_Controller U_VGAController (
        .clk    (clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (VGA_DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );

    OV7670_MemController U_OV7670_MemComtroller (
        .pclk       (ov7670_pclk),
        .reset      (reset),
        .href       (ov7670_href),
        .v_sync     (ov7670_v_sync),
        .ov7670_data(ov7670_data),
        .we         (we),
        .wAddr      (wAddr),
        .wData      (wData)
    );

    frame_buffer U_CaptureBuffer (
        .reset     (reset),
        .wclk      (ov7670_pclk),
        .we        (we),
        .wAddr     (wAddr),
        .wData     (wData),
        .rclk      (clk),
        .oe        (oe),
        .rAddr     (rAddr),
        .rData     (rData)
    );

    QVGA_MemController U_QVGA_MemController (
        .clk       (clk),
        .x_pixel   (x_pixel_mem),
        .y_pixel   (y_pixel_mem),
        .hand_x(hand_x),
        .hand_y(hand_y),
        .hand_motion(hand_motion),

        // frame buffer side
        .d_en      (oe),
        .rAddr     (rAddr),
        .rData     (rData),
        // export side
        .x_OV(x_OV),
        .y_OV(y_OV),
        .red_out (red_port),
        .green_out(green_port),
        .blue_out (blue_port)
    );

    SCCB_intf u_sccb (
        .clk(clk),
        .reset(reset),
        .startSig(sccb_start),
        .SCL(ov7670_scl),
        .SDA(ov7670_sda)
    );

    sccb_start_generator u_start_gen (
        .clk(clk),
        .reset(reset),
        .startSig(sccb_start)
    );


// assign x_OV = x_pixel>>1;
// assign y_OV = y_pixel>>1;
endmodule
