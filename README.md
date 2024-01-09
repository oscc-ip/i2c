# I2C

<p>
    <a href=".">
      <img src="https://img.shields.io/badge/RTL%20dev-done-green?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/VCS%20sim-done-green?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/FPGA%20verif-no%20start-wheat?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/Tapeout%20test-no%20start-wheat?style=flat-square">
    </a>
</p>

## Features
* Compatible with Philips I2C standard
* Programmable prescaler
    * max division factor is up to 2^16
* 100Kbps, 400Kbps or 1Mbps support
* 7 bits addressing mode only
* Single master mode only
* Maskable send or receive interrupt
* Static synchronous design
* Full synthesizable

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```