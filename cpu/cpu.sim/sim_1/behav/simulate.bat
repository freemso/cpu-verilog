@echo off
set xv_path=C:\\Xilinx\\Vivado\\2015.2\\bin
call %xv_path%/xsim test_cpu_behav -key {Behavioral:sim_1:Functional:test_cpu} -tclbatch test_cpu.tcl -view D:/Desktop/cpu/test_cpu_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
