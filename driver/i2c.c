#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#define I2C_BASE_ADDR        0x10004000
#define I2C_REG_CTRL         *((volatile uint32_t *)(I2C_BASE_ADDR))
#define I2C_REG_PSCR         *((volatile uint32_t *)(I2C_BASE_ADDR + 4))
#define I2C_REG_TXR          *((volatile uint32_t *)(I2C_BASE_ADDR + 8))
#define I2C_REG_RXR          *((volatile uint32_t *)(I2C_BASE_ADDR + 12))
#define I2C_REG_CMD          *((volatile uint32_t *)(I2C_BASE_ADDR + 16))
#define I2C_REG_SR           *((volatile uint32_t *)(I2C_BASE_ADDR + 20))

#define I2C_TEST_START       ((uint32_t)0x80)
#define I2C_TEST_STOP        ((uint32_t)0x40)
#define I2C_TEST_READ        ((uint32_t)0x20)
#define I2C_TEST_WRITE       ((uint32_t)0x10)
#define I2C_TEST_START_READ  ((uint32_t)0xA0)
#define I2C_TEST_START_WRITE ((uint32_t)0x90)
#define I2C_TEST_STOP_READ   ((uint32_t)0x60)
#define I2C_TEST_STOP_WRITE  ((uint32_t)0x50)

#define I2C_STATUS_RXACK     ((uint32_t)0x80) // (1 << 7)
#define I2C_STATUS_BUSY      ((uint32_t)0x40) // (1 << 6)
#define I2C_STATUS_AL        ((uint32_t)0x20) // (1 << 5)
#define I2C_STATUS_TIP       ((uint32_t)0x02) // (1 << 1)
#define I2C_STATUS_IF        ((uint32_t)0x01) // (1 << 0)

#define I2C_DEV_ADDR_16BIT   0
#define I2C_DEV_ADDR_8BIT    1

#define TEST_NUM             20
#define AT24C64_SLV_ADDR     0xA0
#define PCF8563B_SLV_ADDR    0xA2


void i2c_config() {
    I2C_REG_CTRL = (uint32_t)0;
    I2C_REG_PSCR = (uint32_t)99;         // 50MHz / (5 * 100KHz) - 1
    printf("CTRL: %d PSCR: %d\n", I2C_REG_CTRL, I2C_REG_PSCR);
    I2C_REG_CTRL = (uint32_t)0b10000000; // core en
}

uint32_t i2c_get_ack() {
    while ((I2C_REG_SR & I2C_STATUS_TIP) == 0); // need TIP go to 1
    while ((I2C_REG_SR & I2C_STATUS_TIP) != 0); // and then go back to 0
    return !(I2C_REG_SR & I2C_STATUS_RXACK);    // invert since signal is active low
}

uint32_t i2c_busy() {
    return ((I2C_REG_SR & I2C_STATUS_BUSY) == I2C_STATUS_BUSY);
}

void i2c_wr_start(uint32_t slv_addr) {
    I2C_REG_TXR = slv_addr;
    I2C_REG_CMD = I2C_TEST_START_WRITE;
    if (!i2c_get_ack()) putstr("[wr start]no ack recv\n");

}

void i2c_rd_start(uint32_t slv_addr) {
    do {
        I2C_REG_TXR = slv_addr;
        I2C_REG_CMD = I2C_TEST_START_WRITE;
    }while (!i2c_get_ack());
}

void i2c_write(uint8_t val) {
    I2C_REG_TXR = val;
    I2C_REG_CMD = I2C_TEST_WRITE;
    if (!i2c_get_ack()) putstr("[i2c write]no ack recv\n");
}

uint32_t i2c_read(uint32_t cmd) {
    I2C_REG_CMD = cmd;
    if (!i2c_get_ack()) putstr("[i2c read]no ack recv\n");
    return I2C_REG_RXR;
}

void i2c_stop() {
    I2C_REG_CMD = I2C_TEST_STOP;
    while(i2c_busy());
}

void i2c_wr_nbyte(uint8_t slv_addr, uint16_t reg_addr, uint8_t type, uint8_t num, uint8_t *data) {
    i2c_wr_start(slv_addr);
    if(type == I2C_DEV_ADDR_16BIT) {
        i2c_write((uint8_t)((reg_addr >> 8) & 0xFF));
        i2c_write((uint8_t)(reg_addr & 0xFF));
    } else {
        i2c_write((uint8_t)reg_addr);
    }
    for(int i = 0; i < num; ++i) {
        i2c_write(*data);
        ++data;
    }
    i2c_stop();
}

void i2c_rd_nbyte(uint8_t slv_addr, uint16_t reg_addr, uint8_t type, uint8_t num, uint8_t *data) {
    i2c_rd_start(slv_addr);
    if(type == I2C_DEV_ADDR_16BIT) {
        i2c_write((uint8_t)((reg_addr >> 8) & 0xFF));
        i2c_write((uint8_t)(reg_addr & 0xFF));
    } else {
        i2c_write((uint8_t)reg_addr);
    }
    i2c_stop();

    i2c_wr_start(slv_addr + 1);
    for (int i = 0; i < num; ++i) {
        if (i == num - 1) data[i] = i2c_read(I2C_TEST_STOP_READ);
        else data[i] = i2c_read(I2C_TEST_READ);
    }
}

uint8_t PCF8563B_bin2bcd(uint8_t val) {
    uint8_t bcdhigh = 0;
    while (val >= 10) {
        ++bcdhigh;
        val -= 10;
    }
    return ((uint8_t)(bcdhigh << 4) | val);
}

uint8_t PCF8563B_bcd2bin(uint8_t val) {
    uint8_t tmp = 0;
    tmp = ((uint8_t)(val & (uint8_t)0xF0) >> (uint8_t)0x04) * 10;
    return (tmp + (val & (uint8_t)0x0F));
}


int main(){
    putstr("i2c test\n");
    i2c_config();
    // wr AT24C64
    uint8_t ref_data[TEST_NUM], rd_data[TEST_NUM];
    for(int i = 0; i < TEST_NUM; ++i) ref_data[i] = i;

    i2c_wr_nbyte(AT24C64_SLV_ADDR, (uint16_t)0, I2C_DEV_ADDR_16BIT, TEST_NUM, ref_data);
    putstr("AT24C64 wr page done\n");
    i2c_rd_nbyte(AT24C64_SLV_ADDR, (uint16_t)0, I2C_DEV_ADDR_16BIT, TEST_NUM, rd_data);

    for(int i = 0; i < TEST_NUM; ++i) {
        printf("recv: %d expt: %d\n", rd_data[i], i);
        if (rd_data[i] != i) putstr("test fail\n");
    }
    putstr("AT24C64 rd page done\n");

    // read

    putstr("PCF8563B wr done\n");
    putstr("PCF8563B rd done\n");

    putstr("test done\n");
    return 0;
}
