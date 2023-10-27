/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE rev.B2 compliant I2C Master byte-controller       ////
////                                                             ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/projects/i2c/    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// common is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "i2c_master_defines.sv"

module i2c_master_byte_ctrl (
    input  logic        clk_i,
    input  logic        rst_n_i,
    input  logic        ena_i,
    input  logic [15:0] clk_cnt_i,   // 4x SCL
    input  logic        start_i,
    input  logic        stop_i,
    input  logic        read_i,
    input  logic        write_i,
    input  logic        ack_i,
    input  logic [ 7:0] dat_i,
    output logic        cmd_ack_o,
    output logic        ack_o,
    output logic [ 7:0] dat_o,
    output logic        i2c_busy_o,
    output logic        i2c_al_o,
    input  logic        scl_i,
    output logic        scl_o,
    output logic        scl_dir_o,
    input  logic        sda_i,
    output logic        sda_o,
    output logic        sda_dir_o
);

  reg r_cmd_ack, r_ack;
  assign cmd_ack_o = r_cmd_ack;
  assign ack_o     = r_ack;

  // statemachine
  parameter [4:0] ST_IDLE = 5'b0_0000;
  parameter [4:0] ST_START = 5'b0_0001;
  parameter [4:0] ST_READ = 5'b0_0010;
  parameter [4:0] ST_WRITE = 5'b0_0100;
  parameter [4:0] ST_ACK = 5'b0_1000;
  parameter [4:0] ST_STOP = 5'b1_0000;

  // signals for bit_controller
  reg [3:0] r_core_cmd;
  reg       r_core_txd;
  wire s_core_ack, s_core_rxd;

  reg [7:0] r_shift;
  reg r_shift, r_ld;

  // signals for state machine
  wire s_go, s_cnt_done;
  reg [2:0] r_dcnt;

  i2c_master_bit_ctrl u_i2c_master_bit_ctrl (
      .clk_i    (clk_i),
      .rst_n_i  (rst_n_i),
      .ena_i    (ena_i),
      .clk_cnt_i(clk_cnt_i),
      .cmd_i    (r_core_cmd),
      .cmd_ack_o(s_core_ack),
      .busy_o   (i2c_busy_o),
      .al_o     (i2c_al_o),
      .dat_i    (r_core_txd),
      .dat_o    (s_core_rxd),
      .scl_i,
      .scl_o,
      .scl_dir_o,
      .sda_i,
      .sda_o,
      .sda_dir_o
  );

  // generate s_go-signal
  assign s_go  = (read_i | write_i | stop_i) & ~r_cmd_ack;
  // assign dat_o output to r_shift-register
  assign dat_o = r_shift;

  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) r_shift <= 8'h0;
    else if (r_ld) r_shift <= dat_i;
    else if (r_shift) r_shift <= {r_shift[6:0], s_core_rxd};

  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) r_dcnt <= 3'h0;
    else if (r_ld) r_dcnt <= 3'h7;
    else if (r_shift) r_dcnt <= r_dcnt - 3'h1;

  assign s_cnt_done = ~(|r_dcnt);


  reg [4:0] r_c_state;
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) begin
      r_core_cmd <= `I2C_CMD_NOP;
      r_core_txd <= 1'b0;
      r_shift    <= 1'b0;
      r_ld       <= 1'b0;
      r_cmd_ack  <= 1'b0;
      r_c_state  <= ST_IDLE;
      r_ack      <= 1'b0;
    end else if (i2c_al_o) begin
      r_core_cmd <= `I2C_CMD_NOP;
      r_core_txd <= 1'b0;
      r_shift    <= 1'b0;
      r_ld       <= 1'b0;
      r_cmd_ack  <= 1'b0;
      r_c_state  <= ST_IDLE;
      r_ack      <= 1'b0;
    end else begin
      // initially reset all signals
      r_core_txd <= r_shift[7];
      r_shift    <= 1'b0;
      r_ld       <= 1'b0;
      r_cmd_ack  <= 1'b0;

      case (r_c_state)  // synopsys full_case parallel_case
        ST_IDLE:
        if (s_go) begin
          if (start_i) begin
            r_c_state  <= ST_START;
            r_core_cmd <= `I2C_CMD_START;
          end else if (read_i) begin
            r_c_state  <= ST_READ;
            r_core_cmd <= `I2C_CMD_READ;
          end else if (write_i) begin
            r_c_state  <= ST_WRITE;
            r_core_cmd <= `I2C_CMD_WRITE;
          end else  // stop_i
          begin
            r_c_state  <= ST_STOP;
            r_core_cmd <= `I2C_CMD_STOP;
          end

          r_ld <= 1'b1;
        end

        ST_START:
        if (s_core_ack) begin
          if (read_i) begin
            r_c_state  <= ST_READ;
            r_core_cmd <= `I2C_CMD_READ;
          end else begin
            r_c_state  <= ST_WRITE;
            r_core_cmd <= `I2C_CMD_WRITE;
          end

          r_ld <= 1'b1;
        end

        ST_WRITE:
        if (s_core_ack)
          if (s_cnt_done) begin
            r_c_state  <= ST_ACK;
            r_core_cmd <= `I2C_CMD_READ;
          end else begin
            r_c_state  <= ST_WRITE;  // stay in same state
            r_core_cmd <= `I2C_CMD_WRITE;  // write_i next bit
            r_shift    <= 1'b1;
          end

        ST_READ:
        if (s_core_ack) begin
          if (s_cnt_done) begin
            r_c_state  <= ST_ACK;
            r_core_cmd <= `I2C_CMD_WRITE;
          end else begin
            r_c_state  <= ST_READ;  // stay in same state
            r_core_cmd <= `I2C_CMD_READ;  // read_i next bit
          end

          r_shift    <= 1'b1;
          r_core_txd <= ack_i;
        end

        ST_ACK:
        if (s_core_ack) begin
          if (stop_i) begin
            r_c_state  <= ST_STOP;
            r_core_cmd <= `I2C_CMD_STOP;
          end else begin
            r_c_state  <= ST_IDLE;
            r_core_cmd <= `I2C_CMD_NOP;

            // generate command acknowledge signal
            r_cmd_ack  <= 1'b1;
          end

          // assign r_ack output to bit_controller_rxd (contains last received bit)
          r_ack      <= s_core_rxd;

          r_core_txd <= 1'b1;
        end else r_core_txd <= ack_i;

        ST_STOP:
        if (s_core_ack) begin
          r_c_state  <= ST_IDLE;
          r_core_cmd <= `I2C_CMD_NOP;

          // generate command acknowledge signal
          r_cmd_ack  <= 1'b1;
        end

      endcase
    end
endmodule
