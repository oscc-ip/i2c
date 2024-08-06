#include <am.h>
#include <klib.h>
#include <klib-macros.h>

#define I2C_BASE_ADDR 0x10004000
#define I2C_REG_CTRL *((volatile uint32_t *)(I2C_BASE_ADDR))
#define I2C_REG_PSCR *((volatile uint32_t *)(I2C_BASE_ADDR + 4))
#define I2C_REG_TXR  *((volatile uint32_t *)(I2C_BASE_ADDR + 8))
#define I2C_REG_RXR  *((volatile uint32_t *)(I2C_BASE_ADDR + 12))
#define I2C_REG_CMD  *((volatile uint32_t *)(I2C_BASE_ADDR + 16))
#define I2C_REG_SR   *((volatile uint32_t *)(I2C_BASE_ADDR + 20))

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

#define TEST_NUM 16
#define AT24C64_SLV_ADDR 0xA0
#define AT24C64_SLV_ADDR 0xA0

// uint32_t slv_addr;

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

void i2c_write(uint32_t val) {
    I2C_REG_TXR = val;
    I2C_REG_CMD = I2C_TEST_WRITE;
    if (!i2c_get_ack()) putstr("[i2c write]no ack recv\n");
}

uint32_t i2c_read(uint32_t cmd) {
    I2C_REG_CMD = cmd;
    if (!i2c_get_ack()) putstr("[i2c read]no ack recv from slv 6\n");
    return I2C_REG_RXR;
}

void i2c_stop() {
    I2C_REG_CMD = I2C_TEST_STOP;
    while(i2c_busy());
}

void AT24C64_wr_setup() {
    i2c_wr_start(AT24C64_SLV_ADDR);
    i2c_write((uint32_t)0); // send the high data word addr
    i2c_write((uint32_t)0); // send the low data word addr
}

void AT24C64_rd_setup() {
    i2c_rd_start(AT24C64_SLV_ADDR);
    i2c_write((uint32_t)0); // send the high data word addr
    i2c_write((uint32_t)0); // send the low data word addr
    i2c_stop();
}

int main(){
    putstr("i2c test\n");
    i2c_config();
    // write
    AT24C64_wr_setup();
    for(int i = 0; i < TEST_NUM; ++i) {
        i2c_write((uint32_t)i);
    }
    i2c_stop();
    putstr("AT24C64 tx done\n");

    // read
    AT24C64_rd_setup();
    i2c_wr_start(AT24C64_SLV_ADDR + 1);
    uint32_t recv_val;
    for (int i = 0; i < TEST_NUM; ++i) {
        if (i == TEST_NUM - 1) recv_val = i2c_read(I2C_TEST_STOP_READ);
        else recv_val = i2c_read(I2C_TEST_READ);

        printf("recv: %d expt: %d\n", recv_val, i);
        if (recv_val != i) putstr("test fail\n");
    }
    putstr("AT24C64 rx done\n");

    putstr("pcf8563 wr done\n");
    putstr("pcf8563 rd done\n");

    putstr("test done\n");
    return 0;
}
