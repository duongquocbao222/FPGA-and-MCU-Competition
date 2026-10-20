module pwm_led (
    input  wire clk,        // Xung nhịp 50.1429 MHz
    input  wire rst_n,      // Reset tích cực mức thấp
    input  wire [1:0] mode, // 00: LOW, 01: HIGH, 10: AUTO
    output wire led_out     // Tín hiệu điều khiển LED (Tích cực mức HIGH)
);

    // Các hằng số tính toán dựa trên xung 50.1429 MHz
    parameter PWM_MAX = 16'd50_143; // Chu kỳ PWM 1ms (1kHz)
    parameter STEP_VAL = PWM_MAX / 1000; // Tăng/giảm mỗi 1ms để hoàn thành 1s
    
    reg [15:0] pwm_cnt;      // Đếm chu kỳ PWM
    reg [15:0] duty_cycle;   // Ngưỡng so sánh độ sáng
    reg [15:0] breath_cnt;   // Bộ đếm cho hiệu ứng thở
    reg breath_dir;          // Hướng thở: 0 = Tăng sáng, 1 = Giảm sáng

    // 1. Bộ đếm PWM cơ bản (Tạo chu kỳ 1ms)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_cnt <= 16'd0;
        end else begin
            if (pwm_cnt >= PWM_MAX - 1)
                pwm_cnt <= 16'd0;
            else
                pwm_cnt <= pwm_cnt + 1'b1;
        end
    end

    // 2. Logic xử lý hiệu ứng thở (Cập nhật duty_cycle mỗi 1ms)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            breath_cnt <= 16'd0;
            breath_dir <= 1'b0;
        end else if (mode == 2'b10) begin // Chỉ chạy khi ở chế độ AUTO
            if (pwm_cnt == 16'd0) begin
                if (breath_dir == 1'b0) begin // Tăng sáng
                    if (breath_cnt >= PWM_MAX - STEP_VAL)
                        breath_dir <= 1'b1;
                    else
                        breath_cnt <= breath_cnt + STEP_VAL;
                end else begin // Giảm sáng
                    if (breath_cnt <= STEP_VAL)
                        breath_dir <= 1'b0;
                    else
                        breath_cnt <= breath_cnt - STEP_VAL;
                end
            end
        end else begin
            breath_cnt <= 16'd0;
            breath_dir <= 1'b0;
        end
    end

    // 3. Lựa chọn Duty Cycle dựa trên Mode
    always @(*) begin
        case (mode)
            2'b00: duty_cycle = PWM_MAX / 4;  // LOW: 25%
            2'b01: duty_cycle = PWM_MAX;      // HIGH: 100%
            2'b10: duty_cycle = breath_cnt;   // AUTO: Breathing LED
            default: duty_cycle = PWM_MAX / 4;
        endcase
    end

    // 4. So sánh xuất tín hiệu ra LED (LED tích cực mức HIGH)
    assign led_out = (pwm_cnt < duty_cycle) ? 1'b1 : 1'b0;

endmodule