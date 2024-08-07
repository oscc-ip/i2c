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

#define TEST_NUM             24
#define AT24C64_SLV_ADDR     0xA0
#define PCF8563B_SLV_ADDR    0xA2

#define PCF8563B_CTL_STATUS1 ((uint8_t)0x00)
#define PCF8563B_CTL_STATUS2 ((uint8_t)0x01)
#define PCF8563B_SECOND_REG  ((uint8_t)0x02)
#define PCF8563B_MINUTE_REG  ((uint8_t)0x03)
#define PCF8563B_HOUR_REG    ((uint8_t)0x04)
#define PCF8563B_DAY_REG     ((uint8_t)0x05)
#define PCF8563B_WEEKDAY_REG ((uint8_t)0x06)
#define PCF8563B_MONTH_REG   ((uint8_t)0x07)
#define PCF8563B_YEAR_REG    ((uint8_t)0x08)

#define SECOND_MINUTE_REG_WIDTH ((uint8_t)0x7F)
#define HOUR_DAY_REG_WIDTH      ((uint8_t)0x3F)
#define WEEKDAY_REG_WIDTH       ((uint8_t)0x07)
#define MONTH_REG_WIDTH         ((uint8_t)0x1F)
#define YEAR_REG_WIDTH          ((uint8_t)0xFF)
#define BCD_Century             ((uint8_t)0x80)

typedef struct {
    struct {
        uint8_t second;
        uint8_t minute;
        uint8_t hour;
    } time;

    struct {
        uint8_t weekday;
        uint8_t day;
        uint8_t month;
        uint8_t year;
    } date;
        
} PCF8563B_info_t;

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
    // do {
    //     I2C_REG_TXR = val;
    //     I2C_REG_CMD = I2C_TEST_WRITE;
    // } while(!i2c_get_ack());
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
    // i2c_wr_start(slv_addr);
    i2c_rd_start(slv_addr);
    if(type == I2C_DEV_ADDR_16BIT) {
        i2c_write((uint8_t)((reg_addr >> 8) & 0xFF));
        i2c_write((uint8_t)(reg_addr & 0xFF));
    } else {
        i2c_write((uint8_t)(reg_addr & 0xFF));
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
        i2c_write((uint8_t)(reg_addr & 0xFF));
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

static uint8_t PCF8563B_bcd2bin(uint8_t val,uint8_t reg_width)
{
    uint8_t res = 0;
    res = (val & (reg_width & 0xF0)) >> 4;
    res = res * 10 + (val & (reg_width & 0x0F));
    return res;
}


void PCF8563B_wr_reg(PCF8563B_info_t *info) {
    uint8_t wr_data[7] = {0};
    *wr_data       = PCF8563B_bin2bcd(info->time.second);
    *(wr_data + 1) = PCF8563B_bin2bcd(info->time.minute);
    *(wr_data + 2) = PCF8563B_bin2bcd(info->time.hour);
    *(wr_data + 3) = PCF8563B_bin2bcd(info->date.day);
    *(wr_data + 4) = PCF8563B_bin2bcd(info->date.weekday);
    *(wr_data + 5) = PCF8563B_bin2bcd(info->date.month);
    *(wr_data + 6) = PCF8563B_bin2bcd(info->date.year);
    i2c_wr_nbyte(PCF8563B_SLV_ADDR, PCF8563B_SECOND_REG, I2C_DEV_ADDR_8BIT, 7, wr_data);
}

PCF8563B_info_t PCF8563B_rd_reg() {
    uint8_t rd_data[7] = {0};
    PCF8563B_info_t info = {0};
    i2c_rd_nbyte(PCF8563B_SLV_ADDR, PCF8563B_SECOND_REG, I2C_DEV_ADDR_8BIT, 7, rd_data);
    info.time.second  = PCF8563B_bcd2bin(rd_data[0], SECOND_MINUTE_REG_WIDTH);
    info.time.minute  = PCF8563B_bcd2bin(rd_data[1], SECOND_MINUTE_REG_WIDTH);
    info.time.hour    = PCF8563B_bcd2bin(rd_data[2], HOUR_DAY_REG_WIDTH);
    info.date.day     = PCF8563B_bcd2bin(rd_data[3], HOUR_DAY_REG_WIDTH);
    info.date.weekday = PCF8563B_bcd2bin(rd_data[4], WEEKDAY_REG_WIDTH);
    info.date.month   = PCF8563B_bcd2bin(rd_data[5], MONTH_REG_WIDTH);
    info.date.year    = PCF8563B_bcd2bin(rd_data[6], YEAR_REG_WIDTH);
    return info;
}

int main(){
    putstr("i2c test\n");
    i2c_config();
    putstr("AT24C64 wr/rd test\n");
    // prepare ref data
    uint8_t ref_data[TEST_NUM], rd_data[TEST_NUM];
    for(int i = 0; i < TEST_NUM; ++i) ref_data[i] = i;
    // write AT24C64
    i2c_wr_nbyte(AT24C64_SLV_ADDR, (uint16_t)0, I2C_DEV_ADDR_16BIT, TEST_NUM, ref_data);
    // read AT24C64
    i2c_rd_nbyte(AT24C64_SLV_ADDR, (uint16_t)0, I2C_DEV_ADDR_16BIT, TEST_NUM, rd_data);
    // check data
    for(int i = 0; i < TEST_NUM; ++i) {
        printf("recv: %d expt: %d\n", rd_data[i], i);
        if (rd_data[i] != i) putstr("test fail\n");
    }
    
    i2c_wr_nbyte(AT24C64_SLV_ADDR, (uint16_t)0, I2C_DEV_ADDR_16BIT, TEST_NUM, ref_data);

    // i2c_wr_nbyte(AT24C64_SLV_ADDR, (uint16_t)36, I2C_DEV_ADDR_16BIT, 10, ref_data);
    // i2c_rd_nbyte(AT24C64_SLV_ADDR, (uint16_t)36, I2C_DEV_ADDR_16BIT, 10, rd_data);
    // for(int i = 0; i < 10; ++i) {
    //     printf("recv: %d expt: %d\n", rd_data[i], i);
    //     if (rd_data[i] != i) putstr("test fail\n");
    // }

    putstr("AT24C64 wr/rd test done\n");
    putstr("PCF8563B test\n");
    PCF8563B_info_t init1_info = {
        .time.second  = 51,
        .time.minute  = 30,
        .time.hour    = 18,
        .date.weekday = 3,
        .date.day     = 7,
        .date.month   = 8,
        .date.year    = 24
    };
    PCF8563B_wr_reg(&init1_info);

    PCF8563B_info_t rd_info = {0};
    for(int i = 0; i < 100; ++i) {
        rd_info = PCF8563B_rd_reg();
        printf("[PCF8563B] %d-%d-%d %d %d:%d:%d\n", rd_info.date.year, rd_info.date.month,
                                                    rd_info.date.day, rd_info.date.weekday,
                                                    rd_info.time.hour, rd_info.time.minute,
                                                    rd_info.time.second);
    }
    putstr("PCF8563B test done\n");

    PCF8563B_info_t init2_info = {
        .time.second  = 23,
        .time.minute  = 22,
        .time.hour    = 12,
        .date.weekday = 1,
        .date.day     = 19,
        .date.month   = 8,
        .date.year    = 24
    };
    PCF8563B_wr_reg(&init2_info);
    for(int i = 0; i < 100; ++i) {
        rd_info = PCF8563B_rd_reg();
        printf("[PCF8563B] %d-%d-%d %d %d:%d:%d\n", rd_info.date.year, rd_info.date.month,
                                                    rd_info.date.day, rd_info.date.weekday,
                                                    rd_info.time.hour, rd_info.time.minute,
                                                    rd_info.time.second);
    }
    putstr("test done\n");
    return 0;
}
