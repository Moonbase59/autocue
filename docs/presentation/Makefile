# autocue presentation makefile

NAME := autocue

all: $(NAME).pdf $(NAME).html

$(NAME).pdf: $(NAME).html
	firefox $(NAME).html
	# open print version, use Ctrl+P and print to PDF
	firefox $(NAME).html?print-pdf

$(NAME).html: $(NAME).md
	pandoc -t revealjs -s $(NAME).md --standalone --slide-level 2 \
	-V slideNumber=true \
	-o $(NAME).html

.PHONY: clean
clean:
	rm $(NAME).pdf $(NAME).html
