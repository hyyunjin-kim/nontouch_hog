`timescale 1ns / 1ps


module OV7670_VGA_Display (
    // global signals
    input  logic       clk,
    input  logic       rst,
    // ov7670 signals
    output logic       ov7670_xclk,
    input  logic       ov7670_pclk,
    input  logic       ov7670_href,
    input  logic       ov7670_v_sync,
    input  logic [7:0] ov7670_data,
    // export signals
    output logic       h_sync,
    output logic       v_sync,
    output logic [4:0] gray_red,
    output logic [5:0] gray_green,
    output logic [4:0] gray_blue,
    // SCCB
    output logic SCL,
    output logic SDA
    // isp
    // input  logic       sw_upscale
    // input  logic [3:0] sw_red,
    // input  logic [3:0] sw_green,
    // input  logic [3:0] sw_blue,
    //input  logic       sw_gray
);
    logic        we;
    logic [16:0] wAddr;
    logic [15:0] wData;
    logic [16:0] rAddr;
    logic [15:0] rData;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic        DE;
    logic w_rclk, rclk;
    logic d_en;
    //logic [3:0] w_red_port, w_green_port, w_blue_port, gray_red, gray_green, gray_blue;
    logic [4:0] w_red_port, w_blue_port;
    logic [5:0] w_green_port;
    logic sccb_start;


    xclk_gen U_xclk_gen (
        .clk  (clk),
        .reset(rst),
        .xclk (xclk)
    );
    assign ov7670_xclk = xclk;

    // pix_clk_gen U_OV7670_Clk_Gen (
    //     .clk (clk),
    //     .rst (rst),
    //     .pclk(ov7670_xclk)
    // );
    VGA_Controller U_VGA_Controller (
        .clk(clk),
        .rst(rst),
        .rclk(w_rclk),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel)
    );
    OV7670_MemController U_OV7670_MemController (
        .pclk(ov7670_pclk),
        .rst(rst),
        .href(ov7670_href),
        .v_sync(ov7670_v_sync),
        .ov7670_data(ov7670_data),
        .we(we),
        .wAddr(wAddr),
        .wData(wData)
    );
    frame_buffer U_frame_buffer (
        .wclk(ov7670_pclk),
        .we(we),
        .wAddr(wAddr),
        .rclk(rclk),
        .oe(d_en),
        .wData(wData),
        .rAddr(rAddr),
        .rData(rData)
    );
    QVGA_MemController U_QVGA_MemController (
        .clk       (w_rclk),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .DE        (DE),
        .rclk      (rclk),
        .d_en      (d_en),
        .rAddr     (rAddr),
        .rData     (rData),
        .red_port  (w_red_port),
        .green_port(w_green_port),
        .blue_port (w_blue_port)
        // .sw        (sw_upscale)
        // .sw_red    (sw_red),
        // .sw_green  (sw_green),
        // .sw_blue   (sw_blue)
    );

    grayscale_controller U_grayscale_controller (
        .red_port       (w_red_port),
        .green_port     (w_green_port),
        .blue_port      (w_blue_port),
        .gray_red_port  (gray_red),
        .gray_green_port(gray_green),
        .gray_blue_port (gray_blue)
    );

    SCCB_intf U_SCCB_intf(
        .clk(clk),
        .reset(rst),
        .startSig(sccb_start),
        .SCL(SCL),
        .SDA(SDA)
    );

    sccb_start_gen U_sccb_start_gen(
        .clk(clk),
        .reset(rst),
        .sccb_start(sccb_start)
    );


endmodule


module grayscale_controller (
    input  logic [4:0] red_port,
    input  logic [5:0] green_port,
    input  logic [4:0] blue_port,
    output logic [4:0] gray_red_port,
    output logic [5:0] gray_green_port,
    output logic [4:0] gray_blue_port
);
    reg [13:0] gray = red_port * 77 + green_port * 150 + blue_port * 29;

    assign {gray_red_port, gray_green_port, gray_blue_port} = {
        gray[13:9], gray[13:8], gray[13:9]
    };

endmodule
