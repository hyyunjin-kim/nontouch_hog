`timescale 1ns / 1ps

module OV7670_MemController (
    input  logic        pclk,
    input  logic        rst,
    input  logic        href,
    input  logic        v_sync,
    input  logic [ 7:0] ov7670_data,
    output logic        we,
    output logic [16:0] wAddr,
    output logic [15:0] wData
);
    logic [9:0] h_counter; // 320 * 2 = 640 (320 pixel) (두 set들어오니까)
    logic [7:0] v_counter;  // 240 line
    logic [15:0] pix_data;

    assign wAddr = v_counter * 320 + h_counter[9:1];   // LSB 없앰으로써 나누기2 기능화
    assign wData = pix_data;

    always_ff @(posedge pclk, posedge rst) begin : h_sequence
        if (rst) begin
            pix_data  <= 0;
            h_counter <= 0;
            we        <= 1'b0;
        end else begin
            if(href == 1'b0) begin
                h_counter <= 0;
                we        <= 1'b0;
            end else begin
                h_counter <= h_counter + 1;
                if (h_counter[0] == 1'b0) begin  // even data
                    pix_data[15:8] <= ov7670_data;
                    we             <= 1'b0;
                end else begin  // odd data
                    pix_data[7:0] <= ov7670_data;
                    we            <= 1'b1;
                end
            end
        end
    end

    always_ff @( posedge pclk, posedge rst) begin : v_sequence
        if(rst) begin
            v_counter <= 0;
        end else begin
            if(v_sync) begin
                v_counter <= 0;
            end else begin
                if(h_counter == 640 - 1) begin
                    v_counter <= v_counter + 1;
                end
            end
        end
    end
endmodule
