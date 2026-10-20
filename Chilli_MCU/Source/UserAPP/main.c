#include <SN32F400.h>
#include <SN32F400_Def.h>
#include "..\Driver\GPIO.h"
#include "..\Driver\CT16B0.h"
#include "..\Driver\CT16B1.h"
#include "..\Driver\I2C.h"
#include "..\Driver\WDT.h"
#include "..\Driver\Utility.h"
#include "..\Module\Segment.h"
#include "..\Module\KeyScan.h"
#include "..\Module\EEPROM.h"
#include "..\Module\Buzzer.h"

void PFPA_Init(void);
void NotPinOut_GPIO_init(void);

#ifndef SN32F407
    #error Please install SONiX.SN32F4_DFP
#endif

#define PKG SN32F407

typedef enum {
    MODE_NORMAL = 0,
    MODE_SET_HOUR,
    MODE_SET_MIN,
    MODE_ALARM_HOUR,
    MODE_ALARM_MIN
} ClockMode_t;

#define KEY_SW3    KEY_1
#define KEY_SW6    KEY_4
#define KEY_SW10   KEY_8
#define KEY_SW16   KEY_13

#define EEPROM_SLAVE_ADDR_W  0xA0
#define EEPROM_SLAVE_ADDR_R  0xA1
#define EEPROM_BASE_REG      0x10
#define EEPROM_MAGIC_BYTE    0xAA

#define SEG_BLANK  0x00

#define TIMEOUT_30S_MS      30000UL

#define LED_D6_ON()      (SN_GPIO3->DATA &= ~(1 << 8))
#define LED_D6_OFF()     (SN_GPIO3->DATA |=  (1 << 8))

uint8_t hour = 0;
uint8_t minute = 0;
uint8_t second = 0;

uint8_t alarm_hour = 0;
uint8_t alarm_min = 0;
uint8_t alarm_sec = 0;

uint8_t has_alarm = 0;

uint32_t ms_count = 0;
uint16_t blink_timer = 0;
uint8_t  blink_state = 0;

ClockMode_t current_mode = MODE_NORMAL;

uint32_t timeout_timer = 0;
uint8_t  alarm_triggered = 0;
uint16_t alarm_duration_ms = 0;
uint16_t alarm_toggle_ms = 0;
uint8_t  buzzer_state = 0;

uint16_t buzzer_pip_timer = 0;

void Save_Alarm_To_EEPROM(void)
{
    // [Nhiem vu 8] EEPROM: Luu gio hen va phut hen, giay hen mac dinh = 0.
    uint8_t val;
    
    val = EEPROM_MAGIC_BYTE;
    eeprom_write(EEPROM_SLAVE_ADDR_W, EEPROM_BASE_REG + 0, &val, 1);
    UT_DelayNms(20);

    val = alarm_hour;
    eeprom_write(EEPROM_SLAVE_ADDR_W, EEPROM_BASE_REG + 1, &val, 1);
    UT_DelayNms(20);

    val = alarm_min;
    eeprom_write(EEPROM_SLAVE_ADDR_W, EEPROM_BASE_REG + 2, &val, 1);
    UT_DelayNms(20);

    val = 0;
    eeprom_write(EEPROM_SLAVE_ADDR_W, EEPROM_BASE_REG + 3, &val, 1);
    UT_DelayNms(20);
}

void Load_Alarm_From_EEPROM(void)
{
    // [Nhiem vu 8] Doc lai gio/phut hen tu EEPROM khi he thong khoi dong.
    uint8_t magic = 0;
    uint8_t h = 0, m = 0, s = 0;
    
    eeprom_read(EEPROM_SLAVE_ADDR_R, EEPROM_BASE_REG + 0, &magic, 1);
    eeprom_read(EEPROM_SLAVE_ADDR_R, EEPROM_BASE_REG + 1, &h, 1);
    eeprom_read(EEPROM_SLAVE_ADDR_R, EEPROM_BASE_REG + 2, &m, 1);
    eeprom_read(EEPROM_SLAVE_ADDR_R, EEPROM_BASE_REG + 3, &s, 1);
    
    if (magic == EEPROM_MAGIC_BYTE && h < 24 && m < 60) {
        alarm_hour = h;
        alarm_min  = m;
        alarm_sec  = 0;
        has_alarm  = 1;
    } else {
        alarm_hour = 0;
        alarm_min  = 0;
        alarm_sec  = 0;
        has_alarm  = 0;
    }
}

void Display_Render(void)
{
    // [Nhiem vu 1] 4 LED 7SEG se the hien gio va phut o che do thuong theo dinh dang: HH.MM.
    uint8_t h = hour;
    uint8_t m = minute;
if (current_mode == MODE_ALARM_HOUR || current_mode == MODE_ALARM_MIN) {
        h = alarm_hour;
        m = alarm_min;
    }

    uint8_t d0 = h / 10;
    uint8_t d1 = h % 10;
    uint8_t d2 = m / 10;
    uint8_t d3 = m % 10;

    // [Nhiem vu 2 & 3] Quan ly hieu ung nhap nhay cho LED HH voi chu ky 1s (0.5s ON - 0.5s OFF).
    if ((current_mode == MODE_SET_HOUR || current_mode == MODE_ALARM_HOUR) && (blink_state == 1)) {
        segment_buff[0] = SEG_BLANK;
        segment_buff[1] = SEG_BLANK;
    } else {
        segment_buff[0] = SEGMENT_TABLE[d0];
        segment_buff[1] = SEGMENT_TABLE[d1];
    }

    // [Nhiem vu 2 & 3] Quan ly hieu ung nhap nhay cho LED MM voi chu ky 1s (0.5s ON - 0.5s OFF).
    if ((current_mode == MODE_SET_MIN || current_mode == MODE_ALARM_MIN) && (blink_state == 1)) {
        segment_buff[2] = SEG_BLANK;
        segment_buff[3] = SEG_BLANK;
    } else {
        segment_buff[2] = SEGMENT_TABLE[d2];
        segment_buff[3] = SEGMENT_TABLE[d3];
    }
}

int main(void)
{
    uint16_t key_code = 0;

    SystemInit();
    SystemCoreClockUpdate();

    PFPA_Init();
    NotPinOut_GPIO_init();

    SN_SYS0->EXRSTCTRL_b.RESETDIS = 0;

    GPIO_Init();
    WDT_Init();

    I2C0_Init();

    CT16B0_Init();
    SN_PFPA->CT16B0_b.PWM0 = 1;
    CT16B1_Init();

    SN_GPIO3->MODE |= (1 << 8);
    LED_D6_OFF();

    UT_DelayNms(100);

    Load_Alarm_From_EEPROM();

    // [Nhiem vu 1] Ngay sau khi cap nguon, mach hoat dong o che do thuong, gio va phut duoc reset ve gia tri 0.
    hour = 0;
    minute = 0;
    second = 0;

    while (1)
    {
        __WDT_FEED_VALUE;

        Digital_Scan();

        UT_DelayNx10us(100);

        ms_count++;
        blink_timer++;

        if (blink_timer >= 500) {
            blink_timer = 0;
            blink_state = !blink_state; 
        }

        if (ms_count >= 1000)
        {
            // [Nhiem vu 1] Bo dem se dem, sau moi phut se hien thi phut +1, den phut thu 60 se reset phut ve 0 va tang gio len 1.
            ms_count = 0;
            second++;
            if (second >= 60) {
                second = 0;
                minute++;
                if (minute >= 60) {
                    minute = 0;
                    hour++;
                    // [Nhiem vu 1] Gio se duoc hien thi tu 00 den 23.
                    if (hour >= 24) {
                        hour = 0;
                    }
                }
            }

            // [Nhiem vu 6] Kich hoat coi khi dong ho chay den gio hen.
            if (has_alarm == 1 && hour == alarm_hour && minute == alarm_min && second == alarm_sec) {
                alarm_triggered = 1;
                alarm_duration_ms = 0;
                alarm_toggle_ms = 0;
                buzzer_state = 1;
                set_buzzer_pitch(0);
            }
        }

        // [Nhiem vu 7] O che do thay doi gio hen hoac phut hen thi LED se nhap nhay voi chu ky 1s (0.5s ON, 0.5s OFF). 
        // Ngoai ra LED se o trang thai OFF.
if (current_mode != MODE_NORMAL) 
        {
            if (blink_state == 0) {
                LED_D6_ON();
            } else {
                LED_D6_OFF();
            }
        } 
        else 
        {
            LED_D6_OFF();
        }

        if (buzzer_pip_timer > 0)
        {
            buzzer_pip_timer--;
            if (buzzer_pip_timer == 0 && alarm_triggered == 0) {
                set_buzzer_pitch(0xFF);
            }
        }

        // [Nhiem vu 9] O che do cai dat, trong vong 30s khong co su kien an nut thi se thoat ra che do thuong.
        if (current_mode != MODE_NORMAL)
        {
            timeout_timer++;
            if (timeout_timer >= TIMEOUT_30S_MS)
            {
                current_mode = MODE_NORMAL;
                timeout_timer = 0;
                
                // [Nhiem vu 6] Khi het thoi gian timeout thoat khoi che do thay doi... thi coi se keu pip trong 0.3s
                set_buzzer_pitch(0);
                buzzer_pip_timer = 300;
            }
        }
        else {
            timeout_timer = 0;
        }

        // [Nhiem vu 6] Khi dong ho chay den gio hen, coi se keu pip-pip lien tuc trong 5s voi chu ky (0.5s ON - 0.5s OFF).
        if (alarm_triggered)
        {
            alarm_duration_ms++;
            alarm_toggle_ms++;

            if (alarm_toggle_ms >= 500) {
                alarm_toggle_ms = 0;
                buzzer_state = !buzzer_state;
                if (buzzer_state) {
                    set_buzzer_pitch(0);
                } else {
                    set_buzzer_pitch(0xFF);
                }
            }

            if (alarm_duration_ms >= 5000) {
                alarm_triggered = 0;
                alarm_duration_ms = 0;
                set_buzzer_pitch(0xFF);
            }
        }

        key_code = KeyScan();
        if (key_code)
        {
            uint8_t pressed_key = key_code & 0xFF;
            if (pressed_key == KEY_SW3 || pressed_key == KEY_SW6 || 
                pressed_key == KEY_SW10 || pressed_key == KEY_SW16)
            {
                // [Nhiem vu 6] Moi khi an cac nut SW3, SW6, SW10, SW16 thi coi se keu pip trong 0.3s.
                set_buzzer_pitch(0);
                buzzer_pip_timer = 300;
                timeout_timer = 0; // Dat lai bo dem timeout khi co nut duoc nhan.
            }

            switch (pressed_key)
            {
                case KEY_SW3:
                    // [Nhiem vu 2] NUT SETUP (SW3).
                    if (current_mode == MODE_ALARM_HOUR || current_mode == MODE_ALARM_MIN) {
                        break;
                    }

                    if (current_mode == MODE_SET_HOUR) {
                        // [Nhiem vu 2] Dang o thay doi gio -> an SW3 de vao che do thay doi phut.
                        current_mode = MODE_SET_MIN;
                    } 
                    else if (current_mode == MODE_SET_MIN) {
// [Nhiem vu 2] Dang o thay doi phut -> an SW3 de vao che do thuong.
                        current_mode = MODE_NORMAL;
                    } 
                    else {
                        // [Nhiem vu 2] Che do thuong -> an SW3 de vao che do thay doi gio.
                        current_mode = MODE_SET_HOUR;
                    }
                    
                    blink_timer = 0;
                    blink_state = 1; 
                    break;

                case KEY_SW16:
                    // [Nhiem vu 3] NUT HEN GIO (SW16).
                    if (current_mode == MODE_SET_HOUR || current_mode == MODE_SET_MIN) {
                        break;
                    }

                    if (current_mode == MODE_ALARM_HOUR) {
                        // [Nhiem vu 3] Dang o thay doi gio hen -> an SW16 de vao thay doi phut hen.
                        current_mode = MODE_ALARM_MIN;
                    } 
                    else if (current_mode == MODE_ALARM_MIN) {
                        // [Nhiem vu 3] Dang o thay doi phut hen -> ghi gio phut hen vao EEPROM va thoat ra che do thuong.
                        Save_Alarm_To_EEPROM();
                        has_alarm = 1;
                        current_mode = MODE_NORMAL;
                    } 
                    else {
                        // [Nhiem vu 3] Dang o che do thuong -> an SW16 de vao thay doi gio hen.
                        if (has_alarm == 0) {
                            alarm_hour = hour;
                            alarm_min  = minute;
                        }
                        
                        current_mode = MODE_ALARM_HOUR;
                    }
                    
                    blink_timer = 0;
                    blink_state = 1;
                    break;

                case KEY_SW6:
                    // [Nhiem vu 4] NUT + (SW6).
                    if (current_mode == MODE_SET_HOUR) {
                        // [Nhiem vu 4] An SW6 de tang gio len 1 don vi, khi gio tang den 24 se reset gio ve 0.
                        hour++;
                        if (hour >= 24) hour = 0;
                    } 
                    else if (current_mode == MODE_SET_MIN) {
                        // [Nhiem vu 4] An SW6 de tang phut len 1 don vi, khi phut tang den 60 se reset phut ve 0.
                        minute++;
                        if (minute >= 60) minute = 0;
                    } 
                    else if (current_mode == MODE_ALARM_HOUR) {
                        // [Nhiem vu 4] Tang gio hen.
                        alarm_hour++;
                        if (alarm_hour >= 24) alarm_hour = 0;
                    } 
                    else if (current_mode == MODE_ALARM_MIN) {
                        // [Nhiem vu 4] Tang phut hen.
                        alarm_min++;
                        if (alarm_min >= 60) alarm_min = 0;
                    }
                    
                    blink_timer = 0;
										blink_state = 0;
                    break;

                case KEY_SW10:
                    // [Nhiem vu 5] NUT - (SW10).
                    if (current_mode == MODE_SET_HOUR) {
                        // [Nhiem vu 5] An SW10 giam gio xuong 1 don vi, khi gio = 0 giam 1 se dat gio = 23.
                        if (hour == 0) hour = 23;
                        else hour--;
                    } 
                    else if (current_mode == MODE_SET_MIN) {
                        // [Nhiem vu 5] An SW10 giam phut xuong 1 don vi, khi phut = 0 giam 1 se dat phut = 59.
                        if (minute == 0) minute = 59;
                        else minute--;
                    } 
                    else if (current_mode == MODE_ALARM_HOUR) {
                        // [Nhiem vu 5] Giam gio hen.
                        if (alarm_hour == 0) alarm_hour = 23;
                        else alarm_hour--;
                    } 
                    else if (current_mode == MODE_ALARM_MIN) {
                        // [Nhiem vu 5] Giam phut hen.
                        if (alarm_min == 0) alarm_min = 59;
                        else alarm_min--;
                    }

                    blink_timer = 0;
                    blink_state = 0;
                    break;

                default:
                    break;
            }
        }

        Display_Render();
    }
}

void NotPinOut_GPIO_init(void)
{
#if (PKG == SN32F405)
    SN_GPIO3->CFG = 0x0002AAAA;
#elif (PKG == SN32F403)
    SN_GPIO3->CFG = 0x0000AAA8;
#endif
}

void HardFault_Handler(void)
{
    NVIC_SystemReset();
}