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
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "i2c_define.sv"

module i2c_master_byte_ctrl (
    input             clk_i,
    input             rst_n_i,
    input             ena_i,
    input      [15:0] clk_cnt_i,
    input             start_i,
    input             stop_i,
    input             read_i,
    input             write_i,
    input             ack_i,
    input      [ 7:0] dat_i,
    output reg        cmd_ack_o,
    output reg        ack_o,
    output     [ 7:0] dat_o,
    output            i2c_busy_o,
    output            i2c_al_o,
    input             scl_i,
    output            scl_o,
    output            scl_dir_o,
    input             sda_i,
    output            sda_o,
    output            sda_dir_o
);

  // statemachine
  parameter [4:0] ST_IDLE = 5'b0_0000;
  parameter [4:0] ST_START = 5'b0_0001;
  parameter [4:0] ST_READ = 5'b0_0010;
  parameter [4:0] ST_WRITE = 5'b0_0100;
  parameter [4:0] ST_ACK = 5'b0_1000;
  parameter [4:0] ST_STOP = 5'b1_0000;

  // signals for bit_controller
  reg [3:0] core_cmd;
  reg       core_txd;
  wire core_ack, core_rxd;

  // signals for shift register
  reg [7:0] sr;  //8bit shift register
  reg shift, ld;

  // signals for state machine
  wire       go;
  reg  [2:0] dcnt;
  wire       cnt_done;

  // hookup bit_controller
  i2c_master_bit_ctrl u_i2c_master_bit_ctrl (
      .clk_i    (clk_i),
      .rst_n_i  (rst_n_i),
      .ena_i    (ena_i),
      .clk_cnt_i(clk_cnt_i),
      .cmd_i    (core_cmd),
      .cmd_ack_o(core_ack),
      .busy_o   (i2c_busy_o),
      .al_o     (i2c_al_o),
      .dat_i    (core_txd),
      .dat_o    (core_rxd),
      .scl_i    (scl_i),
      .scl_o    (scl_o),
      .scl_dir_o(scl_dir_o),
      .sda_i    (sda_i),
      .sda_o    (sda_o),
      .sda_dir_o(sda_dir_o)
  );

  // generate go-signal
  assign go    = (read_i | write_i | stop_i) & ~cmd_ack_o;

  // assign dat_o output to shift-register
  assign dat_o = sr;

  // generate shift register
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) sr <= #1 8'h0;
    else if (ld) sr <= #1 dat_i;
    else if (shift) sr <= #1{sr[6:0], core_rxd};  // tx and rx use one shift register

  // generate counter
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) dcnt <= #1 3'h0;
    else if (ld) dcnt <= #1 3'h7;
    else if (shift) dcnt <= #1 dcnt - 3'h1;

  assign cnt_done = ~(|dcnt);

  reg [4:0] c_state;
  always @(posedge clk_i or negedge rst_n_i)
    if (!rst_n_i) begin
      core_cmd  <= #1 `I2C_CMD_NOP;
      core_txd  <= #1 1'b0;
      shift     <= #1 1'b0;
      ld        <= #1 1'b0;
      cmd_ack_o <= #1 1'b0;
      c_state   <= #1 ST_IDLE;
      ack_o     <= #1 1'b0;
    end else if (i2c_al_o) begin
      core_cmd  <= #1 `I2C_CMD_NOP;
      core_txd  <= #1 1'b0;
      shift     <= #1 1'b0;
      ld        <= #1 1'b0;
      cmd_ack_o <= #1 1'b0;
      c_state   <= #1 ST_IDLE;
      ack_o     <= #1 1'b0;
    end else begin
      // initially reset all signals
      core_txd  <= #1 sr[7];
      shift     <= #1 1'b0;
      ld        <= #1 1'b0;
      cmd_ack_o <= #1 1'b0;

      case (c_state)  // synopsys full_case parallel_case
        ST_IDLE:
        if (go) begin
          if (start_i) begin
            c_state  <= #1 ST_START;
            core_cmd <= #1 `I2C_CMD_START;
          end else if (read_i) begin
            c_state  <= #1 ST_READ;
            core_cmd <= #1 `I2C_CMD_READ;
          end else if (write_i) begin
            c_state  <= #1 ST_WRITE;
            core_cmd <= #1 `I2C_CMD_WRITE;
          end else  // stop_i
          begin
            c_state  <= #1 ST_STOP;
            core_cmd <= #1 `I2C_CMD_STOP;
          end

          ld <= #1 1'b1;
        end

        ST_START:
        if (core_ack) begin
          if (read_i) begin
            c_state  <= #1 ST_READ;
            core_cmd <= #1 `I2C_CMD_READ;
          end else begin
            c_state  <= #1 ST_WRITE;
            core_cmd <= #1 `I2C_CMD_WRITE;
          end

          ld <= #1 1'b1;
        end

        ST_WRITE:
        if (core_ack)
          if (cnt_done) begin
            c_state  <= #1 ST_ACK;
            core_cmd <= #1 `I2C_CMD_READ; // NOTE: read the ack
          end else begin
            c_state  <= #1 ST_WRITE;  // stay in same state
            core_cmd <= #1 `I2C_CMD_WRITE;  // write_i next bit
            shift    <= #1 1'b1;
          end

        ST_READ:
        if (core_ack) begin
          if (cnt_done) begin
            c_state  <= #1 ST_ACK;
            core_cmd <= #1 `I2C_CMD_WRITE; // NOTE: write the ack
          end else begin
            c_state  <= #1 ST_READ;  // stay in same state
            core_cmd <= #1 `I2C_CMD_READ;  // read_i next bit
          end

          shift    <= #1 1'b1;
          core_txd <= #1 ack_i;
        end

        ST_ACK:
        if (core_ack) begin
          if (stop_i) begin
            c_state  <= #1 ST_STOP;
            core_cmd <= #1 `I2C_CMD_STOP;
          end else begin
            c_state   <= #1 ST_IDLE;
            core_cmd  <= #1 `I2C_CMD_NOP;

            // generate command acknowledge signal
            cmd_ack_o <= #1 1'b1;
          end

          // assign ack_o output to bit_controller_rxd (contains last received bit)
          ack_o    <= #1 core_rxd;

          core_txd <= #1 1'b1;
        end else core_txd <= #1 ack_i;

        ST_STOP:
        if (core_ack) begin
          c_state   <= #1 ST_IDLE;
          core_cmd  <= #1 `I2C_CMD_NOP;

          // generate command acknowledge signal
          cmd_ack_o <= #1 1'b1;
        end

      endcase
    end
endmodule
