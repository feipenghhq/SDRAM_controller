
YOSYS = yosys
SCRIPT = synth.ys

all: syn sta

syn:
	$(YOSYS) -s $(SCRIPT) 2>&1 | tee syn.log

sta:
	sta sta.tcl 2>&1 | tee sta.log

clean:
	rm -r -f *.v *.log *.history_sta