// ----------------------------------------------------------------------------
// Single-cycle pulse synchronizer with a depth-3 pending count.
// Back-to-back pclk services are not collapsed the way a plain toggle CDC
// collapses them. A 4th pulse that arrives while 3 are already queued sets
// overflow and is dropped.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_pulse_cdc (
  input  logic src_clk,
  input  logic src_rst_n,
  input  logic src_pulse,
  input  logic dst_clk,
  input  logic dst_rst_n,
  output logic dst_pulse,
  output logic overflow
);
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_ASSERT,
    ST_WAIT0
  } st_e;

  st_e state;
  logic req;
  logic ack;
  logic req_s;
  logic ack_s;
  logic [1:0] pending;

  fswwdt_sync2_vec #(.W(1)) u_req_sync (
    .clk   (dst_clk),
    .rst_n (dst_rst_n),
    .d     (req),
    .q     (req_s)
  );

  fswwdt_sync2_vec #(.W(1)) u_ack_sync (
    .clk   (src_clk),
    .rst_n (src_rst_n),
    .d     (ack),
    .q     (ack_s)
  );

  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) begin
      state    <= ST_IDLE;
      req      <= 1'b0;
      pending  <= 2'b00;
      overflow <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          if ((pending != 2'b00) || src_pulse) begin
            req   <= 1'b1;
            state <= ST_ASSERT;
            // One event is consumed by this launch.
            // pulse && pending : net pending unchanged (consume 1, add 1).
            // pending && !pulse: consume 1.
            // pulse && !pending: pending stays 0.
            if ((pending != 2'b00) && !src_pulse)
              pending <= pending - 2'b01;
          end
        end
        ST_ASSERT: begin
          if (src_pulse) begin
            if (pending == 2'b11)
              overflow <= 1'b1;
            else
              pending <= pending + 2'b01;
          end
          if (ack_s) begin
            req   <= 1'b0;
            state <= ST_WAIT0;
          end
        end
        ST_WAIT0: begin
          if (src_pulse) begin
            if (pending == 2'b11)
              overflow <= 1'b1;
            else
              pending <= pending + 2'b01;
          end
          if (!ack_s)
            state <= ST_IDLE;
        end
        default: begin
          req   <= 1'b0;
          state <= ST_IDLE;
        end
      endcase
    end
  end

  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      ack       <= 1'b0;
      dst_pulse <= 1'b0;
    end else begin
      dst_pulse <= 1'b0;
      if (req_s && !ack) begin
        dst_pulse <= 1'b1;
        ack       <= 1'b1;
      end else if (!req_s && ack) begin
        ack <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire
