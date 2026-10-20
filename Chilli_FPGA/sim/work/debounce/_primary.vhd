library verilog;
use verilog.vl_types.all;
entity debounce is
    generic(
        DELAY_CYCLES    : vl_logic_vector(0 to 19) := (Hi1, Hi1, Hi1, Hi1, Hi0, Hi1, Hi0, Hi0, Hi1, Hi1, Hi0, Hi1, Hi0, Hi1, Hi1, Hi0, Hi1, Hi0, Hi0, Hi1)
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        key_in          : in     vl_logic;
        key_out         : out    vl_logic;
        key_pulse       : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of DELAY_CYCLES : constant is 1;
end debounce;
