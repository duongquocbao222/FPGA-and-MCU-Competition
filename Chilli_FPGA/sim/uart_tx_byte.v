module uart_tx_byte #(
    parameter BAUD_DIV = 16'd435 // Phân tần cho 115200 bps từ xung 50.1429 MHz
)(
    input  wire clk,         // Xung nhịp 50.1429 MHz
    input  wire rst_n,       // Reset tích cực mức thấp
    input  wire send_en,     // Xung kích hoạt bắt đầu truyền 1 byte
    input  wire [7:0] data_in, // Dữ liệu 8-bit cần truyền
    output reg  tx,          // Chân tín hiệu UART TX
    output reg  tx_busy      // Cờ báo hiệu đang truyền dữ liệu (1 = Bận)
);

    reg [15:0] baud_cnt;     // Bộ đếm Baudrate
    reg [3:0]  bit_cnt;      // Bộ đếm bit dữ liệu (0 đến 7)
    reg [7:0]  data_reg;     // Thanh ghi lưu tạm dữ liệu
    
    reg [1:0] current_state, next_state;

    // Định nghĩa các trạng thái
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    //KHỐI 1: Cập nhật trạng thái
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    //KHỐI 2: Logic chuyển trạng thái tiếp theo
    always @(*) begin
        next_state = current_state; 
        
        case (current_state)
            IDLE: begin
                if (send_en) 
                    next_state = START;
            end
            
            START: begin
                if (baud_cnt >= BAUD_DIV - 1) 
                    next_state = DATA;
            end
            
            DATA: begin
                if (baud_cnt >= BAUD_DIV - 1 && bit_cnt == 4'd7) 
                    next_state = STOP;
            end
            
            STOP: begin
                if (baud_cnt >= BAUD_DIV - 1) 
                    next_state = IDLE;
            end
        endcase
    end

    //KHỐI 3: Logic Ngõ ra và Bộ đếm Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx       <= 1'b1;
            tx_busy  <= 1'b0;
            baud_cnt <= 16'd0;
            bit_cnt  <= 4'd0;
            data_reg <= 8'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    tx       <= 1'b1;
                    baud_cnt <= 16'd0;
                    bit_cnt  <= 4'd0;
                    if (send_en) begin
                        data_reg <= data_in; // Chốt dữ liệu
                        tx_busy  <= 1'b1;
                    end else begin
                        tx_busy  <= 1'b0;
                    end
                end
                
                START: begin
                    tx      <= 1'b0; // Bit Start luôn là mức LOW
                    tx_busy <= 1'b1;
                    
                    if (baud_cnt >= BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                
                DATA: begin
                    tx      <= data_reg[bit_cnt[2:0]]; // Truyền từ LSB đến MSB
                    tx_busy <= 1'b1;
                    
                    if (baud_cnt >= BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;
                        if (bit_cnt < 4'd7) begin 
                            bit_cnt <= bit_cnt + 1'b1; // Chuyển sang bit tiếp theo
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
                
                STOP: begin
                    tx      <= 1'b1; // Bit Stop luôn là mức HIGH
                    tx_busy <= 1'b1;
                    
                    if (baud_cnt >= BAUD_DIV - 1) begin
                        baud_cnt <= 16'd0;
                    end else begin
                        baud_cnt <= baud_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule