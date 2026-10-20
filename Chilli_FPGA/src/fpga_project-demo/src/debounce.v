`timescale 1ns / 1ps

module debounce #(
    // Số đếm cho 20ms ở tần số 50.1429 MHz (50,142,857 Hz * 0.02s = 1,002,857)
    parameter DELAY_CYCLES = 20'd1_002_857 
)(
    input  wire clk,
    input  wire rst_n,
    input  wire key_in,
    output reg  key_out,      // Trạng thái nút nhấn đã được lọc nhiễu (0 = Pressed)
    output wire key_pulse     // Xung kích hoạt 1 chu kỳ khi phát hiện cạnh xuống
);

    reg [19:0] count;
    reg key_sync_0, key_sync_1;
    reg key_out_reg;

    // 1. Đồng bộ hóa tín hiệu đầu vào (tránh Metastability)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync_0 <= 1'b1; // Trạng thái nhả nút (Pull-up)
            key_sync_1 <= 1'b1;
        end else begin
            key_sync_0 <= key_in;
            key_sync_1 <= key_sync_0;
        end
    end

    // 2. Bộ đếm thời gian lọc dội phím
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 20'd0;
            key_out <= 1'b1;
            key_out_reg <= 1'b1;
        end else begin
            key_out_reg <= key_out; // Lưu trạng thái trước đó để bắt cạnh
            
            // Nếu trạng thái đồng bộ khác với trạng thái ngõ ra hiện tại
            if (key_out != key_sync_1) begin
                // Khi đếm đủ thời gian 20ms (trừ đi 1 do bộ đếm bắt đầu từ 0)
                if (count >= (DELAY_CYCLES - 1)) begin
                    key_out <= key_sync_1; // Cập nhật trạng thái mới
                    count <= 20'd0;
                end else begin
                    count <= count + 1'b1;
                end
            end else begin
                count <= 20'd0; // Reset bộ đếm nếu nhiễu chưa đủ 20ms
            end
        end
    end

    // 3. Phát hiện Falling Edge tạo xung đơn chu kỳ
    // Nút nhấn tích cực mức thấp (1 -> 0)
    assign key_pulse = (key_out_reg == 1'b1 && key_out == 1'b0);

endmodule