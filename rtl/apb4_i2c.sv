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
// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "i2c_define.svh"

module apb4_i2c (
    apb4_if.slave apb4,
    i2c_if.dut    i2c
);

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [ `I2C_SR_WIDTH-1:0] s_i2c_sr;
  logic [`I2C_RXR_WIDTH-1:0] s_i2c_rxr;
  logic [`I2C_CTRL_WIDTH-1:0] s_i2c_ctrl_d, s_i2c_ctrl_q;
  logic s_i2c_ctrl_en;
  logic [`I2C_PSCR_WIDTH-1:0] s_i2c_pscr_d, s_i2c_pscr_q;
  logic s_i2c_pscr_en;
  logic [`I2C_TXR_WIDTH-1:0] s_i2c_txr_d, s_i2c_txr_q;
  logic s_i2c_txr_en;
  logic [`I2C_CMD_WIDTH-1:0] s_i2c_cmd_d, s_i2c_cmd_q;
  logic s_i2c_cmd_en;

  logic s_bit_ien, s_bit_en;
  logic s_bit_iack, s_bit_ack, s_bit_wr, s_bit_rd, s_bit_sto, s_bit_sta;
  logic s_i2c_done, s_i2c_irxack, s_i2c_busy, s_i2c_al;
  logic s_i2c_rxack_d, s_i2c_rxack_q;
  logic s_i2c_tip_d, s_i2c_tip_q;
  logic s_i2c_irq_d, s_i2c_irq_q;
  logic s_i2c_al_d, s_i2c_al_q;
  logic s_irq_d, s_irq_q;

  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  assign s_bit_ien       = s_i2c_ctrl_q[6];
  assign s_bit_en        = s_i2c_ctrl_q[7];

  assign s_bit_iack      = s_i2c_cmd_q[0];
  assign s_bit_ack       = s_i2c_cmd_q[3];
  assign s_bit_wr        = s_i2c_cmd_q[4];
  assign s_bit_rd        = s_i2c_cmd_q[5];
  assign s_bit_sto       = s_i2c_cmd_q[6];
  assign s_bit_sta       = s_i2c_cmd_q[7];

  assign s_i2c_sr[0]     = s_i2c_irq_q;
  assign s_i2c_sr[1]     = s_i2c_tip_q;
  assign s_i2c_sr[4:2]   = 3'b0;
  assign s_i2c_sr[5]     = s_i2c_al_q;
  assign s_i2c_sr[6]     = s_i2c_busy;
  assign s_i2c_sr[7]     = s_i2c_rxack_q;

  assign i2c.irq_o       = s_irq_q;

  assign s_i2c_ctrl_en   = s_apb4_wr_hdshk && s_apb4_addr == `I2C_CTRL;
  assign s_i2c_ctrl_d    = apb4.pwdata[`I2C_CTRL_WIDTH-1:0];
  dffer #(`I2C_CTRL_WIDTH) u_i2c_ctrl_dffer (
      apb4.pclk,
      apb4.presetn,
      s_i2c_ctrl_en,
      s_i2c_ctrl_d,
      s_i2c_ctrl_q
  );

  assign s_i2c_pscr_en = s_apb4_wr_hdshk && s_apb4_addr == `I2C_PSCR;
  assign s_i2c_pscr_d  = apb4.pwdata[`I2C_PSCR_WIDTH-1:0];
  dfferc #(`I2C_PSCR_WIDTH, `I2C_PSCR_MAX_VAL) u_i2c_pscr_dfferc (
      apb4.pclk,
      apb4.presetn,
      s_i2c_pscr_en,
      s_i2c_pscr_d,
      s_i2c_pscr_q
  );

  assign s_i2c_txr_en = s_apb4_wr_hdshk && s_apb4_addr == `I2C_TXR;
  assign s_i2c_txr_d  = apb4.pwdata[`I2C_TXR_WIDTH-1:0];
  dffer #(`I2C_TXR_WIDTH) u_i2c_txr_dffer (
      apb4.pclk,
      apb4.presetn,
      s_i2c_txr_en,
      s_i2c_txr_d,
      s_i2c_txr_q
  );

  assign s_i2c_cmd_en = (s_i2c_done | s_i2c_al) || (s_apb4_wr_hdshk && s_apb4_addr == `I2C_CMD && s_bit_en);
  always_comb begin
    s_i2c_cmd_d      = s_i2c_cmd_q;
    s_i2c_cmd_d[2:0] = 3'b0;
    if (s_i2c_done | s_i2c_al) begin // clear the cmd flag when trans done or err
      s_i2c_cmd_d[7:4] = 4'b0;
    end else if (s_apb4_wr_hdshk && s_apb4_addr == `I2C_CMD && s_bit_en) begin
      s_i2c_cmd_d = apb4.pwdata[`I2C_CMD_WIDTH-1:0];
    end
  end
  dffer #(`I2C_CMD_WIDTH) u_i2c_cmd_dffer (
      apb4.pclk,
      apb4.presetn,
      s_i2c_cmd_en,
      s_i2c_cmd_d,
      s_i2c_cmd_q
  );

  assign s_i2c_al_d = s_i2c_al | (s_i2c_al_q & (~s_bit_sta));
  dffr #(1) u_i2c_al_dffr (
      apb4.pclk,
      apb4.presetn,
      s_i2c_al_d,
      s_i2c_al_q
  );

  assign s_i2c_rxack_d = s_i2c_irxack;
  dffr #(1) u_i2c_rxack_dffr (
      apb4.pclk,
      apb4.presetn,
      s_i2c_rxack_d,
      s_i2c_rxack_q
  );

  assign s_i2c_tip_d = s_bit_wr | s_bit_rd;
  dffr #(1) u_i2c_tip_dffr (
      apb4.pclk,
      apb4.presetn,
      s_i2c_tip_d,
      s_i2c_tip_q
  );

  assign s_i2c_irq_d = (s_i2c_done | s_i2c_al | s_i2c_irq_q) & (~s_bit_iack);
  dffr #(1) u_i2c_irq_dffr (
      apb4.pclk,
      apb4.presetn,
      s_i2c_irq_d,
      s_i2c_irq_q
  );

  assign s_irq_d = s_i2c_irq_q && s_bit_ien;
  dffr #(1) u_irq_dffr (
      apb4.pclk,
      apb4.presetn,
      s_irq_d,
      s_irq_q
  );

  always_comb begin
    apb4.prdata = '0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `I2C_CTRL: apb4.prdata[`I2C_CTRL_WIDTH-1:0] = s_i2c_ctrl_q;
        `I2C_PSCR: apb4.prdata[`I2C_PSCR_WIDTH-1:0] = s_i2c_pscr_q;
        `I2C_TXR:  apb4.prdata[`I2C_TXR_WIDTH-1:0] = s_i2c_txr_q;
        `I2C_RXR:  apb4.prdata[`I2C_RXR_WIDTH-1:0] = s_i2c_rxr;
        `I2C_SR:   apb4.prdata[`I2C_SR_WIDTH-1:0] = s_i2c_sr;
        default:   apb4.prdata = '0;
      endcase
    end
  end

  i2c_master_byte_ctrl u_i2c_master_byte_ctrl (
      .clk_i     (apb4.pclk),
      .rst_n_i   (apb4.presetn),
      .ena_i     (s_bit_en),
      .clk_cnt_i (s_i2c_pscr_q),
      .start_i   (s_bit_sta),
      .stop_i    (s_bit_sto),
      .read_i    (s_bit_rd),
      .write_i   (s_bit_wr),
      .ack_i     (s_bit_ack),
      .dat_i     (s_i2c_txr_q),
      .cmd_ack_o (s_i2c_done),
      .ack_o     (s_i2c_irxack),
      .dat_o     (s_i2c_rxr),
      .i2c_busy_o(s_i2c_busy),
      .i2c_al_o  (s_i2c_al),
      .scl_i     (i2c.scl_i),
      .scl_o     (i2c.scl_o),
      .scl_dir_o (i2c.scl_dir_o),
      .sda_i     (i2c.sda_i),
      .sda_o     (i2c.sda_o),
      .sda_dir_o (i2c.sda_dir_o)
  );

endmodule
