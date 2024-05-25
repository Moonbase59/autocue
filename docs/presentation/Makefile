# autocue presentation makefile

NAME := autocue

$(NAME).pdf: $(NAME).html
	firefox $(NAME).html
	# open print version, use Ctrl+P and print to PDF
	firefox $(NAME).html?print-pdf

$(NAME).html: $(NAME).md
	pandoc -t revealjs -s $(NAME).md --standalone --slide-level 2 -o $(NAME).html

clean:
	rm $(NAME).pdf $(NAME).html
