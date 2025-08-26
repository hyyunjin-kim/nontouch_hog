`timescale 1ns / 1ps

module QVGA_MemController (
    // VGA Controller side
    input  logic        clk,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic        DE,
    // frame buffer side
    output logic        rclk,
    output logic        d_en,
    output logic [16:0] rAddr,
    input  logic [11:0] rData,
    // export side
    output logic [ 3:0] red_port,
    output logic [ 3:0] green_port,
    output logic [ 3:0] blue_port,
    // isp
    input logic sw, // upscale mode sw
    input logic sw_red,
    input logic sw_green,
    input logic sw_blue,
    input logic [2:0] frame_sw,
    // freeze
    input logic [7:0] freeze_line,
    input logic [2:0] freeze_mode
);

    logic display_en;
    logic [3:0] logic_red, logic_green, logic_blue;

    assign logic_red = sw_red? 4'hf : 4'h0;
    assign logic_green = sw_green? 4'hf : 4'h0;
    assign logic_blue = sw_blue? 4'hf : 4'h0;

    assign rclk = clk;
    // assign display_en = sw ? (x_pixel < 160 && y_pixel < 120) : (x_pixel < 640 && y_pixel < 480);
    assign display_en = (x_pixel < 320 && y_pixel < 240) ;
    assign d_en = display_en;

    // reg [16:0] down_rAddr = (x_pixel < 160 && y_pixel < 120) ? (y_pixel * 160 + x_pixel) : 16'b0;
    // reg [16:0] up_rAddr = (x_pixel < 640 && y_pixel < 480) ? ((y_pixel/4) * 160 + x_pixel/4) : 16'b0;
    // assign rAddr = sw ? down_rAddr : up_rAddr;
    assign rAddr = (x_pixel < 320 && y_pixel < 240) ? ((y_pixel/2) * 160 + x_pixel/2) : 16'b0;


logic border_pixel;
always_comb begin
    border_pixel = 1'b0;
    if (frame_sw != 3'b000) begin
        if ((x_pixel <= 2) || (x_pixel >= 317) || (y_pixel <= 2) || (y_pixel >= 237))
            border_pixel = 1'b1;
    end
end

    // freeze_mode enum
    localparam IDLE  = 0, UP = 1, DOWN = 2, LEFT = 3, RIGHT = 4, STOP = 5;

    // Freeze 라인 시각화 조건
    logic freeze_line_active;
    always_comb begin
        unique case (freeze_mode)
            UP:
                freeze_line_active = (y_pixel[9:1] == (120 - freeze_line));  // 위 → 아래 (y 기준 증가)
            DOWN:
                freeze_line_active = (y_pixel[9:1] == freeze_line);  // 아래 → 위
            LEFT:
                freeze_line_active = (x_pixel[9:1] == (160 - freeze_line));  // 왼 → 오
            RIGHT:
                freeze_line_active = (x_pixel[9:1] == freeze_line);  // 오 → 왼
            default:
                freeze_line_active = 1'b0;
        endcase
    end


    // assign {red_port, green_port, blue_port} = display_en ? {(logic_red & rData[15:12]), (logic_green & rData[10:7]), (logic_blue & rData[4:1])} : 12'b0;
    // always_comb begin
    //     if (!display_en) begin
    //         red_port   = 0;
    //         green_port = 0;
    //         blue_port  = 0;
    //     end else if (freeze_line_active) begin
    //         red_port   = 4'h0;
    //         green_port = 4'h0;
    //         blue_port  = 4'hF; // Freeze Line 표시
    //     end else begin
    //         red_port   = logic_red   & rData[11:8];
    //         green_port = logic_green & rData[7:4];
    //         blue_port  = logic_blue  & rData[3:0];
    //     end
    // end

    always_comb begin
        if (!display_en) begin
            red_port   = 4'h0;
            green_port = 4'h0;
            blue_port  = 4'h0;

        end else if (border_pixel) begin
            // 프레임 색상 선택
            case (frame_sw)
                3'b001: begin  // 검은색
                    red_port   = 4'h0;
                    green_port = 4'h0;
                    blue_port  = 4'h0;
                end
                3'b010: begin  // 분홍색
                    red_port   = 4'hF;
                    green_port = 4'h0;
                    blue_port  = 4'hF;
                end
                3'b100: begin  // 하늘색
                    red_port   = 4'h0;
                    green_port = 4'hF;
                    blue_port  = 4'hF;
                end
                default: begin
                    red_port   = 4'h0;
                    green_port = 4'h0;
                    blue_port  = 4'h0;
                end
            endcase

        end else if (freeze_line_active) begin
            red_port   = 4'h0;
            green_port = 4'h0;
            blue_port  = 4'hF; // Freeze Line 표시

        end else begin
            red_port   = logic_red   & rData[11:8];
            green_port = logic_green & rData[7:4];
            blue_port  = logic_blue  & rData[3:0];
        end
    end
endmodule
