library verilog;
use verilog.vl_types.all;
entity uart_tx_byte is
    generic(
        BAUD_DIV        : vl_logic_vector(0 to 15) := (Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi0, Hi1, Hi1, Hi0, Hi1, Hi1, Hi0, Hi0, Hi1, Hi1)
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        send_en         : in     vl_logic;
        data_in         : in     vl_logic_vector(7 downto 0);
        tx              : out    vl_logic;
        tx_busy         : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of BAUD_DIV : constant is 1;
end uart_tx_byte;
