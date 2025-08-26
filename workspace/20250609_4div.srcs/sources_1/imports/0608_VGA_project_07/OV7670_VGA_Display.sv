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
    output logic [3:0] red_port,
    output logic [3:0] green_port,
    output logic [3:0] blue_port,
    // isp
    // input  logic       sw_upscale,
    input  logic       sw_red,
    input  logic       sw_green,
    input  logic       sw_blue,
    // input  logic       sw_gray,
    // input  logic       sw_edge,
    // input  logic       sw_gaussian,
    // input  logic       sw_sharpening,
    input logic [2:0] frame_sw,
    // SCCB
    output logic       SCL,
    inout  logic       SDA,
    // button
    input  logic       btn_U,
    input  logic       btn_D,
    input  logic       btn_L,
    input  logic       btn_R,
    // switch
    input  logic [1:0] sw_q
);
    logic        we;
    logic [16:0] wAddr;
    logic [11:0] wData;
    logic [16:0] rAddr;
    logic [11:0] rData;
    logic [ 9:0] x_pixel;
    logic [ 9:0] y_pixel;
    logic        DE;
    logic w_rclk, rclk;
    logic d_en;
    logic [3:0]
        w_red_port, w_green_port, w_blue_port, gray_red, gray_green, gray_blue;
    logic [11:0] o_gray;
    assign gray_red   = o_gray[11:8];
    assign gray_green = o_gray[11:8];
    assign gray_blue  = o_gray[11:8];
    logic [3:0] edge_red, edge_green, edge_blue;
    logic [11:0] gaussian_out, gaussian_in;
    logic [11:0] sharpen_out;
    logic [ 7:0] sobel_in;
    logic [11:0] sobel_out;
    logic xclk, sccb_start;
    logic [7:0] scan_line;
    logic w_btn_U, w_btn_D, w_btn_L, w_btn_R;
    assign sobel_in = o_gray[11:4];

    assign gaussian_in = {w_red_port, w_green_port, w_blue_port};


    xclk_gen U_xclk_gen (
        .clk  (clk),
        .reset(rst),
        .xclk (xclk)
    );
    assign ov7670_xclk = xclk;


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

    line_counter U_Line_Counter (
        .clk(clk),
        .rst(rst),
        .scan_line(scan_line),
        .btn(w_btn_U || w_btn_D || w_btn_L || w_btn_R)
    );

    logic [2:0] freeze_mode;


    //--------------------------------------------------------------------
    // 1) frame_buffer 4개 인스턴스 + 출력 배열
    //--------------------------------------------------------------------
    logic [11:0] rData_fb       [0:3];  // 사분면별 read data
    logic [2:0]  freeze_mode_fb [0:3];  // 사분면별 freeze_mode

    generate
    for (genvar i = 0; i < 4; i++) begin : G_FB
        frame_buffer #(
        .H(160),    // QQVGA 원본
        .V(120)
        ) U_frame_buffer (
        .rst       (rst),
        .wclk      (ov7670_pclk),
        .we        (we),
        .wAddr     (wAddr),
        .wData     (wData),
        .rclk      (rclk),
        .oe        (d_en),
        .rAddr     (rAddr),
        .rData     (rData_fb[i]),          // ★ 각 뱅크별 read data
        .scan_line (scan_line),
        .btn_U     (btn_U),
        .btn_D     (btn_D),
        .btn_L     (btn_L),
        .btn_R     (btn_R),
        .active    (sw_q == i[1:0]),       // ★ 선택된 사분면만 FSM 활성
        .freeze_mode(freeze_mode_fb[i])    // ★ 개별 freeze state
        );
    end
    endgenerate

    //--------------------------------------------------------------------
    // 2) VGA-픽셀 → 사분면 매핑 & 다중 read-data MUX
    //--------------------------------------------------------------------
    logic [1:0] q_idx;
    logic [9:0] x_q;        // 0‥319
    logic [9:0] y_q;        // 0‥239

    assign q_idx[0] = (x_pixel >= 10'd320);  // 0:좌, 1:우
    assign q_idx[1] = (y_pixel >= 10'd240);  // 0:상, 1:하
    assign x_q      = x_pixel - (q_idx[0] ? 10'd320 : 10'd0);
    assign y_q      = y_pixel - (q_idx[1] ? 10'd240 : 10'd0);

    // 사분면에 맞는 frame_buffer 데이터 선택
    logic [11:0] rData_mux  = rData_fb[q_idx];
    logic [2:0]  mode_mux   = freeze_mode_fb[q_idx];

    assign rclk = w_rclk;


    QVGA_MemController U_QVGA_MemController (
        .clk        (w_rclk),
        .x_pixel    (x_q),
        .y_pixel    (y_q),
        .DE         (DE),
        .rclk       (rclk),
        .d_en       (d_en),
        .rAddr      (rAddr),
        .rData      (rData_mux),
        .red_port   (w_red_port),
        .green_port (w_green_port),
        .blue_port  (w_blue_port),
        .sw         (sw_upscale),
        .sw_red     (sw_red),
        .sw_green   (sw_green),
        .sw_blue    (sw_blue),
        .frame_sw(frame_sw),
        .freeze_line(scan_line),
        .freeze_mode(mode_mux)
    );

    grayscale_controller U_grayscale_controller (
        .red_port  (w_red_port),
        .green_port(w_green_port),
        .blue_port (w_blue_port),
        .o_gray    (o_gray)
        // .gray_red_port  (gray_red),
        // .gray_green_port(gray_green),
        // .gray_blue_port (gray_blue)
    );

    //      GraySharpen U_GraySharpening(
    //     .clk(clk),
    //     .reset(rst),
    //     .gray_in(sobel_in),    
    //     .x_pixel(x_pixel),
    //     .y_pixel(y_pixel),
    //     .sharpen_out(sharpen_out)
    // );

    //     Gaussian U_Gaussian(
    //     .clk(clk),
    //     .reset(rst),
    //     .pixel_in(gaussian_in),  
    //     .addr(rAddr),      
    //     .Gaussian_out(gaussian_out)   
    // );

    //     sobel_filter U_GraytoSobel(
    //     .clk(clk),
    //     .reset(rst),
    //     .gray_in(sobel_in),           
    //     .x_pixel(x_pixel),       
    //     .y_pixel(y_pixel),       
    //     .sobel_out(sobel_out)      
    // );


    // mux_5x1 U_mux_5x1 (
    //     .sw_gray        (sw_gray),
    //     .sw_edge        (sw_edge),
    //     .sw_gaussian     (sw_gaussian),
    //     .sw_sharpening   (sw_sharpening),
    //     .red_port       (w_red_port),
    //     .green_port     (w_green_port),
    //     .blue_port      (w_blue_port),
    //     .gray_red_port  (gray_red),
    //     .gray_green_port(gray_green),
    //     .gray_blue_port (gray_blue),
    //     .sobel_out(sobel_out),
    //     .gaussian_in(gaussian_out),
    //     .sharpen_out(sharpen_out),
    //     .o_red_port     (red_port),
    //     .o_green_port   (green_port),
    //     .o_blue_port    (blue_port)
    // );

    mux_5x1 U_mux_5x1 (
        .sw_gray        (sw_gray),
        .sw_edge        (),
        .sw_gaussian    (),
        .sw_sharpening  (),
        .red_port       (w_red_port),
        .green_port     (w_green_port),
        .blue_port      (w_blue_port),
        .gray_red_port  (gray_red),
        .gray_green_port(gray_green),
        .gray_blue_port (gray_blue),
        .sobel_out      (),
        .gaussian_in    (),
        .sharpen_out    (),
        .o_red_port     (red_port),
        .o_green_port   (green_port),
        .o_blue_port    (blue_port)
    );

    sccb_start_gen U_SCCB_Start (
        .clk(clk),
        .reset(rst),
        .sccb_start(sccb_start)
    );

    SCCB_intf U_SCCB (
        .clk(clk),
        .reset(rst),
        .startSig(sccb_start),
        .SCL(SCL),
        .SDA(SDA)
    );

    btn_debounce U_btn_debounce_U (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_U),
        .o_btn(w_btn_U)
    );

    btn_debounce U_btn_debounce_D (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_D),
        .o_btn(w_btn_D)
    );

    btn_debounce U_btn_debounce_L (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_L),
        .o_btn(w_btn_L)
    );

    btn_debounce U_btn_debounce_R (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_R),
        .o_btn(w_btn_R)
    );
endmodule


module mux_5x1 (
    // switch
    input  logic        sw_gray,
    input  logic        sw_edge,
    input  logic        sw_gaussian,
    input  logic        sw_sharpening,
    //no filter
    input  logic [ 3:0] red_port,
    input  logic [ 3:0] green_port,
    input  logic [ 3:0] blue_port,
    // gray filter
    input  logic [ 3:0] gray_red_port,
    input  logic [ 3:0] gray_green_port,
    input  logic [ 3:0] gray_blue_port,
    // sobel filter
    input  logic [11:0] sobel_out,
    //Gaussian Filter
    input  logic [11:0] gaussian_in,
    //Sharpening Filter
    input  logic [11:0] sharpen_out,
    //output
    output logic [ 3:0] o_red_port,
    output logic [ 3:0] o_green_port,
    output logic [ 3:0] o_blue_port
);

    logic [3:0] sw_control;

    assign sw_control = {sw_gray, sw_edge, sw_gaussian, sw_sharpening};

    always_comb begin
        case (sw_control)
            4'b0011: begin  //sobel filter
                o_red_port   = sobel_out[11:8];
                o_green_port = sobel_out[11:8];
                o_blue_port  = sobel_out[11:8];
            end
            4'b0111: begin
                o_red_port   = gray_red_port;
                o_green_port = gray_green_port;
                o_blue_port  = gray_blue_port;
            end
            4'b1101: begin
                o_red_port   = gaussian_in[11:8];
                o_green_port = gaussian_in[7:4];
                o_blue_port  = gaussian_in[3:0];
            end
            4'b0110: begin
                o_red_port   = sharpen_out[11:8];
                o_green_port = sharpen_out[11:8];
                o_blue_port  = sharpen_out[11:8];
            end
            default: begin
                o_red_port   = red_port;
                o_green_port = green_port;
                o_blue_port  = blue_port;
            end
        endcase
    end



endmodule

module grayscale_controller (
    input  logic [ 3:0] red_port,
    input  logic [ 3:0] green_port,
    input  logic [ 3:0] blue_port,
    output logic [11:0] o_gray
    // output logic [3:0] gray_red_port,
    // output logic [3:0] gray_green_port,
    // output logic [3:0] gray_blue_port
);
    reg [11:0] gray = red_port * 77 + green_port * 150 + blue_port * 29;
    assign o_gray = gray;

    // assign {gray_red_port, gray_green_port, gray_blue_port} = {
    // gray[11:8], gray[11:8], gray[11:8]
    // };

endmodule
