`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/26 22:55:02
// Design Name: 
// Module Name: DETECT_CONTROL_UNIT
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module DETECT_CONTROL_UNIT#(parameter TEMPLATE_NUM = 23)(
    input    logic   clk,
    input    logic   reset,

    input logic [9:0] x_pixel,
    input logic [9:0] y_pixel,
    input logic [7:0] gray_data,
    input  logic      display_en, // QVGA mem controller에서 빼오기

    output logic [8:0] hand_x,
    output logic [7:0] hand_y,
    output logic       hand_motion // 0: 일반 , 1: 클릭
);

    parameter WIN_W = 32;
    typedef enum {IDLE, BLOCK_HOG,  WAIT_COS, CHECK, DETECT} state_e; //stride 8로 가자 
    // 32x32 윈도우 버퍼 (내부 사용)
    logic [7:0] window [0:WIN_W-1][0:WIN_W-1];
    logic window_valid;

    state_e state, state_next;

    logic start_compute_cos;
    logic done_compute_cos;


        // template bank (2x64)
    logic [15:0] template_bank [0:22][0:63];
    initial begin
        $readmemh("fist1.mem",template_bank[0]);
        $readmemh("fist2.mem",template_bank[1]);
        $readmemh("fist_image.mem",template_bank[2]);
        $readmemh("fist_image2.mem",template_bank[3]);
        $readmemh("fist_image3.mem",template_bank[4]);
        $readmemh("open1.mem",template_bank[5]);
        $readmemh("open10.mem",template_bank[6]);
        $readmemh("open11.mem",template_bank[7]);
        $readmemh("open12.mem",template_bank[8]);
        $readmemh("open13.mem",template_bank[9]);
        $readmemh("open14.mem",template_bank[10]);
        $readmemh("open15.mem",template_bank[11]);
        $readmemh("open16.mem",template_bank[12]);
        $readmemh("open17.mem",template_bank[13]);
        $readmemh("open18.mem",template_bank[14]);
        $readmemh("open2.mem",template_bank[15]);
        $readmemh("open3.mem",template_bank[16]);
        $readmemh("open4.mem",template_bank[17]);
        $readmemh("open5.mem",template_bank[18]);
        $readmemh("open6.mem",template_bank[19]);
        $readmemh("open7.mem",template_bank[20]);
        $readmemh("open8.mem",template_bank[21]);
        $readmemh("open9.mem",template_bank[22]);

    end
    // similarity multi
    // logic sim_start, sim_done;
    logic [39:0] sim_best;
    logic  [$clog2(TEMPLATE_NUM)-1:0]sim_best_id; // 1bit: 0=open, 1=fist
    

    // 각 셀을 flat으로 저장 (8x8 = 64픽셀 × 8bit = 512bit)
    logic [512-1:0] cell_1_flat;
    logic [512-1:0] cell_2_flat;
    logic [512-1:0] cell_3_flat;
    logic [512-1:0] cell_4_flat;

   logic [512-1:0] cell_5_flat;
    logic [512-1:0] cell_6_flat;
    logic [512-1:0] cell_7_flat;
    logic [512-1:0] cell_8_flat;

   logic [512-1:0] cell_9_flat;
    logic [512-1:0] cell_10_flat;
    logic [512-1:0] cell_11_flat;
    logic [512-1:0] cell_12_flat;
   logic [512-1:0] cell_13_flat;
    logic [512-1:0] cell_14_flat;
    logic [512-1:0] cell_15_flat;
    logic [512-1:0] cell_16_flat;


    logic hog_start1;
    logic hog_start2;
    logic hog_start3;
    logic hog_start4;
    logic [512-1:0] hog_cell_flat1;
    logic [512-1:0] hog_cell_flat2;
    logic [512-1:0] hog_cell_flat3;
    logic [512-1:0] hog_cell_flat4;
    logic hog_done1;
    logic hog_done2;
    logic hog_done3;
    logic hog_done4;
    logic [15:0] hog_hist1[0:3];
    logic [15:0] hog_hist2[0:3];
    logic [15:0] hog_hist3[0:3];
    logic [15:0] hog_hist4[0:3];
    logic block_done1; //1개 블럭 끝
    logic block_done2; //1개 블럭 끝
    logic block_done3; //1개 블럭 끝
    logic block_done4; //1개 블럭 끝
    logic [15:0]block_hist1[0:15]; //1개블럭
    logic [15:0]block_hist2[0:15]; //1개블럭
    logic [15:0]block_hist3[0:15]; //1개블럭
    logic [15:0]block_hist4[0:15]; //1개블럭

    // ------------------------------------------------------------------------
    // 32x32 윈도우에서 4개의 8x8 셀을 추출해 flat으로 변환
    // ------------------------------------------------------------------------
    always_comb begin
        // 기본값 초기화
        cell_1_flat = '0;
        cell_2_flat = '0;
        cell_3_flat = '0;
        cell_4_flat = '0;

        cell_5_flat = '0;
        cell_6_flat = '0;
        cell_7_flat = '0;
        cell_8_flat = '0;

        cell_9_flat = '0;
        cell_10_flat = '0;
        cell_11_flat = '0;
        cell_12_flat = '0;

        cell_13_flat = '0;
        cell_14_flat = '0;
        cell_15_flat = '0;
        cell_16_flat = '0;

        // cell1: (0~7, 0~7)
     for (int r = 0; r < 8; r++) begin
        for (int c = 0; c < 8; c++) begin
            // 0~7행
            cell_1_flat [(r*8+c)*8 +: 8]  = window[r+0][c+0];
            cell_2_flat [(r*8+c)*8 +: 8]  = window[r+0][c+8];
            cell_3_flat [(r*8+c)*8 +: 8]  = window[r+0][c+16];
            cell_4_flat [(r*8+c)*8 +: 8]  = window[r+0][c+24];

            // 8~15행
            cell_5_flat [(r*8+c)*8 +: 8]  = window[r+8][c+0];
            cell_6_flat [(r*8+c)*8 +: 8]  = window[r+8][c+8];
            cell_7_flat [(r*8+c)*8 +: 8]  = window[r+8][c+16];
            cell_8_flat [(r*8+c)*8 +: 8]  = window[r+8][c+24];

            // 16~23행
            cell_9_flat [(r*8+c)*8 +: 8]  = window[r+16][c+0];
            cell_10_flat[(r*8+c)*8 +: 8]  = window[r+16][c+8];
            cell_11_flat[(r*8+c)*8 +: 8]  = window[r+16][c+16];
            cell_12_flat[(r*8+c)*8 +: 8]  = window[r+16][c+24];

            // 24~31행
            cell_13_flat[(r*8+c)*8 +: 8]  = window[r+24][c+0];
            cell_14_flat[(r*8+c)*8 +: 8]  = window[r+24][c+8];
            cell_15_flat[(r*8+c)*8 +: 8]  = window[r+24][c+16];
            cell_16_flat[(r*8+c)*8 +: 8]  = window[r+24][c+24];
        end
    end
    end
        logic [39:0] max_similarity;
    logic [9:0] best_x, best_y;
    logic [$clog2(TEMPLATE_NUM)-1:0] best_id; // 템플릿 개수에 맞추기 
    always_ff @(posedge clk, posedge reset) begin
        if(reset) begin
            state <= IDLE;
            start_compute_cos <= 0;
            done_compute_cos <= 0;
            max_similarity <= 0;
            best_x <= 0;
            best_y <= 0;
            best_id <= 0;
        end
        else begin
            state <= state_next;
                 if (x_pixel==0 && y_pixel==0) begin
                max_similarity <= 0;
                best_x <= 0;
                best_y <= 0;
                best_id <= 0;
            end
                   if (state==WAIT_COS && done_compute_cos) begin
                if (sim_best > max_similarity) begin
                    max_similarity <= sim_best;
                    best_x <= x_pixel - 16;  // 윈도우 중심
                    best_y <= y_pixel - 16;
                    best_id <= sim_best_id;
                end
            end
        end
    end
    

    always_comb begin
        state_next = state;
        start_compute_cos = 0;
        case(state) 
            IDLE: begin
                if(window_valid) state_next = BLOCK_HOG;
            end
            BLOCK_HOG: begin
                if(block_done1 & block_done2 & block_done3 & block_done4) begin
                    state_next = WAIT_COS;
                    start_compute_cos = 1'b1;

                end
            end
            WAIT_COS: begin
                if(done_compute_cos) state_next = CHECK;
            end

            CHECK: begin
                if(x_pixel == 319 && y_pixel == 239) state_next = DETECT;
                else state_next = IDLE;
            end
            DETECT: begin
                // hand_x = 
                // hand_y = 
                // motion = 
                state_next = IDLE;
            end

        endcase


    
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            hand_x <= 0;
            hand_y <= 0;
            hand_motion <= 0;
        end else if (state == DETECT) begin
            hand_x <= best_x[8:0];
            hand_y <= best_y[7:0];
            hand_motion <= (best_id <= 4)? 1'b1 : 0; // 0=open, 1=fist // 이거는 범위로 조정하자 여러개 만들어서 
        end
    end
    // ------------------------------------------------------------------------
    // 라인버퍼 인스턴스
    // ------------------------------------------------------------------------
    linebuffer_window_32x32 u_window_linebuf32 (
        .clk(clk),
        .rst(reset),
        .pixel_valid(display_en),
        .gray_in(gray_data),
        .x_pixel(x_pixel),   // 0~319
        .window(window),
        .window_valid(window_valid)
    );

   hog_cell u_compute_hog_Cell1
 (
    .clk(clk),
    .reset(reset),
    .start(hog_start1),    // 1클럭 펄스
    // 512bit flat 입력: 8x8 * 8bit = 512bit
    .cell_flat(hog_cell_flat1),

    .done(hog_done1),     // 연산 완료 (1클럭 high)
    .hist(hog_hist1) // 4-bin histogram
);
   hog_cell u_compute_hog_Cell2
 (
    .clk(clk),
    .reset(reset),
    .start(hog_start2),    // 1클럭 펄스
    // 512bit flat 입력: 8x8 * 8bit = 512bit
    .cell_flat(hog_cell_flat2),

    .done(hog_done2),     // 연산 완료 (1클럭 high)
    .hist(hog_hist2) // 4-bin histogram
);
   hog_cell u_compute_hog_Cell3
 (
    .clk(clk),
    .reset(reset),
    .start(hog_start3),    // 1클럭 펄스
    // 512bit flat 입력: 8x8 * 8bit = 512bit
    .cell_flat(hog_cell_flat3),

    .done(hog_done3),     // 연산 완료 (1클럭 high)
    .hist(hog_hist3) // 4-bin histogram
);
   hog_cell u_compute_hog_Cell4
 (
    .clk(clk),
    .reset(reset),
    .start(hog_start4),    // 1클럭 펄스
    // 512bit flat 입력: 8x8 * 8bit = 512bit
    .cell_flat(hog_cell_flat4),

    .done(hog_done4),     // 연산 완료 (1클럭 high)
    .hist(hog_hist4) // 4-bin histogram
);

    HOG_FSM u_HOG_FSM_BLOCK1 (
    .clk(clk),
    .reset(reset),
    .window_valid(window_valid),

    // 4개의 셀 (flat 512bit)
    .cell1_flat(cell_1_flat),
    .cell2_flat(cell_2_flat),
    .cell3_flat(cell_3_flat),
    .cell4_flat(cell_4_flat),

    // HOG 모듈 인터페이스 (flat 버스)
    .hog_start(hog_start1),
    .hog_cell_flat(hog_cell_flat1),  // 512bit flat
    .hog_done(hog_done1),
    .hog_hist(hog_hist1),   // 4-bin histogram 출력

    // 최종 출력
    .block_done(block_done1),
    .block_hist(block_hist1)// 4셀 × 4bin = 16 값
);

    HOG_FSM u_HOG_FSM_BLOCK2 (
    .clk(clk),
    .reset(reset),
    .window_valid(window_valid),

    // 4개의 셀 (flat 512bit)
    .cell1_flat(cell_5_flat),
    .cell2_flat(cell_6_flat),
    .cell3_flat(cell_7_flat),
    .cell4_flat(cell_8_flat),

    // HOG 모듈 인터페이스 (flat 버스)
    .hog_start(hog_start2),
    .hog_cell_flat(hog_cell_flat2),  // 512bit flat
    .hog_done(hog_done2),
    .hog_hist(hog_hist2),   // 4-bin histogram 출력

    // 최종 출력
    .block_done(block_done2),
    .block_hist(block_hist2)// 4셀 × 4bin = 16 값
);

    HOG_FSM u_HOG_FSM_BLOCK3 (
    .clk(clk),
    .reset(reset),
    .window_valid(window_valid),

    // 4개의 셀 (flat 512bit)
    .cell1_flat(cell_9_flat),
    .cell2_flat(cell_10_flat),
    .cell3_flat(cell_11_flat),
    .cell4_flat(cell_12_flat),

    // HOG 모듈 인터페이스 (flat 버스)
    .hog_start(hog_start3),
    .hog_cell_flat(hog_cell_flat3),  // 512bit flat
    .hog_done(hog_done3),
    .hog_hist(hog_hist3),   // 4-bin histogram 출력

    // 최종 출력
    .block_done(block_done3),
    .block_hist(block_hist3)// 4셀 × 4bin = 16 값
);

    HOG_FSM u_HOG_FSM_BLOCK4 (
    .clk(clk),
    .reset(reset),
    .window_valid(window_valid),

    // 4개의 셀 (flat 512bit)
    .cell1_flat(cell_13_flat),
    .cell2_flat(cell_14_flat),
    .cell3_flat(cell_15_flat),
    .cell4_flat(cell_16_flat),

    // HOG 모듈 인터페이스 (flat 버스)
    .hog_start(hog_start4),
    .hog_cell_flat(hog_cell_flat4),  // 512bit flat
    .hog_done(hog_done4),
    .hog_hist(hog_hist4),   // 4-bin histogram 출력

    // 최종 출력
    .block_done(block_done4),
    .block_hist(block_hist4)// 4셀 × 4bin = 16 값
);

    hog_similarity_multi #(
        .TEMPLATE_NUM(23),
        .N(64)
    ) u_multi (
        .clk(clk),
        .reset(reset),
        .start(start_compute_cos),
        .block_hist1(block_hist1),
        .block_hist2(block_hist2),
        .block_hist3(block_hist3),
        .block_hist4(block_hist4),
        .template_bank(template_bank),
        .done(done_compute_cos),
        .max_similarity(sim_best),
        .best_id(sim_best_id)
    );
ila_0 u_ila(
.clk(clk),


.probe0(x_pixel),
.probe1(y_pixel),
.probe2(gray_data),
.probe3(hand_x),
.probe4(hand_y),
.probe5(hand_motion),
.probe6(state)
);

    // 이 모듈에서는 hand_x, hand_y, hand_motion은 추후 HOG FSM 결과로 결정

endmodule


module linebuffer_window_32x32 #
(
    parameter IMG_W = 320,
    parameter WIN_W = 32
)
(
    input  logic        clk,
    input  logic        rst,
    input  logic        pixel_valid,
    input  logic [7:0]  gray_in,
    input  logic [9:0]  x_pixel,   // 0~319

    output logic [7:0] window [0:WIN_W-1][0:WIN_W-1],
    output logic       window_valid
);

    // ===========================
    // 라인 수 카운트 (세로 valid 확인용)
    // ===========================
    logic [9:0] line_count;
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            line_count <= 0;
        else if (pixel_valid && (x_pixel == IMG_W-1))
            line_count <= line_count + 1;
    end

   assign window_valid = 
       (x_pixel >= WIN_W-1) &&
       (line_count >= WIN_W-1) &&
       (x_pixel[2:0] == 3'd7) &&       // x 좌표가 8의 배수 + 7 (마지막 픽셀)
       (line_count[2:0] == 3'd7);      // y 좌표도 동일

    // ---------------------------
    // 1) 가로 방향: 32픽셀 Shift Register
    // ---------------------------
    logic [7:0] row_shift [0:WIN_W-1][0:WIN_W-1];
    integer i,j;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (i=0;i<WIN_W;i=i+1)
                for (j=0;j<WIN_W;j=j+1)
                    row_shift[i][j] <= 8'd0;
        end 
        else if (pixel_valid) begin
            // 첫 번째 줄 (i=0): shift 왼쪽→오른쪽
            for (j=0; j<WIN_W-1; j=j+1)
                row_shift[0][j] <= row_shift[0][j+1];
            row_shift[0][WIN_W-1] <= gray_in;  // 최신 픽셀은 맨 끝
        end
    end

    // ---------------------------
    // 2) 세로 방향: 31개의 라인 버퍼 (BRAM)
    // ---------------------------
    (* ram_style = "block" *) 
    logic [7:0] linebuf [0:WIN_W-2][0:IMG_W-1];

    always_ff @(posedge clk) begin
        if (pixel_valid) begin
            // 현재 줄 저장
            linebuf[0][x_pixel] <= gray_in;
            // 이전 줄 데이터 위로 복사
            for (i=1; i<WIN_W-1; i=i+1)
                linebuf[i][x_pixel] <= linebuf[i-1][x_pixel];
        end
    end

    // ---------------------------
    // 3) block RAM read latency 보정
    // ---------------------------
    logic [7:0] linebuf_data [0:WIN_W-2]; // 한 클럭 지연된 값

    always_ff @(posedge clk) begin
        if (pixel_valid) begin
            for (i=1; i<WIN_W; i=i+1)
                linebuf_data[i-1] <= linebuf[i-1][x_pixel];
        end
    end

    // ---------------------------
    // 4) 세로 줄 데이터(1클럭 지연) → 가로 shift register
    // ---------------------------
    always_ff @(posedge clk) begin
        if (pixel_valid) begin
            for (i=1; i<WIN_W; i=i+1) begin
                // 가로 shift (왼쪽→오른쪽)
                for (j=0; j<WIN_W-1; j=j+1)
                    row_shift[i][j] <= row_shift[i][j+1];
                row_shift[i][WIN_W-1] <= linebuf_data[i-1];
            end
        end
    end

    // ---------------------------
    // 5) window 출력
    // ---------------------------
    always_comb begin
        for (i=0; i<WIN_W; i=i+1)
            for (j=0; j<WIN_W; j=j+1)
                window[i][j] = row_shift[i][j];
    end

endmodule


module HOG_FSM (
    input  logic        clk,
    input  logic        reset,
    input  logic        window_valid,

    // 4개의 셀 (flat 512bit)
    input  logic [512-1:0] cell1_flat,
    input  logic [512-1:0] cell2_flat,
    input  logic [512-1:0] cell3_flat,
    input  logic [512-1:0] cell4_flat,

    // HOG 모듈 인터페이스 (flat 버스)
    output logic        hog_start,
    output logic [512-1:0] hog_cell_flat,  // 512bit flat
    input  logic        hog_done,
    input  logic [15:0] hog_hist [0:3],   // 4-bin histogram 출력

    // 최종 출력
    output logic        block_done,
    output logic [15:0] block_hist [0:15] // 4셀 × 4bin = 16 값
);

    typedef enum logic [2:0] {
        IDLE,
        CELL1,
        CELL2,
        CELL3,
        CELL4,
        FINISH
    } state_e;

    state_e state, next_state;
    logic [1:0] cell_index; // 현재 몇 번째 셀인지 0~3
    logic [15:0] hist_mem [0:15]; // 중간 histogram 저장

    // ------------------------------------------------------------------------
    // 상태 레지스터
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------------------
    // 선택된 셀 flat
    // ------------------------------------------------------------------------
    logic [512-1:0] sel_cell_flat;

    always_comb begin
        case (cell_index)
            2'd0: sel_cell_flat = cell1_flat;
            2'd1: sel_cell_flat = cell2_flat;
            2'd2: sel_cell_flat = cell3_flat;
            2'd3: sel_cell_flat = cell4_flat;
            default: sel_cell_flat = '0;
        endcase
    end

    // hog 모듈 입력 연결
    assign hog_cell_flat = sel_cell_flat;

    // ------------------------------------------------------------------------
    // 기본값 + 상태머신
    // ------------------------------------------------------------------------
    always_comb begin
        next_state  = state;
        hog_start   = 1'b0;
        block_done  = 1'b0;

        case(state)
            IDLE: begin
                if (window_valid) begin
                    hog_start  = 1'b1;   // 첫 셀 시작 (1클럭)
                    next_state = CELL1;
                end
            end

            CELL1: if (hog_done) begin
                next_state = CELL2;
                hog_start  = 1'b1;
            end

            CELL2: if (hog_done) begin
                next_state = CELL3;
                hog_start  = 1'b1;
            end

            CELL3: if (hog_done) begin
                next_state = CELL4;
                hog_start  = 1'b1;
            end

            CELL4: if (hog_done) begin
                next_state = FINISH;
            end

            FINISH: begin
                block_done = 1'b1;
                next_state = IDLE; // 다음 block 처리 준비
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // cell_index 관리
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cell_index <= 0;
        end else begin
            if (state==IDLE && window_valid) cell_index <= 0;
            else if (hog_done && state!=FINISH) cell_index <= cell_index + 1;
        end
    end

    // ------------------------------------------------------------------------
    // histogram 결과 저장
    // ------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (hog_done) begin
            hist_mem[cell_index*4+0] <= hog_hist[0];
            hist_mem[cell_index*4+1] <= hog_hist[1];
            hist_mem[cell_index*4+2] <= hog_hist[2];
            hist_mem[cell_index*4+3] <= hog_hist[3];
        end
    end

    // ------------------------------------------------------------------------
    // 최종 block descriptor 출력
    // ------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (block_done)
            for (int i=0; i<16; i++)
                block_hist[i] <= hist_mem[i];
    end

endmodule


module hog_cell #(
    parameter CELL_SIZE = 8
)(
    input  logic                           clk,
    input  logic                           reset,
    input  logic                           start,    // 1클럭 펄스
    // 512bit flat 입력: 8x8 * 8bit = 512bit
    input  logic [CELL_SIZE*CELL_SIZE*8-1:0] cell_flat,

    output logic                           done,     // 연산 완료 (1클럭 high)
    output logic [15:0]                    hist [0:3] // 4-bin histogram
);

    // FSM 상태
    typedef enum logic [1:0] {IDLE, COMPUTE, FINISH} state_e;
    state_e state, next_state;

    // 픽셀 인덱스
    logic [5:0] pix_idx;  // 0~63
    int x, y;

    // 누적 히스토그램
    logic [15:0] hist_accum [0:3];

    // 계산용 조합 변수
    logic signed [10:0] gx_c, gy_c;  // sobel 결과 (combinational)
    logic [15:0] mag_c;
    logic [8:0]  angle_c;
    logic [1:0]  bin_c;

    // ------------------------------------------------------------------------
    // flat 벡터에서 픽셀 값 읽기
    // ------------------------------------------------------------------------
    function automatic logic [7:0] get_pix(input int yy, input int xx); //함수 써서 indexing 편하게!!
        int index;
        begin
            index = yy * CELL_SIZE + xx;
            get_pix = cell_flat[index*8 +: 8];
        end
    endfunction

    // ------------------------------------------------------------------------
    // FSM 상태 전이
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case(state)
            IDLE:    if (start) next_state = COMPUTE;
            COMPUTE: if (pix_idx == 63) next_state = FINISH;
            FINISH:  next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // pix_idx 카운터
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            pix_idx <= 0;
        else if (state == COMPUTE)
            pix_idx <= pix_idx + 1;
        else if (state == IDLE)
            pix_idx <= 0;
    end

    assign x = pix_idx % CELL_SIZE;
    assign y = pix_idx / CELL_SIZE;

    // ------------------------------------------------------------------------
    // 조합 논리: gx, gy, mag, angle, bin 계산
    // ------------------------------------------------------------------------
    always_comb begin
        // 기본값 초기화
        gx_c = 0;
        gy_c = 0;
        mag_c = 0;
        angle_c = 0;
        bin_c = 0;

        if (state == COMPUTE &&
            x>0 && x<CELL_SIZE-1 &&
            y>0 && y<CELL_SIZE-1) begin

            gx_c = -get_pix(y-1,x-1) + get_pix(y-1,x+1)
                 - 2*get_pix(y,x-1) + 2*get_pix(y,x+1)
                 - get_pix(y+1,x-1) + get_pix(y+1,x+1);

            gy_c =  get_pix(y-1,x-1) + 2*get_pix(y-1,x) + get_pix(y-1,x+1)
                 -  get_pix(y+1,x-1) - 2*get_pix(y+1,x) - get_pix(y+1,x+1);

            mag_c = (gx_c[10] ? -gx_c : gx_c) + (gy_c[10] ? -gy_c : gy_c);

            if (gy_c == 0)
                angle_c = 0;
            else if (gx_c == 0)
                angle_c = 90;
            else if ((gy_c > 0 && gx_c > 0) || (gy_c < 0 && gx_c < 0))
                angle_c = 45;
            else
                angle_c = 135;

            if (angle_c < 45)      bin_c = 2'd0;
            else if (angle_c < 90) bin_c = 2'd1;
            else if (angle_c <135) bin_c = 2'd2;
            else                   bin_c = 2'd3;
        end
    end

    // ------------------------------------------------------------------------
    // hist_accum 누적 (<=만 사용)
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i=0; i<4; i++)
                hist_accum[i] <= 0;
        end else if (state == IDLE && start) begin
            for (int i=0; i<4; i++)
                hist_accum[i] <= 0;
        end else if (state == COMPUTE) begin
            if (x>0 && x<CELL_SIZE-1 && y>0 && y<CELL_SIZE-1) begin
                case (bin_c)
                    2'd0: hist_accum[0] <= hist_accum[0] + mag_c;
                    2'd1: hist_accum[1] <= hist_accum[1] + mag_c;
                    2'd2: hist_accum[2] <= hist_accum[2] + mag_c;
                    2'd3: hist_accum[3] <= hist_accum[3] + mag_c;
                endcase
            end
        end
    end

    // ------------------------------------------------------------------------
    // 완료 신호 및 히스토그램 출력
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            done <= 1'b0;
            for (int i=0; i<4; i++)
                hist[i] <= 0;
        end else if (state == FINISH) begin
            done <= 1'b1;
            for (int i=0; i<4; i++)
                hist[i] <= hist_accum[i];
        end else begin
            done <= 1'b0;
        end
    end

endmodule

module hog_similarity_multi #(
    parameter TEMPLATE_NUM = 23, // id는 첫번째 칸 2번쨰 칸이 값 걍 idx 범위로 할래 2번쨰 칸이 값 걍 idx 범위로 할래 
    parameter N = 64
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    // 4개의 block histogram 입력
    input  logic [15:0] block_hist1 [0:15],
    input  logic [15:0] block_hist2 [0:15],
    input  logic [15:0] block_hist3 [0:15],
    input  logic [15:0] block_hist4 [0:15],

    // 여러 템플릿 (TEMPLATE_NUM x 64)
    input  logic [15:0] template_bank [0:TEMPLATE_NUM-1][0:N-1],

    // 최종 출력
    output logic done,                      // 모든 템플릿 계산 완료
    output logic [39:0] max_similarity,     // 가장 높은 similarity
    output logic [$clog2(TEMPLATE_NUM)-1:0] best_id
);

    // descriptor 64개 합치기
    logic [15:0] desc [0:N-1];
    always_comb begin
        for (int i=0; i<16; i++) begin
            desc[i]     = block_hist1[i];
            desc[i+16]  = block_hist2[i];
            desc[i+32]  = block_hist3[i];
            desc[i+48]  = block_hist4[i];
        end
    end

    // FSM 내부 변수
    logic [6:0] idx;
    logic [39:0] accum;
    logic running;
    logic [$clog2(TEMPLATE_NUM)-1:0] tmpl_idx;

    // 내부 최대값 추적
    logic [39:0] best_val;
    logic [$clog2(TEMPLATE_NUM)-1:0] best_idx;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            idx <= 0;
            accum <= 0;
            running <= 0;
            done <= 0;
            tmpl_idx <= 0;
            best_val <= 0;
            best_idx <= 0;
        end else begin
            if (start && !running) begin
                // 초기화
                running <= 1;
                accum <= 0;
                idx <= 0;
                tmpl_idx <= 0;
                best_val <= 0;
                best_idx <= 0;
                done <= 0;
            end else if (running) begin
                accum <= accum + (desc[idx] * template_bank[tmpl_idx][idx]);
                if (idx == N-1) begin
                    // 템플릿 하나 처리 끝 → max 갱신
                    if (accum > best_val) begin
                        best_val <= accum;
                        best_idx <= tmpl_idx;
                    end
                    accum <= 0;
                    idx <= 0;

                    if (tmpl_idx == TEMPLATE_NUM-1) begin
                        running <= 0;
                        done <= 1;  // 모든 템플릿 끝
                    end else begin
                        tmpl_idx <= tmpl_idx + 1;
                    end
                end else begin
                    idx <= idx + 1;
                end
            end else begin
                done <= 0;
            end
        end
    end

    // 최종 출력
    assign max_similarity = best_val;
    assign best_id = best_idx;

endmodule

