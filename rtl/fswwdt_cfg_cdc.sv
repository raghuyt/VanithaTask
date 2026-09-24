// ----------------------------------------------------------------------------
// pclk -> wdt_clk configuration handshake.
// 4-phase req/ack. data_hold is stable for a full src cycle before req rises,
// and stays stable until ack returns, so the destination may sample it directly.
// A push that arrives while a transfer is in flight updates the shadow.
// The latest write wins. That is the right policy for configuration.
// ----------------------------------------------------------------------------
`default_nettype none

module fswwdt_cfg_cdc #(
  parameter int unsigned W = 32
) (
  input  logic             src_clk,
  input  logic             src_rst_n,
  input  logic             src_push,
  input  logic [W-1:0]     src_data,
  input  logic             dst_clk,
  input  logic             dst_rst_n,
  output logic             dst_valid,
  output logic [W-1:0]     dst_data
);
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_LOAD,
    ST_WAIT_ACK,
    ST_WAIT_ACK0
  } st_e;

  st_e             state;
  logic            req;
  logic            ack;
  logic            req_s;
  logic            ack_s;
  logic            pend;
  logic [W-1:0]    shadow;
  logic [W-1:0]    data_hold;

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
      state     <= ST_IDLE;
      req       <= 1'b0;
      pend      <= 1'b0;
      shadow    <= '0;
      data_hold <= '0;
    end else begin
      if (src_push) begin
        shadow <= src_data;
        pend   <= 1'b1;
      end

      case (state)
        ST_IDLE: begin
          if (pend && src_push) begin
            // Same-cycle push: send the new word, not the pre-push shadow.
            data_hold <= src_data;
            pend      <= 1'b0;
            state     <= ST_LOAD;
          end else if (pend && !src_push) begin
            data_hold <= shadow;
            pend      <= 1'b0;
            state     <= ST_LOAD;
          end
        end
        ST_LOAD: begin
          req   <= 1'b1;
          state <= ST_WAIT_ACK;
        end
        ST_WAIT_ACK: begin
          if (ack_s) begin
            req   <= 1'b0;
            state <= ST_WAIT_ACK0;
          end
        end
        ST_WAIT_ACK0: begin
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
      dst_valid <= 1'b0;
      dst_data  <= '0;
    end else begin
      dst_valid <= 1'b0;
      if (req_s && !ack) begin
        dst_data  <= data_hold;
        dst_valid <= 1'b1;
        ack       <= 1'b1;
      end else if (!req_s && ack) begin
        ack <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire
