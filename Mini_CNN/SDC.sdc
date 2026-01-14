##############################################################
# mini_cnn_pe.sdc
# Timing Constraints File for mini_cnn_pe.v
# Author: Nagaraj
# Description:
#   Defines timing, I/O, and clock constraints for synthesis
##############################################################

# ============================================================
# 1. Define Primary Clock
# ============================================================

# Assuming a 100 MHz clock (10 ns period)
create_clock -name clk -period 10.000 [get_ports clk]

# ============================================================
# 2. Input Delays (relative to clock)
# ============================================================

# Inputs driven by external logic (data, control)
# Assuming input arrives 2 ns after clock edge
set_input_delay 2.0 -clock [get_clocks clk] [get_ports {rst data_in mode start}]

# ============================================================
# 3. Output Delays (relative to clock)
# ============================================================

# Outputs captured by next stage logic
# Assuming output required 2 ns before next clock edge
set_output_delay 2.0 -clock [get_clocks clk] [get_ports {done result}]

# ============================================================
# 4. Clock Uncertainty and Transition
# ============================================================

# Add small clock uncertainty (jitter, skew)
set_clock_uncertainty 0.2 [get_clocks clk]

# Define clock transition times (rise/fall)
set_clock_transition 0.1 [get_clocks clk]

# ============================================================
# 5. Input / Output Drive and Load
# ============================================================

# Define input drive strength (standard cell or FPGA buffer)
set_drive 2 [get_ports {rst data_in mode start}]

# Define output load capacitance (in pF)
set_load 0.5 [get_ports {done result}]

# ============================================================
# 6. False Paths (optional, for non-timed signals)
# ============================================================

# Example: If 'rst' is synchronous, you can exclude async timing paths
set_false_path -from [get_ports rst]

# ============================================================
# 7. Multi-cycle Paths (optional, if needed)
# ============================================================

# Example: If computation takes multiple cycles (FSM path)
# Uncomment and adjust as needed
# set_multicycle_path 2 -from [get_registers acc] -to [get_registers result]

##############################################################
# End of SDC File
##############################################################