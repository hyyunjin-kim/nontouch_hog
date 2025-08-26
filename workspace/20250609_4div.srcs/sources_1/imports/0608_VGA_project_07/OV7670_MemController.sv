`timescale 1ns / 1ps
module OV7670_MemController (
    input  logic        pclk,
    input  logic        rst,
    input  logic        href,
    input  logic        v_sync,
    input  logic [ 7:0] ov7670_data,
    output logic        we,
    output logic [16:0] wAddr,
    output logic [11:0] wData
);
    logic [9:0] h_counter;
    logic [7:0] v_counter;
    logic [11:0] pix_data;

    // QQVGA: 160x120
    // 저장 주소 계산: 줄마다 160 픽셀 → 160 * y + x
    assign wAddr = v_counter * 160 + h_counter[9:2]; // 4픽셀 단위로 1픽셀 저장
    assign wData = pix_data;

    always_ff @(posedge pclk or posedge rst) begin : h_sequence
        if (rst) begin
            pix_data  <= 12'd0;
            h_counter <= 10'd0;
            we        <= 1'b0;
        end else begin
            if (!href) begin
                h_counter <= 0;
                we        <= 0;
            end else begin
                h_counter <= h_counter + 1;

                // 매 4픽셀마다 1픽셀 저장 (h_counter[1:0] == 2'b00)
                if (h_counter[0] == 1'b0) begin
                    pix_data[11:5] <= {ov7670_data[7:4], ov7670_data[2:0]};
                    we <= 1'b0;
                end else begin
                    pix_data[4:0] <= {ov7670_data[7], ov7670_data[4:1]};

                    if (h_counter[1:0] == 2'b01) begin
                        we <= 1'b1; // write only every 4 pixels
                    end else begin
                        we <= 1'b0;
                    end
                end
            end
        end
    end

    always_ff @(posedge pclk or posedge rst) begin : v_sequence
        if (rst) begin
            v_counter <= 0;
        end else begin
            if (v_sync) begin
                v_counter <= 0;
            end else begin
                // 한 라인당 320 클럭(160 픽셀 x 2바이트)만 처리
                if (h_counter == 320 - 1) begin
                    // QQVGA는 120라인까지만 저장
                    if (v_counter < 120)
                        v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule
