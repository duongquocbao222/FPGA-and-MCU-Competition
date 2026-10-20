`timescale 1ns / 1ps

module top_system (
    input  wire clk_27m, // Xung thạch anh 27MHz trên board
    input  wire btn1,    // Nút nhấn 1 (Chuyển LOW <-> HIGH hoặc về LOW)
    input  wire btn2,    // Nút nhấn 2 (Chuyển sang AUTO)
    output wire led,     // Tín hiệu điều khiển LED
    output wire uart_tx  // Tín hiệu truyền UART lên máy tính
);

    // 1. Sinh xung hệ thống (PLL) & Power-On-Reset (POR)
    wire sys_clk; // Xung 50.1429 MHz từ PLL
    
    // Gọi IP Core PLL 
    Gowin_PLLO sys_pll_inst (
        .clkin(clk_27m),
        .dta(4'b0000),
        .clkouta(sys_clk)
    );

    // Mạch Power-On-Reset (Tạo tín hiệu rst_n = 0 trong khoảng 1.3ms đầu lúc mới cấp nguồn)
    reg [15:0] por_cnt = 16'd0;
    reg rst_n = 1'b0;
    
    always @(posedge sys_clk) begin
        if (por_cnt < 16'hFFFF)
            por_cnt <= por_cnt + 1'b1;
        else
            rst_n <= 1'b1; // Nhả reset sau khi hệ thống ổn định
    end

    // 2. Gọi các khối Debounce (Chống dội phím)
    wire btn1_pulse;
    wire btn2_pulse;

    debounce btn1_inst (
        .clk(sys_clk), .rst_n(rst_n), .key_in(btn1), 
        .key_out(), .key_pulse(btn1_pulse)
    );

    debounce btn2_inst (
        .clk(sys_clk), .rst_n(rst_n), .key_in(btn2), 
        .key_out(), .key_pulse(btn2_pulse)
    );

    // 3. FSM Điều khiển Chế độ Hệ thống
    localparam LOW  = 2'b00;
    localparam HIGH = 2'b01;
    localparam AUTO = 2'b10;

    reg [1:0] sys_mode; // 00: LOW, 01: HIGH, 10: AUTO
    reg start_tx_str;   // Cờ kích hoạt gửi chuỗi qua UART

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            sys_mode     <= LOW;  // Thiết lập về Chế độ 1 (LOW) khi cấp nguồn/reset
            start_tx_str <= 1'b1; // Kích hoạt gửi "MODE: LOW\r\n" lần đầu
        end else begin
            start_tx_str <= 1'b0; // Mặc định hạ cờ để tránh phát liên tục
            
            case (sys_mode)
                LOW: begin
                    if (btn2_pulse) begin
                        sys_mode     <= AUTO; // Lập tức sang AUTO
                        start_tx_str <= 1'b1;
                    end else if (btn1_pulse) begin
                        sys_mode     <= HIGH; // Chuyển từ LOW -> HIGH
                        start_tx_str <= 1'b1;
                    end
                end
                
                HIGH: begin
                    if (btn2_pulse) begin
                        sys_mode     <= AUTO; // Lập tức sang AUTO
                        start_tx_str <= 1'b1;
                    end else if (btn1_pulse) begin
                        sys_mode     <= LOW;  // Quay lại từ HIGH -> LOW
                        start_tx_str <= 1'b1;
                    end
                end
                
                AUTO: begin
                    if (btn1_pulse) begin
                        sys_mode     <= LOW;  // Đang AUTO nhấn Button 1 -> Về LOW
                        start_tx_str <= 1'b1;
                    end
                    //bỏ qua btn2_pulse ở đây để tránh spam UART khi đang ở AUTO
                end
                
                default: begin
                    sys_mode     <= LOW;
                    start_tx_str <= 1'b1;
                end
            endcase
        end
    end

    // 4. Gọi khối PWM điều khiển LED
    pwm_led pwm_inst (
        .clk(sys_clk),
        .rst_n(rst_n),
        .mode(sys_mode),
        .led_out(led)
    );

    // 5. FSM Truyền chuỗi UART 
    wire uart_tx_busy;
    reg  uart_send_en;
    reg  [7:0] uart_tx_data;
    
    uart_tx_byte uart_tx_inst (
        .clk(sys_clk),          
        .rst_n(rst_n),
        .send_en(uart_send_en), 
        .data_in(uart_tx_data), 
        .tx(uart_tx),           
        .tx_busy(uart_tx_busy)  
    );

    reg [3:0] str_idx;
    reg [1:0] current_state, next_state; 

    localparam IDLE      = 2'd0;
    localparam SEND      = 2'd1;
    localparam WAIT_BUSY = 2'd2;
    localparam WAIT_DONE = 2'd3;

    // Giới hạn độ dài chuỗi tùy theo Mode
    wire [3:0] max_idx = (sys_mode == LOW) ? 4'd10 : 4'd11;

    // KHỐI 1: Cập nhật trạng thái 
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) 
            current_state <= IDLE;
        else 
            current_state <= next_state;
    end

    // KHỐI 2: Logic trạng thái tiếp theo
    always @(*) begin
        next_state = current_state; // Mặc định giữ nguyên trạng thái
        
        case (current_state)
            IDLE: begin
                if (start_tx_str) 
                    next_state = SEND;
            end
            
            SEND: begin
                next_state = WAIT_BUSY;
            end
            
            WAIT_BUSY: begin
                if (uart_tx_busy) 
                    next_state = WAIT_DONE;
            end
            
            WAIT_DONE: begin
                if (!uart_tx_busy) begin
                    if (str_idx < max_idx) 
                        next_state = SEND; // Còn ký tự -> quay lại SEND
                    else 
                        next_state = IDLE; // Hết chuỗi -> về IDLE
                end
            end
        endcase
    end

    // KHỐI 3: Logic Ngõ ra và Datapath (Sequential)
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            str_idx      <= 4'd0;
            uart_send_en <= 1'b0;
            uart_tx_data <= 8'd0;
        end else begin
            uart_send_en <= 1'b0; // Default clear cờ gửi để tạo xung đơn

            case (current_state)
                IDLE: begin
                    if (start_tx_str) 
                        str_idx <= 4'd0; // Reset index khi có lệnh bắt đầu
                end
                
                SEND: begin
                    uart_send_en <= 1'b1; // Phát xung enable
                    
                    // Nạp data dựa theo sys_mode
                    case (str_idx)
                        4'd0:  uart_tx_data <= 8'h4D; // 'M'
                        4'd1:  uart_tx_data <= 8'h4F; // 'O'
                        4'd2:  uart_tx_data <= 8'h44; // 'D'
                        4'd3:  uart_tx_data <= 8'h45; // 'E'
                        4'd4:  uart_tx_data <= 8'h3A; // ':'
                        4'd5:  uart_tx_data <= 8'h20; // ' '
                        4'd6:  uart_tx_data <= (sys_mode == LOW) ? 8'h4C : ((sys_mode == HIGH) ? 8'h48 : 8'h41); // 'L', 'H', 'A'
                        4'd7:  uart_tx_data <= (sys_mode == LOW) ? 8'h4F : ((sys_mode == HIGH) ? 8'h49 : 8'h55); // 'O', 'I', 'U'
                        4'd8:  uart_tx_data <= (sys_mode == LOW) ? 8'h57 : ((sys_mode == HIGH) ? 8'h47 : 8'h54); // 'W', 'G', 'T'
                        4'd9:  uart_tx_data <= (sys_mode == LOW) ? 8'h0D : ((sys_mode == HIGH) ? 8'h48 : 8'h4F); // '\r', 'H', 'O'
                        4'd10: uart_tx_data <= (sys_mode == LOW) ? 8'h0A : 8'h0D; // '\n', '\r'
                        4'd11: uart_tx_data <= (sys_mode == LOW) ? 8'h00 : 8'h0A; // '\n' (Cho HIGH và AUTO)
                        default: uart_tx_data <= 8'h00; 
                    endcase
                end
                
                WAIT_BUSY: begin
                    // Đợi UART TX báo bận
                end
                
                WAIT_DONE: begin
                    // Tăng index khi UART báo rảnh để chuẩn bị cho chu kỳ SEND tiếp theo
                    if (!uart_tx_busy && str_idx < max_idx) begin
                        str_idx <= str_idx + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule