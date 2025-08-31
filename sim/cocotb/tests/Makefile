# Makefile

WAVES ?= 0

basic:
	pytest -s tester.py --test=test_basic --waves=$(WAVES)

waveform:
	gtkwave sim_build/tb_sdram_controller.fst waveform.gtkw &

clean:
	rm -r .pytest_cache sim_build

















