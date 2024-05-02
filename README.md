# I2C

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

FULL vision of datatsheet can be found in [datasheet.md](./doc/datasheet.md).

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```