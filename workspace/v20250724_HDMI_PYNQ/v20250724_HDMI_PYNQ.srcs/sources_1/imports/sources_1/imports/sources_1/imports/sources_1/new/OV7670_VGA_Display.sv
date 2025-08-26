`timescale 1ns / 1ps

module OV7670_VGA_Display (
    // global signals
    input  logic       clk,
    input  logic       reset,
    input  logic       sw_gray,
    input  logic       sw_upscale,
    // filter signals
    // input  logic       sw_red,
    // input  logic       sw_green,
    // input  logic       sw_blue,
    // input  logic       sw_gray,
    // input  logic       sw_upscale,
    // ov7670 signals
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_v_sync,
    input  logic [7:0] ov7670_data,
    output logic       ov7670_scl,
    output logic       ov7670_sda,
    // VGA export
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

    logic        we;
    logic [16:0] wAddr;
    logic [15:0] wData;
    //logic [16:0] rAddr;
    logic [15:0] rData;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic        DE;
    logic        sccb_start;

    logic        oe;  // frame_buffer의 .oe 포트 (MUX 결과)
    logic [16:0] rAddr;  // frame_buffer의 .rAddr 포트 (MUX 결과)


    //-------------------------------------------------------------------------------------------------------//
    // filter for VGA output (to Monitor)
    // 원 데이터 비트폭
    // 원 데이터 비트폭
    logic [4:0] red_data;    // 5bit
    logic [5:0] green_data;  // 6bit
    logic [4:0] blue_data;   // 5bit

    // Grayscale 변환용 비트폭 (곱셈 결과에 맞게)
    logic [11:0] red_to_gray;     // 5bit * 7bit = 12bit 필요
    logic [13:0] green_to_gray;   // 6bit * 8bit = 14bit 필요
    logic [9:0]  blue_to_gray;    // 5bit * 6bit = 10bit 필요

    logic [14:0] gray_sum;        // 15bit 필요: 12 + 14 + 10 → 15bit 안전
    logic [7:0]  gray8;           // 최종 8bit Grayscale

    // Grayscale 변환 (가중치: R77, G150, B29)
    assign red_to_gray   = red_data   * 12'd77;
    assign green_to_gray = green_data * 14'd150;
    assign blue_to_gray  = blue_data  * 10'd29;

    assign gray_sum = red_to_gray + green_to_gray + blue_to_gray;
    assign gray8    = gray_sum[14:7];  // 상위 8bit 사용

    // VGA 5:6:5 bit로 매핑
    assign red_port   = sw_gray ? gray8[7:3] : red_data;
    assign green_port = sw_gray ? gray8[7:2] : green_data;
    assign blue_port  = sw_gray ? gray8[7:3] : blue_data;

    // HDMI 8:8:8 wire
    logic [23:0] w_rgb888;
    // HDMI gray
    logic [23:0] gray_rgb888;
    assign gray_rgb888 = {gray8, gray8, gray8};

    logic [23:0] hdmi_rgb888;
    assign hdmi_rgb888 = sw_gray ? gray_rgb888 : w_rgb888;

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

    logic clk_250MHz;
    logic clk_locked;
    logic reset_sync;
    assign reset_sync = reset | ~clk_locked;
    //-----------------------------------------------------------------------------------------------------------------------//

    pixel_clk_gen U_OV7670_Clk_Gen (
        .clk  (clk),
        .reset(reset),
        .pclk (ov7670_xclk)
    );

    VGA_Controller U_VGAController (
        .clk    (clk),
        .reset  (reset),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .DE     (DE),
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
        .DE        (DE),
        // frame buffer side
        .d_en      (oe),
        .rAddr     (rAddr),
        .rData     (rData),
        // export side
        .red_port  (red_data),
        .green_port(green_data),
        .blue_port (blue_data)
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


//     camera_hdmi_top U_camera_HDMI(
//         .pixel_clk(ov7670_xclk), //25MHz
//         .serial_clk(clk_250MHz), // 250MHz
//         .rst(reset_sync),
//         // Camera input (from OV7670 RGB565 interface)
//         .rgb565_in({red_port, green_port, blue_port}),
//         .hsync(h_sync),
//         .vsync(v_sync),
//         .vde(DE),  // video data enable
//         // TMDS HDMI Output
//         .tmds_clk_p(tmds_clk_p),  // HDMI TMDS 클럭 채널
//         .tmds_clk_n(tmds_clk_n),
//         .tmds_data_p(tmds_data_p), // HDMI TMDS 데이터 채널(R,G,B 각각)
//         .tmds_data_n(tmds_data_n)
// );

    rgb565_go_rgb888 U_rgb888(
        .pixel_clk(ov7670_pclk),
        .red(red_data),
        .green(green_data),
        .blue(blue_data),
        .rgb888(w_rgb888)
    );

    clk_wiz_0 u_clk_250(
        .clk_in1  (ov7670_xclk),  // 입력 클럭
        .clk_out1 (clk_250MHz),   // 출력 클럭
        .reset    (reset),        // reset input
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
