`timescale 1ns / 1ps

module line_counter (
    input  logic        clk,        // 100 MHz 클럭
    input  logic        rst,        // active-high 비동기 리셋
    output logic [7:0]  scan_line,  // 0부터 119(=120라인) 순환
    input  logic        btn
);

    // 2,500,000 사이클 = 약 100 MHz 클럭 기준 0.025 초
    // => 1초에 40번(40 Hz) tick 발생
    localparam integer MAX_CNT    = 2_500_000 - 1;  
    // localparam integer MAX_SCLINE = 120;        // QQVGA 세로 해상도 120라인: 인덱스 0..119
    localparam integer MAX_SCLINE = 160;        // QQVGA 세로 해상도 120라인: 인덱스 0..119
    parameter IDLE = 0, RUN = 1, STOP = 2;

    logic [21:0] counter_reg, counter_next;  // 2,500,000 < 2^22(≈4,194,304)이므로 22비트 카운터
    logic [7:0]  scan_line_reg, scan_line_next;
    logic [1:0] state, next;

    assign scan_line = scan_line_reg;

    always_ff @( posedge clk, posedge rst ) begin : blockName
        if(rst) begin
            state <= IDLE;
            counter_reg   <= 0;
            scan_line_reg <= 0;
        end else begin
            state <= next;
            counter_reg <= counter_next;
            scan_line_reg <= scan_line_next;
        end
    end

    always_comb begin
        next = state;
        counter_next = counter_reg;
        scan_line_next = scan_line_reg;
        case (state)
            IDLE: begin
                if(btn) begin
                    next = RUN;
                end
            end 
            RUN: begin
                if (counter_reg == MAX_CNT) begin
                    counter_next = 0;
                    // scan_line을 1 증가하되, 최대(MAX_SCLINE)를 넘어가면 0으로 돌아감
                    if (scan_line_reg == MAX_SCLINE) begin
                        scan_line_next = scan_line_reg;
                        next = STOP;
                    end else begin
                        scan_line_next = scan_line_reg + 1;
                    end
                end else begin
                    counter_next = counter_reg + 1;
                end
            end
            STOP: begin
                if(btn) begin
                    next = RUN;
                    scan_line_next = 0;
                end
            end 
        endcase
    end

endmodule


module btn_debounce (
    input logic clk,
    input logic reset,
    input logic i_btn,
    output logic o_btn
);

    logic [7:0] q_reg, q_next;  // shift register
    logic  edge_detect;
    logic  btn_debounce;

    // 1khz clk
    logic [$clog2(100_000)-1:0] counter_reg, counter_next;
    logic r_1khz;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next;
        end
    end
    // next
    always @(*) begin  // 100_000_000 = 100M
        counter_next = counter_reg;
        r_1khz = 0;
        if (counter_reg == 100_000) begin
            counter_next = 0;
            r_1khz = 1'b1;
        end else begin  // 1khz 1tick.
            counter_next = counter_reg + 1;
            r_1khz = 1'b0;
        end
    end

    // state logic , shift register
    always @(posedge r_1khz, posedge reset) begin
        if (reset) begin
            q_reg <= 0;
        end else begin
            q_reg <= q_next;
        end
    end

    // next logic
    always @(i_btn, r_1khz) begin  // event i_btn, r_1khz
        q_next = {i_btn, q_reg[7:1]};
    end

    // 8 input AND gate
    assign btn_debounce = &q_reg;

    // edge_detector , 100Mhz
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            edge_detect <= 0;
        end else begin
            edge_detect <= btn_debounce;
        end
    end

    assign o_btn = btn_debounce & (~edge_detect);

endmodule
