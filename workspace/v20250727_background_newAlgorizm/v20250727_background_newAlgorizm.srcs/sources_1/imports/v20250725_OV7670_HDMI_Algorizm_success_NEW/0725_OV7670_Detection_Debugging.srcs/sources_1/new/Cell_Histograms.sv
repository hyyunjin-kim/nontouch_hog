module Cell_Histograms (
  input  logic        clk,
  input  logic        reset,
  // from Compute_Gradients
  input  logic [9:0]  grad_x_pix,
  input  logic [9:0]  grad_y_pix,
  input  logic [11:0] abs_G,
  input  logic [1:0]  bin_num,
  input  logic        valid_pixel, 
  // outputs
  output logic        cell_done,
  output logic [5:0]  cell_x,
  output logic [4:0]  cell_y,
  output logic [15:0] hist0, hist1, hist2, hist3,
  output logic        frame_done
);

  // 파라미터
  localparam int CELL_SIZE = 8;
  localparam int NC_X = 320 / CELL_SIZE; // 40
  localparam int NC_Y = 240 / CELL_SIZE; // 30

  // internal histogram storage
  logic [15:0] cells[0:NC_Y-1][0:NC_X-1][0:3];

  // FSM 상태
  typedef enum logic [1:0] {S_IDLE, S_ACCUM, S_CELL_DONE, S_ALL_DONE} state_t;
  state_t state, next_state;

  // 출력용 인덱스
  logic [5:0] out_x;
  logic [4:0] out_y;

  logic [5:0] cx, cy;

  // 1) FSM state register
  always_ff @(posedge clk or posedge reset) begin
    if (reset) state <= S_IDLE;
    else       state <= next_state;
  end

  // 2) FSM next-state & outputs
  always_comb begin
    // default
    next_state = state;
    cell_done  = 0;
    frame_done = 0;
    unique case (state)
      S_IDLE: begin
        // clear memories
        if (valid_pixel) next_state = S_ACCUM;
      end

      S_ACCUM: begin
        if ( grad_x_pix==319 && grad_y_pix==239 && valid_pixel ) begin
          next_state = S_CELL_DONE;
        end
      end

      S_CELL_DONE: begin
        cell_done = 1;
        if (out_y == NC_Y-1 && out_x == NC_X-1) next_state = S_ALL_DONE;
      end

      S_ALL_DONE: begin
        frame_done = 1;
        next_state = S_IDLE;
      end
    endcase
  end

  // 3) Accumulation & clearing
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      // reset all histogram bins
      for (int yy=0; yy<NC_Y; yy++)
        for (int xx=0; xx<NC_X; xx++)
          for (int b=0; b<4; b++)
            cells[yy][xx][b] <= 0;
      out_x <= 0;
      out_y <= 0;
    end else begin
      case (state)
        S_IDLE: begin
          // already cleared by reset
        end

        S_ACCUM: begin
          if (valid_pixel) begin
            // compute cell coords (>>3 대신 /8)
            logic [5:0] cx = grad_x_pix >> 3;
            logic [4:0] cy = grad_y_pix >> 3;
            cells[cy][cx][bin_num] <= cells[cy][cx][bin_num] + abs_G;
          end
        end

        S_CELL_DONE: begin
          // 출력용 인덱스 증가
          if (cell_done) begin
            {out_x, out_y} <= (out_x == NC_X-1)? {0, out_y+1} : {out_x+1, out_y};
          end
        end

        S_ALL_DONE: begin
          // nothing
        end
      endcase
    end
  end

  // 4) 셀 히스토그램을 출력
  assign cell_x = out_x;
  assign cell_y = out_y;
  assign hist0  = cells[out_y][out_x][0];
  assign hist1  = cells[out_y][out_x][1];
  assign hist2  = cells[out_y][out_x][2];
  assign hist3  = cells[out_y][out_x][3];

endmodule
