library verilog;
use verilog.vl_types.all;
entity pwm_led is
    generic(
        PWM_MAX         : vl_logic_vector(0 to 15) := (Hi1, Hi1, Hi0, Hi0, Hi0, Hi0, Hi1, Hi1, Hi1, Hi1, Hi0, Hi1, Hi1, Hi1, Hi1, Hi1);
        STEP_VAL        : vl_notype
    );
    port(
        clk             : in     vl_logic;
        rst_n           : in     vl_logic;
        mode            : in     vl_logic_vector(1 downto 0);
        led_out         : out    vl_logic
    );
    attribute mti_svvh_generic_type : integer;
    attribute mti_svvh_generic_type of PWM_MAX : constant is 1;
    attribute mti_svvh_generic_type of STEP_VAL : constant is 3;
end pwm_led;
