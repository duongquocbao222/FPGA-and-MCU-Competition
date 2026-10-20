library verilog;
use verilog.vl_types.all;
entity top_system is
    port(
        clk_27m         : in     vl_logic;
        btn1            : in     vl_logic;
        btn2            : in     vl_logic;
        led             : out    vl_logic;
        uart_tx         : out    vl_logic
    );
end top_system;
