quit	-sim

.main	clear

vsim -novopt -assertdebug -classdebug -coverage -coverstore A:\MyProjects\IC_labs\data_transform\coverage -sv_seed random +UVM_TESTNAME=basic_data_transform_test work.tb

add wave tb/dt_if/*

run -all