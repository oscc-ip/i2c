// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.sv"
`include "gpio_pad.sv"
`include "i2c_define.sv"

module apb4_i2c_tb ();
  localparam CLK_PEROID = 10;
  logic rst_n_i, clk_i;
  wire s_scl_pad, s_sda_pad;
  pullup (s_scl_pad);
  pullup (s_sda_pad);

  initial begin
    clk_i = 1'b0;
    forever begin
      #(CLK_PEROID / 2) clk_i <= ~clk_i;
    end
  end

  task sim_reset(int delay);
    rst_n_i = 1'b0;
    repeat (delay) @(posedge clk_i);
    #1 rst_n_i = 1'b1;
  endtask

  initial begin
    sim_reset(40);
  end

  apb4_if u_apb4_if (
      clk_i,
      rst_n_i
  );

  i2c_if u_i2c_if ();

  tri_pd_pad_h u_scl_pad (
      .i_i   (u_i2c_if.scl_o),
      .oen_i (u_i2c_if.scl_dir_o),
      .ren_i (),
      .c_o   (u_i2c_if.scl_i),
      .pad_io(s_scl_pad)
  );
  tri_pd_pad_h u_sda_pad (
      .i_i   (u_i2c_if.sda_o),
      .oen_i (u_i2c_if.sda_dir_o),
      .ren_i (),
      .c_o   (u_i2c_if.sda_i),
      .pad_io(s_sda_pad)
  );

  test_top u_test_top (u_apb4_if.master);
  apb4_i2c u_apb4_i2c (
      .apb4(u_apb4_if.slave),
      .i2c (u_i2c_if.dut)
  );

  AT24C04 u_AT24C04 (
      .WP (1'b0),
      .SCL(s_scl_pad),
      .SDA(s_sda_pad)
  );
endmodule
