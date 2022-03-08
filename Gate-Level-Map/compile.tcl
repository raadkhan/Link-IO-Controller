include load_etc.tcl

# For timestamps
date

puts "\n\n> Synthesizing . . ."

# Set top level design name variable
set DESIGN io_controller_top

# Set synthesis effort, mapping effort, and working directory
set SYN_EFF medium
set MAP_EFF medium
set SYN_PATH "."

puts "> Setting PDK library . . ."
set PDKDIR /ubc/ece/data/cmc2/kits/ncsu_pdk/FreePDK15/
set_attribute lib_search_path /ubc/ece/data/cmc2/kits/ncsu_pdk/FreePDK15/NanGate_15nm_OCL_v0.1_2014_06_Apache.A/front_end/timing_power_noise/CCS
set_attribute library {NanGate_15nm_OCL_worst_low_conditional_ccs.lib}

puts "> Reading HDL in reverse hierarchical order . . ."
read_hdl -sv ./in/io_controller.sv
read_hdl -sv ./in/io_controller_top.sv

# Elaborate top level design for syntax
elaborate $DESIGN

puts "> Done. Runtime and memory stats:"
timestat Elaboration

puts "\n\n> Checking design for any unresolved problems . . ."
check_design -unresolved

puts "\n\n> Reading timing constraints and clock definitions . . ."
read_sdc ./in/timing.sdc

puts "\n\n> Synthesizing to generic cell . . ."
synthesize -to_generic -eff $SYN_EFF

puts "> Done. Runtime and memory stats:"
timestat GENERIC

puts "\n\n> Synthesizing to gates . . ."
synthesize -to_mapped -eff $MAP_EFF -no_incr

puts "> Done. Runtime and memory stats:"
timestat MAPPED

puts "\n\n> Running incremental synthesis . . ."
synthesize -to_mapped -eff $MAP_EFF -incr

puts "\n\n> Inserting Tie Hi and Tie Low cells . . ."
insert_tiehilo_cells

puts "> Done. Runtime and memory stats:"
timestat INCREMENTAL

puts "\n\n> Generating reports . . ."
report area > ./out/${DESIGN}_area.rpt
report gates > ./out/${DESIGN}_gates.rpt
report timing > ./out/${DESIGN}_timing.rpt
report power > ./out/${DESIGN}_power.rpt

puts "\n\n> Generating mapped Verilog files . . ."
write_hdl -mapped > ./out/${DESIGN}_map.v

puts "\n\n> Generating timing constraints files . . ."
write_sdc > ./out/${DESIGN}_map.sdc
write_sdf > ./out/${DESIGN}_map.sdf

puts "Finished. Final runtime and memory stats:"
timestat FINAL

puts "Exiting . . ."
quit