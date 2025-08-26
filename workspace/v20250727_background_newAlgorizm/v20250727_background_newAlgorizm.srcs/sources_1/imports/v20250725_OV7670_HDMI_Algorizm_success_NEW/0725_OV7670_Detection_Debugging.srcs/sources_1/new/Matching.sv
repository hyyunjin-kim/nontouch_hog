`timescale 1ns / 1ps

module Matching (
  input  logic        clk,
  input  logic        reset,
  // ROI 경계 & 유효 신호
  input  logic [9:0]  min_x, min_y,
  input  logic [9:0]  max_x, max_y,
  input  logic        roi_valid,
  // Frame Buffer 포트 B (읽기 전용)
  output logic [16:0] fb_addr,    // y_cur*WIDTH + x_cur
  input  logic [7:0]  fb_gray,    // BRAM에서 읽혀 들어오는 픽셀
  // HOG 블록 디스크립터 출력
  output logic        blk_valid,
  output logic [15:0] desc_out [0:15],
  output logic [9:0] blk_x,
  output logic [9:0] blk_y,
  output logic all_blocks_valid
);
  localparam int WIDTH  = 320;
  // ROI 순회를 위한 카운터
  logic [9:0] x_cur, y_cur;
  typedef enum logic [1:0] { 
    S_IDLE,      // ROI 대기
    S_READ_PIX,  // ROI 내부 픽셀 읽기
    S_DONE       // ROI 처리 완료
  } state_t;
  state_t state, next_state;
  logic [9:0] x_next, y_next;

// 1) next-state / next-counters 계산 (combinational)
always_comb begin
  next_state = state;
  x_next = x_cur;
  y_next = y_cur;

  case (state)
    S_IDLE: begin
      if (roi_valid) begin
        next_state = S_READ_PIX;
        x_next = min_x;
        y_next = min_y;
      end
    end

    S_READ_PIX: begin
      // ROI 순회 중
      if (x_cur == max_x) begin
        x_next = min_x;
        y_next = y_cur + 1;
      end else begin
        x_next = x_cur + 1;
      end
      if (y_cur == max_y && x_cur == max_x)
        next_state = S_DONE;
    end

    S_DONE: begin
      next_state = S_IDLE;
    end
  endcase
end

// 2) state 및 counters 업데이트 (sequential)
always_ff @(posedge clk) begin
  if (reset) begin
    state <= S_IDLE;
    x_cur <= 0;
    y_cur <= 0;
    fb_addr <= 0;
    all_blocks_valid <= 0;
  end else begin
    state <= next_state;
    x_cur <= x_next;
    y_cur <= y_next;

    case (state)
      S_IDLE: begin
        all_blocks_valid <= 0;
      end

      S_READ_PIX: begin
        fb_addr <= y_cur * WIDTH + x_cur;
      end

      S_DONE: begin
        all_blocks_valid <= 1;
      end
    endcase
  end
end


  // ----
  // 여기서 fb_gray를 받아서 Compute_Gradients → Cell_Histograms → Block_Normalize
  // → desc_out[0..15] 에 스트리밍으로 연결합니다.
  // ----

logic [9:0]  grad_x_pix;
logic [9:0]  grad_y_pix;
logic [11:0] abs_G;
logic [1:0]  bin_num;
logic        cell_done;
logic [5:0]  cell_x;
logic [4:0]  cell_y;
logic [15:0] hist0, hist1, hist2, hist3;
logic frame_done;

Compute_Gradients U_Compute_Gradients(
    .clk(clk),
    .reset(reset),
    .gray_in(fb_gray),       // 입력: 8비트 그레이스케일 영상
    .x_pixel(x_cur),       // 현재 x좌표
    .y_pixel(y_cur),       // 현재 y좌표
    .abs_G(abs_G),      // 출력: 그라디언트 절댓값
    .bin_num(bin_num),     //출력: bin(0~3)
    .grad_x_pix(grad_x_pix),
    .grad_y_pix(grad_y_pix),
    .valid_pixel(valid_pixel)
);

Cell_Histograms U_Cell_Histograms(
  .reset(reset),
  .clk(clk),
  // from Compute_Gradients
  .grad_x_pix(grad_x_pix),
  .grad_y_pix(grad_y_pix),
  .abs_G(abs_G),
  .bin_num(bin_num),
  .valid_pixel(valid_pixel), 
  // outputs
  .cell_done(cell_done),
  .cell_x(cell_x),
  .cell_y(cell_y),
  .hist0(hist0), 
  .hist1(hist1), 
  .hist2(hist2), 
  .hist3(hist3),
  .frame_done(frame_done)
);

Block_Normalize U_Block_Normalize(
  .clk(clk),
  .reset(reset),
  // Cell_Histograms 출력 (시퀀셜)
  .cell_done(cell_done),
  .cell_x(cell_x), 
  .cell_y(cell_y), // 셀 좌표
  .hist0(hist0), 
  .hist1(hist1), 
  .hist2(hist2), 
  .hist3(hist3),
  .blk_valid(blk_valid),      // 블록 디스크립터 유효
  .desc(desc_out),     // 정규화된 블록 벡터
  .blk_x(blk_x),
  .blk_y(blk_y)

);

endmodule
