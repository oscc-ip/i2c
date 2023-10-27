// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023 Beijing Institute of Open Source Chip
// gpio is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

// verilog_format: off
`define I2C_PSCR 4'b0000 //BASEADDR+0x00
`define I2C_CTRL 4'b0001 //BASEADDR+0x04
`define I2C_TXR  4'b0010 //BASEADDR+0x08
`define I2C_RXR  4'b0011 //BASEADDR+0x0C
`define I2C_CMD  4'b0100 //BASEADDR+0x10
`define I2C_SR   4'b0101 //BASEADDR+0x14
// verilog_format: on

module apb4_i2c (
    // verilog_format: off
    apb4_if.slave apb4,
    // verilog_format: on
    input logic  scl_i,
    output logic scl_o,
    output logic scl_dir_o,
    input logic  sda_i,
    output logic sda_o,
    output logic sda_dir_o,
    output logic irq_o
);

  logic [3:0] s_apb_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [15:0] s_i2c_pscr_d, s_i2c_pscr_q;
  logic [7:0] s_i2c_ctrl_d, s_i2c_ctrl_q;
  logic [7:0] s_i2c_txr_d, s_i2c_txr_q;
  logic [7:0] s_i2c_rxr;
  logic [7:0] s_i2c_cmd_d, s_i2c_cmd_q;
  logic [7:0] s_i2c_sr;
  logic s_i2c_done, s_i2c_en, s_i2c_ien, s_i2c_irxack;
  logic s_i2c_rxack_d, s_i2c_rxack_q;
  logic s_i2c_tip_d, s_i2c_tip_q;
  logic s_i2c_irq_d, s_i2c_irq_q;
  logic s_i2c_busy, s_i2c_al;
  logic s_i2c_al_d, s_i2c_al_q;
  logic s_irq_d, s_irq_q;

  assign s_apb_addr      = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign s_i2c_en        = s_i2c_ctrl_q[7];
  assign s_i2c_ien       = s_i2c_ctrl_q[6];
  assign s_i2c_sr[7]     = s_i2c_rxack_q;
  assign s_i2c_sr[6]     = s_i2c_busy;
  assign s_i2c_sr[5]     = s_i2c_al_q;
  assign s_i2c_sr[4:2]   = 3'b0;
  assign s_i2c_sr[1]     = s_i2c_tip_q;
  assign s_i2c_sr[0]     = s_i2c_irq_q;
  assign irq_o           = s_irq_q;


  dffr #(16) u_i2c_pscr_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_pscr_d,
      s_i2c_pscr_q
  );

  assign s_i2c_pscr_d = s_apb4_wr_hdshk && (s_apb_addr == `I2C_PSCR) ? apb4.pwdata[15:0] : s_i2c_pscr_q;
  assign s_i2c_ctrl_d = s_apb4_wr_hdshk && (s_apb_addr == `I2C_CTRL) ? apb4.pwdata[7:0] : s_i2c_ctrl_q;
  dffr #(8) u_i2c_ctrl_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_ctrl_d,
      s_i2c_ctrl_q
  );

  assign s_i2c_txr_d = s_apb4_wr_hdshk && (s_apb_addr == `I2C_TXR) ? apb4.pwdata[7:0] : s_i2c_txr_q;
  dffr #(8) u_i2c_txr_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_txr_d,
      s_i2c_txr_q
  );


  always_comb begin
    s_i2c_cmd_d[7:3] = s_i2c_cmd_q[7:3];
    s_i2c_cmd_d[2:0] = 3'b0;

    if (s_apb4_wr_hdshk && s_apb_addr == `I2C_CMD && s_i2c_en) begin
      s_i2c_cmd_d = apb4.pwdata[7:0];
    end else if (s_i2c_done | s_i2c_al) begin
      s_i2c_cmd_d[7:4] = 4'b0;
    end
  end

  dffr #(8) u_i2c_cmd_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_cmd_d,
      s_i2c_cmd_q
  );

  assign s_i2c_al_d = s_i2c_al | (s_i2c_al_q & (~s_i2c_cmd_q[7]));
  dffr #(1) u_i2c_al_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_al_d,
      s_i2c_al_q
  );

  assign s_i2c_rxack_d = s_i2c_irxack;
  dffr #(1) u_i2c_rxack_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_rxack_d,
      s_i2c_rxack_q
  );

  assign s_i2c_tip_d = s_i2c_cmd_q[5] | s_i2c_cmd_q[4];
  dffr #(1) u_i2c_tip_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_tip_d,
      s_i2c_tip_q
  );

  assign s_i2c_irq_d = (s_i2c_done | s_i2c_al | s_i2c_irq_q) & (~s_i2c_cmd_q[0]);
  dffr #(1) u_i2c_irq_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_i2c_irq_d,
      s_i2c_irq_q
  );

  assign s_irq_d = s_i2c_irq_q && s_i2c_ien;
  dffr #(1) u_irq_dffr (
      apb4.hclk,
      apb4.hresetn,
      s_irq_d,
      s_irq_q
  );

  always_comb begin
    apb4.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb_addr)
        `I2C_PSCR: apb4.prdata = {16'b0, s_i2c_pscr_q};
        `I2C_CTRL: apb4.prdata = {24'b0, s_i2c_ctrl_q};
        `I2C_TXR:  apb4.prdata = {24'b0, s_i2c_txr_q};
        `I2C_RXR:  apb4.prdata = {24'b0, s_i2c_rxr_q};
        `I2C_CMD:  apb4.prdata = {24'b0, s_i2c_cmd_q};
        `I2C_SR:   apb4.prdata = {24'b0, s_i2c_sr};
      endcase
    end
  end

  i2c_master_byte_ctrl u_i2c_master_byte_ctrl (
      .clk_i     (apb4.hclk),
      .rst_n_i   (apb4.hresetn),
      .ena_i     (s_i2c_en),
      .clk_cnt_i (s_i2c_pscr_q),
      .start_i   (s_i2c_cmd_q[7]),
      .stop_i    (s_i2c_cmd_q[6]),
      .read_i    (s_i2c_cmd_q[5]),
      .write_i   (s_i2c_cmd_q[4]),
      .ack_i     (s_i2c_cmd_q[3]),
      .dat_i     (s_i2c_txr_q),
      .cmd_ack_o (s_i2c_done),
      .ack_o     (s_i2c_irxack),
      .dat_o     (s_i2c_rxr),
      .i2c_busy_o(s_i2c_busy),
      .i2c_al_o  (s_i2c_al),
      .scl_i,
      .scl_o,
      .scl_dir_o,
      .sda_i,
      .sda_o,
      .sda_dir_o
  );

  assign apb4.pready  = 1'b1;
  assign apb4.pslverr = 1'b0;

endmodule
