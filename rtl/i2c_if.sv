// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// i2c is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

interface i2c_if ();
  logic scl_i;
  logic scl_o;
  logic scl_dir_o;
  logic sda_i;
  logic sda_o;
  logic sda_dir_o;
  logic irq_o;

  modport dut(
      input scl_i,
      output scl_o,
      output scl_dir_o,
      input sda_i,
      output sda_o,
      output sda_dir_o,
      output irq_o
  );

  modport tb(
      output scl_i,
      input scl_o,
      input scl_dir_o,
      output sda_i,
      input sda_o,
      input sda_dir_o,
      input irq_o
  );
endinterface