`timescale 1ns / 1ps
//NEW


module Top_FPGA(
    input  logic       clk,
    input  logic       reset,
    input  logic       sw_gray,
    input  logic       sw_upscale,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_v_sync,
    input  logic [7:0] ov7670_data,
    output logic        tx_out,
    output logic       ov7670_scl,
    output logic       ov7670_sda,
    output logic        ov7670_xclk,

    // output logic       h_sync,
    // output logic       v_sync,
    // output logic [4:0] red_port,
    // output logic [5:0] green_port,
    // output logic [4:0] blue_port,

    // HDMI TMDS Output
    output logic        tmds_clk_p,
    output logic        tmds_clk_n,
    output logic [2:0]  tmds_data_p,
    output logic [2:0]  tmds_data_n    
    );

logic [9:0] x_in;
logic [9:0] y_in;
logic [7:0] gray;
// logic h_sync;
// logic v_sync;

logic [8:0] obj_x;
logic [7:0] obj_y;
logic hand_motion;
logic [16:0] fb_addr;
logic [7:0]  fb_gray;

    logic DE;
    logic clk_250MHz;
    logic clk_locked;
    logic reset_sync;
    assign reset_sync = reset | ~clk_locked;
    // HDMI 8:8:8 wire
    logic [23:0] w_rgb888;
    // HDMI gray
    logic [7:0]  gray8;
    logic [23:0] gray_rgb888;
    assign gray_rgb888 = {gray8, gray8, gray8};

    logic [23:0] hdmi_rgb888;
    assign hdmi_rgb888 = sw_gray ? gray_rgb888 : w_rgb888;

    logic [4:0] w_red_data;    // 5bit
    logic [5:0] w_green_data;  // 6bit
    logic [4:0] w_blue_data;   // 5bit

    logic       h_sync;
    logic       v_sync;

Detection_Algorithm U_Detection_Algorithm(
    .clk(clk),
    .reset(reset),
    .x_in(x_in),
    .y_in(y_in),
    .gray_in(gray),
    .tx_out(tx_out),
    .hand_x_vga(obj_x),
    .hand_y_vga(obj_y),
    .hand_gesture(hand_motion),
    .fb_addr(fb_addr),
    .fb_gray(fb_gray)
);

OV7670_VGA_Display U_OV7670(
    // global signals
    .clk(clk),
    .reset(reset),
    .sw_gray(sw_gray),
    .sw_upscale(sw_upscale),
    .ov7670_xclk(ov7670_xclk),
    .ov7670_pclk(ov7670_pclk),
    .ov7670_href(ov7670_href),
    .ov7670_v_sync(ov7670_v_sync),
    .ov7670_data(ov7670_data),
    .ov7670_scl(ov7670_scl),
    .ov7670_sda(ov7670_sda),
    .hand_x(obj_x),
    .hand_y(obj_y),
    .hand_motion(hand_motion),
    .h_sync(h_sync),
    .v_sync(v_sync),
    .red_port(w_red_data),
    .green_port(w_green_data),
    .blue_port(w_blue_data),
    .gray_out(gray8),
    .x_OV(x_in),
    .y_OV(y_in),
    .fb_addr(fb_addr),
    .fb_gray(fb_gray),
    .DE(DE)
);

    rgb565_go_rgb888 U_rgb888(
        .pixel_clk(ov7670_pclk),
        .red(w_red_data),
        .green(w_green_data),
        .blue(w_blue_data),
        .rgb888(w_rgb888)
    );

    clk_wiz_0 u_clk_250(
        .clk_in1  (ov7670_xclk),  // 입력 클럭
        .clk_out1 (clk_250MHz),   // 출력 클럭
        .locked   (clk_locked)    // lock 상태 output
    );

    rgb2dvi #(
        .kGenerateSerialClk(1'b0), // 내부 시리얼 클럭 생성 안 함 (우리는 clk_wiz로 생성)
        .kClkPrimitive("PLL"),     // 사용하지 않음 (내부 클럭 생성 OFF)
        .kClkRange(1),             // 120MHz 이상이므로 1
        .kRstActiveHigh(1'b1),
        .kD0Swap(1'b0),
        .kD1Swap(1'b0),
        .kD2Swap(1'b0),
        .kClkSwap(1'b0)
        ) u_rgb2dvi (
        // TMDS Outputs
        .TMDS_Clk_p    (tmds_clk_p),
        .TMDS_Clk_n    (tmds_clk_n),
        .TMDS_Data_p   (tmds_data_p),
        .TMDS_Data_n   (tmds_data_n),

        // Reset (Active High)
        .aRst          (reset_sync),
        .aRst_n        (),  // 사용하지 않음

        // Video Input (RGB888)
        .vid_pData     (hdmi_rgb888), // {8,8,8}
        .vid_pVDE      (DE),           // Video Data Enable
        .vid_pHSync    (h_sync),       // 수평 동기
        .vid_pVSync    (v_sync),       // 수직 동기
        .PixelClk      (ov7670_xclk),  // 25MHz 픽셀 클럭
        .SerialClk     (clk_250MHz)    // 250MHz 직렬 전송용 클럭
    );
endmodule
