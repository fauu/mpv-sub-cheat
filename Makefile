SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables

-include ./Makefile.env

NAME = sub-cheat
SOURCE = $(NAME).fnl
OUTDIR = out
OUTPUT = $(OUTDIR)/$(NAME).lua

install: compile
	@if [ -z "$(INSTALL)" ]; then
		echo "INSTALL is not set. Put INSTALL=/path/to/mpv/scripts/ in Makefile.env file"
		exit
	fi
	if cp $(OUTPUT) $(INSTALL); then
		echo "Copied $(OUTPUT) to $(INSTALL)"
	fi

compile: $(SOURCE)
	@if [ -z "$(FENNEL)" ]; then
		echo "FENNEL is not set. Put FENNEL=/path/to/fennel in Makefile.env file"
		exit
	fi
	mkdir -p $(OUTDIR)
	if $(FENNEL) --compile $< > $(OUTPUT); then
		echo "Compiled $< to $(OUTPUT)"
	else
		exit
	fi
.PHONY: compile

clean:
	@if [ -d "$(OUTDIR)" ]; then
		rm -rf "$(OUTDIR)"
	fi
.PHONY: clean
