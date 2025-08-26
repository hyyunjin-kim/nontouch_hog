`timescale 1ns / 1ps

module Frame_Match #(
  parameter int TPL_NUM    = 48,    // 전체 템플릿 개수
  parameter int MAX_BLOCKS = 1024   // ROI 내부 최대 블록 개수
)(
  input  logic                   clk,
  input  logic                   reset,
  // 한 프레임 분량의 모든 블록 디스크립터가 준비되면 1클럭 펄스
  input  logic                   all_blocks_valid,
  // 블록 개수
  input  logic [$clog2(MAX_BLOCKS)-1:0] block_count,
  // 블록별 HOG 디스크립터 (streaming)
  input  logic [15:0] desc_out   [0:15],
  // 블록별 좌표도 함께 들어온다고 가정
  input  logic        blk_valid,
  input  logic [9:0]  blk_x,
  input  logic [9:0]  blk_y,

  // 최종 결과
  output logic        done,        // 1 클럭짜리 valid 펄스
  output logic [9:0]  hand_x,      // 검출된 블록 의 x
  output logic [9:0]  hand_y,      // 검출된 블록 의 y
  output logic [$clog2(TPL_NUM)-1:0] o_hand_motion  // 검출된 템플릿 ID
);

  logic [$clog2(TPL_NUM)-1:0] hand_motion;

  //------------------------------------------------------------
  // 1) 블록 단위로 루프: block_idx 카운터
  logic [$clog2(MAX_BLOCKS)-1:0] block_idx;
  typedef enum logic [1:0] { IDLE, PROCESS, FINISH } state_t;
  state_t state, next_state;

  // 글로벌 최댓값 추적용 레지스터
  logic signed [35:0] best_score;
  logic [$clog2(MAX_BLOCKS)-1:0] best_blk_idx;
  logic [$clog2(TPL_NUM)-1:0] best_tpl;

  // Template_Match 인스턴스 출력
  logic signed [31:0] tpl_score;    // 가장 높은 템플릿과의 코사인 유사도
  logic        tpl_valid;           // block마다 1 clk later

  // 블록 좌표 latch
  logic [9:0] blk_x_reg, blk_y_reg;

  // 2) FSM state transition
  always_ff @(posedge clk or posedge reset) begin
    if (reset) state <= IDLE;
    else        state <= next_state;
  end

  always_comb begin
    next_state = state;
    case(state)
      IDLE:    if (all_blocks_valid)        next_state = PROCESS;
      PROCESS: if (block_idx == block_count) next_state = FINISH;
      FINISH:  next_state = IDLE;
    endcase
  end

  // 3) main control: 인덱스, 최고값 갱신
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      block_idx    <= 0;
      best_score   <= -36'sd1<<35;  // 충분히 작은 값
      best_blk_idx <= 0;
      best_tpl     <= 0;
      done         <= 0;
    end else begin
      case(state)
        IDLE: begin
          done       <= 0;
          block_idx  <= 0;
          best_score <= -36'sd1<<35;
        end

        PROCESS: begin
          // 매 블록마다 blk_valid로 동기화되어 들어온다고 가정
          if (blk_valid) begin
            // 현재 block 좌표 잠시 저장
            blk_x_reg <= blk_x[block_idx];
            blk_y_reg <= blk_y[block_idx];
            // block_idx를 Template_Match에 넘기고, 1 clk 뒤 tpl_valid/tpl_score 가 유효
            block_idx <= block_idx + 1;
          end

          // 결과가 돌아오면 최고값 갱신
          if (tpl_valid) begin
            if (tpl_score > best_score) begin
              best_score   <= tpl_score;
              best_blk_idx <= block_idx - 1;
              best_tpl     <= hand_motion; // Template_Match 모듈이 hand_motion 으로 뱉어낸 템플릿 ID
            end
          end
        end

        FINISH: begin
          // 모든 블록 끝나면 결과 출력
          done   <= 1;
          hand_x <= blk_x[best_blk_idx];
          hand_y <= blk_y[best_blk_idx];
          o_hand_motion <= best_tpl;
        end
      endcase
    end
  end

  // 4) Template_Match 인스턴스
  //    → blk_valid: desc_valid & blk_valid
  //    → tpl_score, tpl_valid, hand_motion
  Template_Match #(
    .TPL_NUM   (TPL_NUM),
    .VECTOR_LEN(16)
  ) u_tmatch (
    .clk          (clk),
    .reset        (reset),
    .desc_valid    (blk_valid),
    .desc_out     (desc_out),
    .best_score    (tpl_score),
    .best_tpl_id   (hand_motion)
  );

endmodule
