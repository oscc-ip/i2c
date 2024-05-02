## Datasheet

### Overview
The `i2c(inter-integrated circuit)` IP is a fully parameterised soft IP to implement the standard i2c master interface. The IP features an APB4 slave interface, fully compliant with the AMBA APB Protocol Specification v2.0.

### Feature
* Compatible with Philips I2C standard
* Programmable prescaler
    * max division factor is up to 2^16
* 100Kbps, 400Kbps or 1Mbps support
* 7 bits addressing mode only
* Single master mode only
* Maskable send or receive interrupt
* Static synchronous design
* Full synthesizable

### Interface
| port name | type        | description          |
|:--------- |:------------|:---------------------|
| apb4      | interface   | apb4 slave interface |
| i2c ->    | interface   | i2c slave interface |
| `i2c.scl_i` | input | i2c clock input |
| `i2c.scl_o` | output | i2c clock output |
| `i2c.scl_dir_o` | output | i2c clock tri-state ctrl |
| `i2c.sda_i` | input | i2c data input |
| `i2c.sda_o` | output | i2c data output |
| `i2c.sda_dir_o` | output | i2c data tri-state ctrl |
| `i2c.irq_o` | output | i2c irq output |

### Register

| name | offset  | length | description |
|:----:|:-------:|:-----: | :---------: |
| [CTRL](#control-register) | 0x0 | 4 | control register |
| [PSCR](#prescaler-reigster) | 0x4 | 4 | prescaler register |
| [TXR](#transmit-reigster) | 0x8 | 4 | transmit register |
| [RXR](#receive-reigster) | 0xC | 4 | receive register |
| [CMD](#command-reigster) | 0x10 | 4 | command register |
| [SR](#state-reigster) | 0x14 | 4 | state register |

#### Control Register
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:8]` | none | reserved |
| `[7:7]` | RW | EN |
| `[6:6]` | RW | IEN |
| `[5:0]` | none | reserved |

reset value: `0x0000_0000`

* EN: function enable
* IEN: interrupt enable

#### Prescaler Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:16]` | none | reserved |
| `[15:0]` | RW | PSCR |

reset value: `0x0000_0002`

* PSCR: 16-bit prescaler value

#### Transmit Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:8]` | none | reserved |
| `[7:0]` | RW | DATA |

reset value: `0x0000_0000`

* DATA: transmit value

#### Receive Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:8]` | none | reserved |
| `[7:0]` | RO | DATA |

reset value: `0x0000_0000`

* DATA: receive data

#### Command Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:8]` | none | reserved |
| `[7:7]` | WO | STA |
| `[6:6]` | WO | STO |
| `[5:5]` | WO | RD |
| `[4:4]` | WO | WR |
| `[3:3]` | WO | ACK |
| `[2:1]` | none | reserved |
| `[0:0]` | WO | IACK |

reset value: `0x0000_xxxx`

* STA:
* STO:
* RD:
* WR:
* ACK:
* IACK:

#### State Reigster
| bit | access  | description |
|:---:|:-------:| :---------: |
| `[31:8]` | none | reserved |
| `[7:7]` | RO | RXK |
| `[6:6]` | RO | BSY |
| `[5:5]` | RO | AL |
| `[4:2]` | none | reserved |
| `[1:1]` | RO | TIP |
| `[0:0]` | RO | IF |

reset value: `0xxxxx_xxxx`

* RXK:
* BSY:
* AL:
* TIP:
* IF:

### Program Guide
These registers can be accessed by 4-byte aligned read and write. C-like pseudocode read operation:
```c
uint32_t val;
val = i2c.SYS // read the sys register
val = i2c.IDL // read the idl register
val = i2c.IDH // read the idh register

```
write operation:
```c
uint32_t val = value_to_be_written;
i2c.SYS = val // write the sys register
i2c.IDL = val // write the idl register
i2c.IDH = val // write the idh register

```

### Resoureces
### References
### Revision History