PYTHON=python3
SCRIPTS=scripts
SRC=src
OUT=src/tt_um_a1k0n_nyancat.v.new

# Danh sách nhân vật
NAMES = mander melon zizard fire

all: run_pipeline run_o copy 

run_pipeline:
	# 1. Chạy extract cho từng con bằng vòng lặp shell
	@for name in $(NAMES); do \
		echo "Processing $$name..."; \
		export NYAN_NAME=$$name; \
		cd $(SCRIPTS) && $(PYTHON) extractcat.py; \
		cd ..; \
	done
	# 2. Sau khi có đủ dữ liệu, chạy script gen palette chung
	cd $(SCRIPTS) && $(PYTHON) gen_pallet.py
	# 3. Chạy các script còn lại
	cd $(SCRIPTS) && $(PYTHON) ripmusic.py

run_o:
	./o

copy:
	cat $(OUT) | xclip -selection clipboard

clean:
	rm -f $(OUT)
	rm -f data/*.hex
