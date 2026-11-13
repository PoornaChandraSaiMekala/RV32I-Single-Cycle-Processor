
# =====================================================
# RV32I Processor - Basys 3
# Target clock frequency: 100 MHz
# Clock period: 10 ns
# =====================================================
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name sys_clk -period 10.000 [get_ports clk]
