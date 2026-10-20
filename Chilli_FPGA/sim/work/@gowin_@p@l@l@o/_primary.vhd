library verilog;
use verilog.vl_types.all;
entity Gowin_PLLO is
    port(
        clkouta         : out    vl_logic;
        clkin           : in     vl_logic;
        dta             : in     vl_logic_vector(3 downto 0)
    );
end Gowin_PLLO;
