PYTHON=python3
SCRIPTS=scripts
SRC=src
OUT=src/tt_um_a1k0n_nyancat.v.new

all: run_pipeline run_o copy 

run_pipeline:
	cd $(SCRIPTS) && $(PYTHON) extractcat.py
	cd $(SCRIPTS) && $(PYTHON) gamma.py
	cd $(SCRIPTS) && $(PYTHON) ripmusic.py

run_o:
	./o

copy:
	cat $(OUT) | xclip -selection clipboard

clean:
	rm -f $(OUT)
