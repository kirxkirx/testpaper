#
# ---=== Ultimate LaTeX astronomy paper/proposal makefile ===---
#
# Run 'make' to compile a LaTeX source and display the reulting PDF with 'okular'
# The Makefile understands 'latex'/'pdflatex' with or without 'bibtex'.
# The Makefile will apply a set of tests aiming to catch common typos, repeated words, 
# check US/British spelling and some aspects of AAS/MNRAS journal style.
#
# The Makefile assumes it is run by GNUmake and relies on external tools including cat, cut, grep, sed, awk, and okular
# 
# The originla version of this Makefile was created by Kirill Sokolovsky <kirx@kirx.net>
#
######################################################################################################
# Manual setttings that modify the makefile behaviour

# Set to "yes" if this is an arXiv sumbission (needs .bbl file) otherwise set "no" (remove .bbl file on cleanup)
ARXIV=no
#ARXIV=yes

# Display the compiled document using okular or other PDF viewer? (yes/no)
LAUNCH_PDF_VIEWER_TO_DISPLAY_COMPILED_PAPER=yes

# is texcount is not installed the Makefile will complain about it but will not fail
COUNT_NUMBER_OF_CHARACTERS_WITH_TEXCOUNT=yes

# make a grayscale copy of the PDF - think of the colorblind people and the ones with cheap laser printers
PRODUCE_BLACK_AND_WHITE_COPY_OF_THE_PDF_TO_CHECK_HOW_IT_LOOKS=no

# Disable some individual tests if needed (yes -- test enabled / no -- test disabled)
#
# demand \textsc{MyCodeName}
TEST_SOFTWARE_TEXTSC=yes
CODE_NAMES_CASE_INSENSITIVE := IRAF MIDAS AIPS CASA DS9 XSPEC HEASoft Fermitools Difmap DiFx PIMA SExtractor PSFEx PyZOGY lightkurve photutils
CODE_NAMES_CASE_SENSITIVE := VaST

# warn about UTF8 characters in the .tex source files
TEST_NONASCII_CHARS=yes
# do not allow km/s, demand km\,s^{-1} instead
TEST_KM_S=yes

######################################################################################################
# Automated setup: try hard to find the main tex file and recognize its format: PDF figure, BibTeX...
#

SHELL := /usr/bin/env bash

# manually exclude some tex filenames from consideration
ALL_TEXFILES_FOR_GRAMMAR_CHECK := $(shell ls *.tex | grep -v -e 'aassymbols.tex' -e '_backup' -e '_BACKUP' -e '_BASE' -e '_LOCAL' -e '_REMOTE')

# Set *main.tex as the main TeX file, otherwise assume the largest TeX file is the main TeX file
TEXFILE_BASENAME := $(shell if [ -f *main.tex ];then ls *main.tex ;else ls -S $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) ;fi | head -n1 | sed 's:.tex::g')


PDFTEX := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -e 'includegr' -e 'file' | grep --quiet -e '.pdf' -e '.png' && echo 'yes' )
BIBTEX := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet 'bibliographystyle' && echo 'yes' )

BIBFILENAME := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep 'bibliography{' | head -n1 | awk -F'bibliography{' '{print $$2}' | awk -F'}' '{print $$1".bib"}')

MODIFY_BIBFILE_ULTRACOMPACT_REF := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet -e 'bibliographystyle.mnras_shortlisthack' -e 'bibliographystyle.supershort_numbers_oneline' && echo 'yes' )

MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep 'documentclass' | grep --quiet 'mnras' && echo 'yes' )

AAS_MANUSCRIPT_REQUIRING_US_SPELLING := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep 'documentclass' | grep --quiet -e 'aastex' -e 'emulateapj' && echo 'yes' )

# if somehow both MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING and AAS_MANUSCRIPT_REQUIRING_US_SPELLING are set to 'yes'
# set MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING to 'no' and prefer the US spelling
ifeq ($(MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING),yes)
ifeq ($(AAS_MANUSCRIPT_REQUIRING_US_SPELLING),yes)
MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING := no
endif
endif

# First, case-insensitive and then case-sensitive search for names of common astronomy codes
ANY_KNOWN_SOFTWARE_MENTIONED := $(shell \
    for code in $(CODE_NAMES_CASE_INSENSITIVE); do \
        if cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' | sed 's/\\citep{[^}]*}//g' | sed 's/\\cite{[^}]*}//g' | sed 's/\\citealt{[^}]*}//g' | sed 's/\\texttt{[^}]*}//g' | grep --quiet --ignore-case -e "\\b$$code\\b" ; then \
            echo 'yes'; \
            exit; \
        fi; \
    done; \
    for code in $(CODE_NAMES_CASE_SENSITIVE); do \
        if cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' |  sed 's/\\citep{[^}]*}//g' | sed 's/\\cite{[^}]*}//g' | sed 's/\\citealt{[^}]*}//g' | sed 's/\\texttt{[^}]*}//g' | grep --quiet -e "\\b$$code\\b" ; then \
            echo 'yes'; \
            exit; \
        fi; \
    done)


IS_SWIFT_UVOT_MENTIONED := $(shell cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet -e 'Swift' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet -e 'UVOT' && echo 'yes' )


all: info clean check_utf8 check_spell check_robot_words check_no_whitespace check_coma_instead_of_period check_extra_white_space try_to_find_duplicate_words shorten_journal_names_bib check_british_spelling check_us_spelling check_gamma_ray_math_mode check_software_small_capitals check_swift_uvot_lowercase_filternames check_km_s check_units check_consistent_unbreakable_space_size_UT check_consistent_Halpha_Hbeta check_consistent_multiwavelength check_phrasing check_filenames_good_for_arXiv  $(TEXFILE_BASENAME).pdf  produce_balck_and_white_copy_of_the_pdf check_for_bonus_figures  display_compiled_pdf


info: $(TEXFILE_BASENAME).tex
	@echo "Starting the ultimate LaTeX Makefile"
	@echo "TEXFILE_BASENAME= "$(TEXFILE_BASENAME)
ifeq ($(BIBTEX),yes)
	@echo "BIBFILENAME= "$(BIBFILENAME)
else
	@echo "No BibTeX, fine"
endif

clean: 
ifeq ($(ARXIV),yes)
	# do not remove .bbl file for arXiv submission
	rm -f $(TEXFILE_BASENAME).pdf $(TEXFILE_BASENAME).ps $(TEXFILE_BASENAME).dvi $(TEXFILE_BASENAME).log $(TEXFILE_BASENAME).aux $(TEXFILE_BASENAME).blg DEADJOE *~ *.bak main_paper.pdf online_material.pdf $(TEXFILE_BASENAME).out $(TEXFILE_BASENAME).teximulated mn2e.bst_backup missfont.log *~ $(TEXFILE_BASENAME)_grayscale.pdf
else
	# remove .bbl file and everything else
	rm -f $(TEXFILE_BASENAME).bbl  $(TEXFILE_BASENAME).pdf $(TEXFILE_BASENAME).ps $(TEXFILE_BASENAME).dvi $(TEXFILE_BASENAME).log $(TEXFILE_BASENAME).aux $(TEXFILE_BASENAME).blg DEADJOE *~ *.bak main_paper.pdf online_material.pdf $(TEXFILE_BASENAME).out $(TEXFILE_BASENAME).teximulated mn2e.bst_backup missfont.log *~ $(TEXFILE_BASENAME)_grayscale.pdf
endif


check_utf8: $(TEXFILE_BASENAME).tex
ifeq ($(TEST_NONASCII_CHARS),yes)
	#
	# Display any non-ASCII UTF8 characters higlighting them with color.
	# (If this check fails, but you see no color in the output -
	# the non-ASCII character is masquerading as white space and
	# you may need to select text with mouse to see the offending character.)
	#
	@echo "Searching for non-ASCII characters in TeX file"
	{ LC_ALL=C grep --color=always '[^ -~]\+' $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) && exit 1 || true; }
	#{ LC_ALL=C grep --color=always '[^ -~]\+' $(TEXFILE_BASENAME).tex && exit 1 || true; }
	# Check that the TeX file type is not Unicode - but that may miss some stray Unicode character
	file $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep -e 'Unicode' -e 'ISO-8859' && exit 1 || true; }
	#file $(TEXFILE_BASENAME).tex | { grep Unicode && exit 1 || true; }
ifeq ($(BIBTEX),yes)
	@echo "Searching for non-ASCII characters in BibTeX file"
	{ LC_ALL=C grep --color=always '[^ -~]\+' $(BIBFILENAME) && echo 'WARNING: Unicode character in .bib file - trying to fix' && cp $(BIBFILENAME) $(BIBFILENAME).backup && sed -i 's/\(\x09\|\x0B\|\x0C\|\xC2\xA0\|\xE2\x80\x80\|\xE2\x80\x81\|\xE2\x80\x82\|\xE2\x80\x83\|\xE2\x80\x84\|\xE2\x80\x85\|\xE2\x80\x86\|\xE2\x80\x87\|\xE2\x80\x88\|\xE2\x80\x89\|\xE2\x80\x8A\|\xE2\x80\xAF\|\xE2\x81\x9F\|\xE3\x80\x80\|\x98\)/ /g'  $(BIBFILENAME) || true; }
	{ LC_ALL=C grep --color=always '[^ -~]\+' $(BIBFILENAME) && echo 'ERROR: Unicode character in .bib file' && exit 1 || true; }
endif
endif


check_spell: $(TEXFILE_BASENAME).tex
	# Case-insensitive search
	# sed 's/[^ ]*.eps[^ ]*//ig'   is to make sure figure filenames are ignored
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:the A config::g' | sed 's:a-priori::g' | sed 's:a priori::g' | sed 's:binary tree::g' | sed 's:pile up::g' | sed 's:pile~up::g' | sed 's/[^ ]*.eps[^ ]*//ig' | sed 's/\\url{[^}]*}//g' | { grep --color=always --ignore-case -e 'compliment' -e 'complimented' -e 'ile up' -e 'ile~up' -e '\bcan will\b' -e '\bmay can\b' -e '\bmay will\b' -e '\ba the\b' -e '\bthe a\b' -e '\bwhited\b' -e '\bneutrons star\b' -e '\bhotpot\b' -e '\brang\b' -e 'has be seen' -e 'synchroton' -e '\bhight\b' -e 'far from being settled' -e 'recourses' -e '\bwile\b' -e 'will allows' -e '\btree\b' -e '\ban new\b' && exit 1 || true; }
	# Case-sensitive search
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:the A config::g' | { grep --color=always -e 'x-ray' -e ' tp ' && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -ie 's/\\[A-Za-z0-9]* / /g' | { grep --color=always 'countrate' && echo "SHOULD BE count rate" && exit 1 || true; }
	# Use \b to match on "word boundaries", which will make your search match on whole words only.
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always '\bgenue\b' && echo "SHOULD BE genuine" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always '\bTHe\b' && echo "SHOULD BE the" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'maid' && echo "DID YOU MEAN made ?" && exit 1 || true; }
	# 'substraction' is a rare synonym for 'embezzlement' https://www.merriam-webster.com/dictionary/substraction
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'substraction' && echo "DID YOU MEAN subtraction ?" && exit 1 || true; }
	# and the all-time classic
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'redshit' && echo "DID YOU MEAN redshift ?" && exit 1 || true; }
	# 'common-envelop' is not your ordinary package for a letter
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bcommon-envelop\b' && echo "DID YOU MEAN common-envelope ?" && exit 1 || true; }
	# ' on Fig'
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bon Fig' && echo "DID YOU MEAN in Fig... ?" && exit 1 || true; }
	#
	# 'number if'
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bnumber if\b' && echo "DID YOU MEAN number of ?" && exit 1 || true; }
	# novae instead of novas, unless it looks like software name 'NOVAS' - a popular astrometry library
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/textsc{[^{}]*}//g' | sed -e 's/texttt{[^{}]*}//g' | sed -e 's/url{[^{}]*}//g' | { grep --color=always '\bnovas\b' && echo "DID YOU MEAN novae ?" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bloosing\b' && echo "DID YOU MEAN losing ? othewise use loosening" && exit 1 || true; }
	# Appending~\ref{
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e '\bAppending~\\ref{' -e '\bAppending \\ref{' && echo "DID YOU MEAN Appendix~\\ref{" && exit 1 || true; }
	# GHz
	cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always -e '\bGHZ\b' -e '\bGhz\b' && echo "SHOULD BE  GHz" && exit 1 || true; }
	#
	cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always 'tune able' && echo "SHOULD BE tunable" && exit 1 || true; }
	#
	cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always 'thejet' && echo "SHOULD BE the jet" && exit 1 || true; }

check_robot_words:  $(TEXFILE_BASENAME).tex
	# Words and phrases normal people do not use
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bdelve\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bgrappling\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bunleash\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\btestament\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bjourney\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bsupercharge\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bembrace\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bburning question\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bunlock\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\buplevel\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\brevolutionize\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bgroundbreaking\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\belevate\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bin the wake of\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\bavid\b' && echo "ARE YOU A ROBOT?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'It is important to note' && echo "DON'T WRITE LIKE THAT IF YOU ARE A HUMAN" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e "I can't help with that" -e "Is there something else I can help you with" -e "I'm not able to fulfill" -e "That's not something I can do" -e "I can offer assistance on a wide range of topics" -e "I can't proceed with this specific request" -e "I'm sorry but as a AI language model" -e "Here are some" && echo "ARE YOU KIDDING ME?" && exit 1 || true; }
	
check_no_whitespace: $(TEXFILE_BASENAME).tex
	#  cut -f1 -d"%" -- ignore everything after %
	#  sed -e 's/\[[^][]*\]//g' -- ignore everything between []
	#  sed -e 's/{[^{}]*}//g'   -- ignore everything between {}
	#
	# period      sed 's:[A-Z].[A-Z].::g' will allow for two capital letter combinations like initials K.S.
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's:R.A.::g' | sed 's:L.A.Cosmic::g' | sed 's:\\.M::g' | sed 's:Obs.ID::g' | sed 's:U.S.::g' | sed 's:H.E.S.S.::g' | sed 's:J.D.L.::g' | sed 's:K.V.S.::g' | sed 's:E.A.::g' | sed 's:Ras.Pi::g' | sed 's:Ph.D.::g' | sed 's:P.O.::g' | sed 's:[A-Z].[A-Z].[A-Z].::g'  | sed 's:[A-Z].[A-Z].::g' | { grep --color=always -e '\.[A-Z]' && exit 1 || true; }
	# two periods
	# sed -e 's/\.\.\.//g' -- allow for three periods 
	# sed -e 's/\.\.\///g' -- allow for '../' as in file path
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\.\.\.//g' | sed -e 's/\.\.\///g' | { grep --color=always -e '\.\.' && exit 1 || true; }
	# coma periods;   sed 's:\\,::g' -- remove unbreakable half-spaces from the test
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's:\\,::g' | { grep --color=always -e '\,\.' && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's:\\,::g' | { grep --color=always -e ',\.' && exit 1 || true; }
	# some journal styles allow ".," combination: "e.g.,"
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | { grep --color=always -e '\.\,' && exit 1 || true; }
	# two comas;   sed 's:\\,::g' -- remove unbreakable half-spaces from the test
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's:\\,::g' | { grep --color=always -e '\,\,' && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's:\\,::g' | { grep --color=always -e ',,' && exit 1 || true; }
	# missing \ref (but allow \href {http://...} and stuff like {dblp:#1})
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | grep -v -e 'href ' -e ':#1}' | { grep --color=always -E -e '~{\w*:' -e ' {\w*:' && echo "MISSING \\ref{} ?" && exit 1 || true; }
	# White space between Fig. and ref
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Fig \\ref' && echo "SHOULD BE Fig.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figs \\ref' && echo "SHOULD BE Figs.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Fig\, \\ref' && echo "SHOULD BE Fig.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figs\. \\ref' && echo "SHOULD BE Figs.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Fig\.\\ref' && echo "SHOULD BE Fig.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figs\.\\ref' && echo "SHOULD BE Figs.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Fig\\ref' && echo "SHOULD BE Fig.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figs\\ref' && echo "SHOULD BE Figs.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Fig~\\ref' && echo "SHOULD BE Fig.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figs~\\ref' && echo "SHOULD BE Figs.~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figure\\ref' && echo "SHOULD BE Figure~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figures\\ref' && echo "SHOULD BE Figures~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figure \\ref' && echo "SHOULD BE Figure~\\ref{}" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always 'Figures \\ref' && echo "SHOULD BE Figures~\\ref{}" && exit 1 || true; }
	# White space before \cite
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\protect\\citeauthoryear::g' | sed 's:\\protect\\citename::g' | { grep --color=always '[a-z]\\cite' && echo "NO WHITE SPACE BEFORE \\cite" && exit 1 || true; }

check_extra_white_space: $(TEXFILE_BASENAME).tex
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v -e '\.\.\/' -e ' \.\/' | { grep --color=always ' \.' && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always ' \,' && exit 1 || true; }

check_coma_instead_of_period: $(TEXFILE_BASENAME).tex
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | grep -v -e 'Uni' -e 'Obs' -e 'Inst' -e 'The Netherlands' -e 'The United' | { grep --color=always -e '\,The' -e '\, The' && exit 1 || true; }

check_units: $(TEXFILE_BASENAME).tex
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | { grep --color=always '\bhr\b' && echo "SHOULD BE h ACCORDING TO IAU RECOMMENDATIONS ON UNITS https://www.iau.org/publications/proceedings_rules/units/" && exit 1 || true; }

check_phrasing: $(TEXFILE_BASENAME).tex
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | { grep --color=always -e '\ballow one to identify\b' -e '\ballow to identify\b' && echo "SHOULD BE allow the identification of" && exit 1 || true; }

try_to_find_duplicate_words: $(TEXFILE_BASENAME).tex
	#
	# Checking for repeated words over linebreaks
	# We do not exclude comments, so line numbers will be correct
	# sed -n '/filecontents/,/filecontents/!p'  -- ignore everything between these lines (it's an embedded file)
	# grep -v ' \-\-[A-Za-z]'    -- remove command line arguments examples
	#                   ' & '    -- ignore tables that may well have duplicate words/numbers
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | grep -v -e ' \--[A-Za-z]' -e ' & ' | cut -f1 -d"%" | sed -n '/filecontents/,/filecontents/!p' | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | { grep -Ei --color  "\b(\w+)\b\s*\1\b" && exit 1 || true; }
	#  sed 's/%.*$//'    -- remove everything after %
	#  sed '/^[[:space:]]*$/d' -- remoove empty lines
	# The output line nubers may not be exact as we skip comment lines
	# sed -n '/filecontents/,/filecontents/!p'  -- ignore everything between these lines (it's an embedded file)
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | grep -v -e ' \--[A-Za-z]' -e ' & ' | cut -f1 -d"%" | sed -n '/filecontents/,/filecontents/!p' | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | { grep -Ei --color  "\b(\w+)\b\s*\1\b" && exit 1 || true; }
	#
	# Catch word repeats in one line (obsolete)
	# The old version that doesn't catch everything
	# sed -n '/filecontents/,/filecontents/!p'  -- ignore everything between these lines (it's an embedded file)
	#cat $(TEXFILE_BASENAME).tex | sed -n '/filecontents/,/filecontents/!p' | sed 's:\\it : :g' | grep -v -E '[0-9]cm' | grep -v -E '[0-9]in' | grep -v -e '&' -e 'textwidth' -e 'includegraphicx' -e 'includegraphics' -e 'tabular' | { egrep "(\b[a-zA-Z]+) \1\b"  && exit 1 || true; }
	# The new experimental version
	#  sed -e 's/\[[^][]*\]//g' -- ignore everything between []
	#  sed -e 's/{[^{}]*}//g'   -- ignore everything between {}
	# mess 'caption{}' and 'captionbox{}' as we still want to check for repeated words in captions
	# sed -n '/filecontents/,/filecontents/!p'  -- ignore everything between these lines (it's an embedded file)
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | grep -v -e ' \--' -e ' & ' | sed -n '/filecontents/,/filecontents/!p' | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | { grep -Ein --color  "\b(\w+)\b\s*\1\b" && exit 1 || true; }
	# Last-trench effort -- just grep for the most common repetitions
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always -e ' the the ' -e ' a the ' && exit 1 || true; }
	#
	#######################
	# sed 's/[[:blank:]]\+/ /g' - replace multiple white spaces with one white space
	# Search for suspicious word combinations
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always  "\bare know\b" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always -e "\bmission line\b" -e "\bmission lines\b" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always "\bwill be also be\b" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always "\bdivided my the\b" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed 's:\\it : :g' | sed 's:\\em : :g' | sed 's:\\bf : :g' | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | grep -v 'tabular' | sed 's:caption{::g' | sed 's:captionbox{::g' | sed -e 's/{[^{}]*}//g' | sed -e 's/{[^{}]*}//g' | sed -e 's/\[[^][]*\]//g' | sed -e 's/\[[^][]*\]//g' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always "\bthe on\b" && exit 1 || true; }
	# "the were" -> "they were"
	#cat *.tex | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bthe were\b' && echo "DID YOU MEAN they were ?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bthe were\b' && echo "DID YOU MEAN they were ?" && exit 1 || true; }
	# "Through this paper" -> "Throughout this paper"
	#cat *.tex | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bThrough this paper\b' && echo "DID YOU MEAN throughout this paper ?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bThrough this paper\b' && echo "DID YOU MEAN throughout this paper ?" && exit 1 || true; }
	# "in order to not" -> "in order not to"
	#cat *.tex | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bin order to not\b' && echo "DID YOU MEAN in order not to ?" && exit 1 || true; }	
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bin order to not\b' && echo "DID YOU MEAN in order not to ?" && exit 1 || true; }	
	# two version -> two versions
	#cat *.tex | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case -e '\btwo version\b' -e '\bthree version\b' -e '\bfour version\b' -e '\bfive version\b' -e '\bsix version\b' -e '\bseven version\b' -e '\beight version\b' -e '\bnine version\b' -e '\bten version\b' -e '\beleven version\b' -e '\btwleve version\b' && echo "DID YOU MEAN versions ?" && exit 1 || true; }	
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case -e '\btwo version\b' -e '\bthree version\b' -e '\bfour version\b' -e '\bfive version\b' -e '\bsix version\b' -e '\bseven version\b' -e '\beight version\b' -e '\bnine version\b' -e '\bten version\b' -e '\beleven version\b' -e '\btwleve version\b' && echo "DID YOU MEAN versions ?" && exit 1 || true; }	
	# minor and minor axes
	#cat *.tex | sed 's/%.*$$//' | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case 'minor and minor axes' && echo "DID YOU MEAN major and minor axes ?" && exit 1 || true; }	
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case 'minor and minor axes' && echo "DID YOU MEAN major and minor axes ?" && exit 1 || true; }
	#
	# try to check the use of temporary (adjective) vs temporarily (adverb)
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\btemporary \(degrade\|improve\|decrease\|display\|create\|destroy\|add\|remove\|close\|open\|suppress\|promote\|express\|release\|capture\|stimulate\|enhance\|localize\|available\|unavailable\|excite\|calm\|dull\|relax\|accelerate\|decelerate\|withdraw\|trap\|recover\|confine\|free\|here\|there\|accessible\|inaccessible\|appear\|disappear\)\(d\|ed\)\?\b' && echo "CHECK the use of temporary (adjective) vs temporarily (adverb)" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bhole mas\b' && echo "DID YOU MEAN black hole mass ?" && exit 1 || true; }	
	# general an/and
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case -E '\b(an)\s+[bcdfgjklmpqstvwyz]' && echo "CHECK the use of an vs and  (test 1)" && exit 1 || true; }
	# an disappear
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\ban \(young\|include\|exclude\|degrade\|improve\|decrease\|display\|create\|destroy\|add\|remove\|close\|suppress\|promote\|express\|release\|capture\|stimulate\|enhance\|localize\|available\|unavailable\|excite\|calm\|dull\|relax\|accelerate\|decelerate\|withdraw\|trap\|recover\|confine\|free\|here\|there\|accessible\|inaccessible\|appear\|disappear\)\b' && echo "CHECK the use of an vs and  (test 2)" && exit 1 || true; }
	# last a few day
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\blast a few \(second\|minute\|hour\|day\|month\|year\)\b' && echo "CHECK last a few ...s" && exit 1 || true; }
	# is excludes
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bas is \(include\|exclude\|degrade\|improve\|increase\|decrease\|display\|create\|destroy\|add\|remove\|close\|open\|suppress\|promote\|express\|release\|capture\|stimulate\|enhance\|localize\|available\|unavailable\|excite\|calm\|dull\|relax\|accelerate\|decelerate\|withdraw\|trap\|recover\|confine\|free\|here\|there\|accessible\|inaccessible\|appear\|disappear\)\(s\|d\|ed\)\?\b' && echo "CHECK the use of is vs it" && exit 1 || true; }
	# these is no doubt
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bthese is no doubt\b' && echo "SHOULD BE there is no doubt" && exit 1 || true; }
	# further away
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bfurther away\b' && echo "SHOULD BE farther away" && exit 1 || true; }
	# further than
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bfurther than\b' && echo "SHOULD BE farther than" && exit 1 || true; }
	# out analysis
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bout analysis\b' && echo "SHOULD BE our analysis" && exit 1 || true; }
	# from at
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\bfrom at\b' && echo "SHOULD BE form at OR from OR at" && exit 1 || true; }
	# even grades
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | sed '/^[[:space:]]*$$/d' | awk 'BEGIN{getline l;} {combined=l " " $$0; printf(" %.5d - %.5d: %s\n",FNR-1,FNR, combined); l=$$0;}' | sed 's/[[:blank:]]\+/ /g' | { grep --color=always --ignore-case '\beven grades\b' && echo "SHOULD BE event grades" && exit 1 || true; }
	
	
# This hack will modify the .bib file replacing some long journal names if we are using mnras_shortlisthack.bst style
shorten_journal_names_bib: $(BIBFILENAME)
ifeq ($(MODIFY_BIBFILE_ULTRACOMPACT_REF),yes)
	# Modify .bib
	@echo "I WILL RUIN THE BIBFILE"
	echo $(MODIFY_BIBFILE_ULTRACOMPACT_REF)
	# If the bibfile looks unmodified, save a backup copy
	cat $(BIBFILENAME) | { grep -e '{ATel}' -e '{RNAAS}' -e '{AN}' || cp -v $(BIBFILENAME) $(BIBFILENAME)_backup_long_journal_names ; }
	# Do the actual modification
	cat $(BIBFILENAME) | sed 's:{The Astronomer.s Telegram}:{ATel}:g' | sed 's:{Research Notes of the American Astronomical Society}:{RNAAS}:g' | sed 's:{Astronomische Nachrichten}:{AN}:g' > $(BIBFILENAME)_tmp && mv -v $(BIBFILENAME)_tmp $(BIBFILENAME)
else
	# Nothing to do
	@echo "KEEP THE ORIGINAL BIBFILE"
	echo $(MODIFY_BIBFILE_ULTRACOMPACT_REF)
endif

check_british_spelling:
ifeq ($(MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING),yes)
	# Check for British spelling
	# MNRAS style guide https://academic.oup.com/mnras/pages/General_Instructions#6%20Style%20guide
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v '$^{' | grep -v '\\center' | { grep --color=always 'centered' && echo "SHOULD BE centred" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v '$^{' | grep -v '\\center' | { grep --color=always 'center' && echo "SHOULD BE centre" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'sulfur' && echo "SHOULD BE sulphur" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'labeled' && echo "SHOULD BE labelled" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'analyze' && echo "SHOULD BE analyse" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'parametrise' && echo "SHOULD BE parametrize" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'acknowledgments' && echo "SHOULD BE Acknowledgements (this is how the section is named in the MNRAS template)" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'artifact' && echo "SHOULD BE artefact" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'best-fit ' && echo "SHOULD BE best-fitting" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'disk' && echo "SHOULD BE disc" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'halos' && echo "SHOULD BE haloes" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'hot-spot' && echo "SHOULD BE hotspot" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'nonlinear' && echo "SHOULD BE non-linear" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case ' onto ' && echo "SHOULD BE on to" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'timescale' && echo "SHOULD BE time-scale" && exit 1 || true; }
	# random collection of astronomy-specific words
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'barycenter' && echo "SHOULD BE barycentre" && exit 1 || true; }
	# random collection of words
	# sed 's/\\[^~]*{//g'  will remove \textcolor{
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\[^~]*{//g' | grep -v -e 'xcolor' -e 'rgbcolor' | { grep --color=always --ignore-case 'color' && echo "SHOULD BE colour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'flavor' && echo "SHOULD BE flavour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'humor' && echo "SHOULD BE humour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'traveling' && echo "SHOULD BE travelling" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'behavior' && echo "SHOULD BE behaviour" && exit 1 || true; }
	# Use \b to match on "word boundaries", which will make your search match on whole words only.
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's:laborator::g' | sed 's:ollaboration::g' | grep -v '$^{' | { grep --color=always '\blabor\b' && echo "SHOULD BE labour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'neighbor' && echo "SHOULD BE neighbour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'paralyze' && echo "SHOULD BE paralyse" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's:talogue::g' | { grep --color=always --ignore-case 'catalog' && echo "SHOULD BE catalogue" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '\banalog\b' && echo "SHOULD BE analogue" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'centimeter' && echo "SHOULD BE centimetre" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'modeling' && echo "SHOULD BE modelling" && exit 1 || true; }
	# Other MNRAS things
	# https://academic.oup.com/mnras/pages/general_instructions#6.5%20Miscellaneous%20journal%20style
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | { grep --color=always --ignore-case -e '\\%' -e 'percent' && echo "SHOULD BE per cent" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e '~sec ' -e ' sec ' -e '\\,sec' && echo "SHOULD BE s" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'e\.g\.\,' && echo "SHOULD BE e.g." && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'i\.e\.\,' && echo "SHOULD BE i.e." && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e 'cf\.\,' -e ' cf ' && echo "SHOULD BE cf." && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case ' etc ' && echo "SHOULD BE etc." && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case '``' && echo "SHOULD BE \`" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case "''" && echo "SHOULD BE \'" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e 'eq\.' -e 'eqn\.' -e 'Eq\.' -e 'Eqn\.' && echo "SHOULD BE equation~()" && exit 1 || true; }
else
	# Nothing to do
	@echo "THIS DOES NOT LOOK LIKE A MNRAS MANUSCRIPT - NOT ENFORCING BRITISH SPELLING"
	echo $(MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING)
endif

check_us_spelling:
ifeq ($(AAS_MANUSCRIPT_REQUIRING_US_SPELLING),yes)
	# Check for US spelling
	# AAS style guide https://journals.aas.org/aas-style-guide/
	# they also suggest follow The Chicago Manual of Style https://www.chicagomanualofstyle.org/home.html
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | grep -v '$^{' | grep -v '\\center' | { grep --color=always 'centered' && echo "SHOULD BE centred" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v '$^{' | grep -v '\\center' | { grep --color=always 'centred' && echo "SHOULD BE centered" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | grep -v '$^{' | grep -v '\\center' | { grep --color=always 'center' && echo "SHOULD BE centre" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v '$^{' | grep -v '\\center' | { grep --color=always 'centre' && echo "SHOULD BE center" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'sulfur' && echo "SHOULD BE sulphur" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'sulphur' && echo "SHOULD BE sulfur" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'labeled' && echo "SHOULD BE labelled" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'labelled' && echo "SHOULD BE labeled" && exit 1 || true; }
	#
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'analyze' && echo "SHOULD BE analyse" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's:analyses::g' | sed 's:Analyses::g' | { grep --color=always --ignore-case 'analyse' && echo "SHOULD BE analyze / analyzed  see https://www.chicagomanualofstyle.org/book/ed17/part2/ch07/psec003.html" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'parametrized' && echo "SHOULD BE parameterized" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'parametrise' && echo "SHOULD BE parametrize" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'parametrize' && echo "SHOULD BE parameterize" && exit 1 || true; }
	# Why I was under impression that 'acknowledgements' is the correct spelling in AAS journals?
	# Their style guide spells 'acknowledgments' https://journals.aas.org/manuscript-preparation/#acknowledgments
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'acknowledgments' && echo "SHOULD BE acknowledgements" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'acknowledgements' && echo "SHOULD BE acknowledgments" && exit 1 || true; }
	#
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'artifact' && echo "SHOULD BE artefact" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'artefact' && echo "SHOULD BE artifact" && exit 1 || true; }
	# Yes, best-fitting seems to be OK at AAS
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'best-fit ' && echo "SHOULD BE best-fitting" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'best-fitting ' && echo "SHOULD BE best-fit" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'disk' && echo "SHOULD BE disc" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e ' disc\,' -e ' disc\.' -e 'disc$$' -e 'disc ' && echo "SHOULD BE disk" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'halos' && echo "SHOULD BE haloes" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'haloes' && echo "SHOULD BE halos" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'hot-spot' && echo "SHOULD BE hotspot" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'nonlinear' && echo "SHOULD BE non-linear" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case ' onto ' && echo "SHOULD BE on to" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case ' on to ' && echo "SHOULD BE onto" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e 'time-scale' -e 'time scale' -e 'time~scale' && echo "SHOULD BE timescale" && exit 1 || true; }
	#
	# random collection of words
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'color' && echo "SHOULD BE colour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'colour' && echo "SHOULD BE color" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'flavor' && echo "SHOULD BE flavour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'flavour' && echo "SHOULD BE flavor" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'humor' && echo "SHOULD BE humour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'humour' && echo "SHOULD BE humor" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | grep -v '$^{' | { grep --color=always 'labor' && echo "SHOULD BE labour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v '$^{' | { grep --color=always 'labour' && echo "SHOULD BE labor" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'neighbor' && echo "SHOULD BE neighbour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'neighbour' && echo "SHOULD BE neighbor" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'paralyze' && echo "SHOULD BE paralyse" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'paralyse' && echo "SHOULD BE paralyze" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | sed 's:talogue::g' | { grep --color=always --ignore-case 'catalog' && echo "SHOULD BE catalogue" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's:talogue::g' | { grep --color=always --ignore-case 'catalogue' && echo "SHOULD BE catalog" && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'analog' && echo "SHOULD BE analogue" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'analogue' && echo "SHOULD BE analog" && exit 1 || true; }
	#cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'traveling' && echo "SHOULD BE travelling" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'travelling' && echo "SHOULD BE traveling" && exit 1 || true; }
	#cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'behavior' && echo "SHOULD BE behaviour" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'behaviour' && echo "SHOULD BE behavior" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'can not' && echo "SHOULD BE cannot  see https://www.merriam-webster.com/grammar/cannot-vs-can-not-is-there-a-difference" && exit 1 || true; }
	#
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case 'modeling' && echo "SHOULD BE modelling" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'modelling' && echo "SHOULD BE modeling" && exit 1 || true; }
	# Other AAS things
	#cat $(TEXFILE_BASENAME).tex | { grep --color=always --ignore-case '\\%' && echo "SHOULD BE per cent" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case -e '~sec ' -e ' sec ' -e '\\,sec' && echo "SHOULD BE s" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'e\.g\. ' && echo "SHOULD BE e.g.," && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'e\.g\.\]' && echo "SHOULD BE e.g.," && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case 'i\.e\. ' && echo "SHOULD BE i.e.," && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case -e 'cf\.\,' -e ' cf ' && echo "SHOULD BE cf." && exit 1 || true; }
	#cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | { grep --color=always --ignore-case ' etc ' && echo "SHOULD BE etc." && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always --ignore-case ' `[a-zA-Z]' && echo "SHOULD BE \`\`" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v "s' " | { grep --color=always --ignore-case "[a-zA-Z]' " && echo "SHOULD BE \'\'" && exit 1 || true; }
	# super AAS-specific
	# https://journals.aas.org/manuscript-preparation/#figure_numbering
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'Fig\.' && echo "SHOULD BE Figure" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'Figs\.' && echo "SHOULD BE Figures" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'Sec\.' && echo "SHOULD BE Section" && exit 1 || true; }
	#
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'errorbar' && echo "SHOULD BE error bar" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'free-fall' && echo "SHOULD BE freefall" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'free fall' && echo "SHOULD BE freefall" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'free~fall' && echo "SHOULD BE freefall" && exit 1 || true; }
	# https://journals.aas.org/aas-style-guide/
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'black body' -e 'black-body' -e 'black~body' && echo "SHOULD BE blackbody" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'gray body' -e 'gray-body' -e 'gray~body' && echo "SHOULD BE graybody" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'BL Lacs' -e 'BL~Lacs' && echo "SHOULD BE BL Lacertae objects, also BL Lac objects" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep -v '\\linewidth' | { grep --color=always 'linewidth' && echo "SHOULD BE line width" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'Milky Way Galaxy' && echo "SHOULD BE Milky Way (MW): the Milky Way" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'zero point' -e 'zero~point' && echo "SHOULD BE zero-point" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'radio loud' -e 'radio~loud' && echo "SHOULD BE radio-loud" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'radio quiet' -e 'radio~quiet' && echo "SHOULD BE radio-quiet" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always -e 'radio loudness' -e 'radio~loudness' && echo "SHOULD BE radio-loudness" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'metal poor' && echo "SHOULD BE metal-poor" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'metal rich' && echo "SHOULD BE metal-rich" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'flat fielding' && echo "SHOULD BE flat-fielding" && exit 1 || true; }
	# check that ORCIDs are uniq
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep '\\author\[' | awk -F'[' '{print $$2}' | awk -F']' '{print $$1}' | sort | uniq -d | grep --color=always '.' && echo "CHECK for non-uniq ORCID" && exit 1 || true; }
	
else
	# Nothing to do
	@echo "THIS DOES NOT LOOK LIKE AN AAS MANUSCRIPT - NOT ENFORCING US SPELLING"
	echo $(AAS_MANUSCRIPT_REQUIRING_US_SPELLING)
endif

# We want to check for a consistent use of 'gamma-ray' vs '$\gamma$-ray', but only if it's a journal paper:
# in a proposal draft we may have an ASCII-only abstract and LaTeX text body.
DO_IT_CHECK_GAMMA_RAY_MATH_MODE=no
ifeq ($(AAS_MANUSCRIPT_REQUIRING_US_SPELLING),yes)
DO_IT_CHECK_GAMMA_RAY_MATH_MODE=yes
endif
ifeq ($(MNRAS_MANUSCRIPT_REQUIRING_BRITISH_SPELLING),yes)
DO_IT_CHECK_GAMMA_RAY_MATH_MODE=yes
endif
check_gamma_ray_math_mode:
ifeq ($(DO_IT_CHECK_GAMMA_RAY_MATH_MODE),yes)
	@echo "THIS IS AN MNRAS OR AAS MANUSCRIPT"
	echo $(DO_IT_CHECK_GAMMA_RAY_MATH_MODE)
	{ cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | grep --quiet 'gamma-ray' && cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | grep --quiet '$$\\gamma$$-ray' && cat $(TEXFILE_BASENAME).tex | cut -f1 -d"%" | grep --color=always -e 'gamma-ray' -e '$$\\gamma$$-ray' && echo "SHOULD BE USING CONSISTENTLY 'gamma-ray' or '$$\\gamma\$$-ray'" && exit 1 || true; }
else
	# Nothing to do
	@echo "THIS DOES NOT LOOK LIKE AN MNRAS OR AAS MANUSCRIPT - NOT ENFORCING MATH MODE for 'gamma-ray'"
	echo $(DO_IT_CHECK_GAMMA_RAY_MATH_MODE)
endif

check_km_s:
ifeq ($(TEST_KM_S),yes)
	# Check for km/s
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'km/s' && echo "SHOULD BE km\\,s$$^{-1}$$ ?" && exit 1 || true; }
endif

check_software_small_capitals:
ifeq ($(ANY_KNOWN_SOFTWARE_MENTIONED),yes)
ifeq ($(TEST_SOFTWARE_TEXTSC),yes)
	@failed=0; \
	for code in $(CODE_NAMES_CASE_INSENSITIVE); do \
		if cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g'| sed 's/\\citep{[^}]*}//g' | sed 's/\\cite{[^}]*}//g' | sed 's/\\citealt{[^}]*}//g' | sed 's/\\texttt{[^}]*}//g' | grep --quiet --ignore-case -e "\\b$$code\\b" ; then \
			! cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' | sed 's/\\citep{[^}]*}//g' | sed 's/\\cite{[^}]*}//g' | sed 's/\\citealt{[^}]*}//g' | sed 's/\\texttt{[^}]*}//g' | grep --ignore-case -e "\\b$$code\\b" | grep -v -e 'textsc' -e 'scshape' -e '{\\sc ' >/dev/null && continue ; \
			failed=1; \
		fi; \
	done; \
	for code in $(CODE_NAMES_CASE_SENSITIVE); do \
		if cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' | sed 's/\\citep{[^}]*}//g' | sed 's/\\cite{[^}]*}//g' | sed 's/\\citealt{[^}]*}//g' | sed 's/\\texttt{[^}]*}//g' | grep --quiet -e "\\b$$code\\b" ; then \
			! cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' | sed 's/\\citep{[^}]*}//g' | sed 's/\\cite{[^}]*}//g' | sed 's/\\citealt{[^}]*}//g' | sed 's/\\texttt{[^}]*}//g' | grep -e "\\b$$code\\b" | grep -v -e 'textsc' -e 'scshape' -e '{\\sc ' >/dev/null && continue ; \
			failed=1; \
		fi; \
	done; \
	if [ $$failed -eq 0 ]; then \
		echo "All code names are properly formatted with 'textsc' or 'scshape'."; \
	else \
		echo "Checking for code names without 'textsc' or 'scshape' failed."; \
		echo "Displaying occurrences of code names:"; \
		for code in $(CODE_NAMES_CASE_INSENSITIVE); do \
    			cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' | grep --color=always --ignore-case -e "\\b$$code\\b" ; \
		done; \
		for code in $(CODE_NAMES_CASE_SENSITIVE); do \
    			cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | sed 's/\\url{[^}]*}//g' | grep --color=always -e "\\b$$code\\b" ; \
		done; \
		echo "SHOULD BE \\textsc{CodeName}" ; \
		exit 1; \
	fi
else
	@echo "TEST_SOFTWARE_TEXTSC is not set to 'yes'. Skipping the test."
endif
else
	@echo "NO KNOWN SOFTWARE NAMES RECOGNIZED"
	@echo $(ANY_KNOWN_SOFTWARE_MENTIONED)
endif

check_swift_uvot_lowercase_filternames:
ifeq ($(IS_SWIFT_UVOT_MENTIONED),yes)
	# Check that Swift/UVOT filter names are lowercase
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'UVW1' && echo "Swift/UVOT FILTER NAMES SHOULD BE LOWECASE uvw1 ?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'UVM2' && echo "Swift/UVOT FILTER NAMES SHOULD BE LOWECASE uvm2 ?" && exit 1 || true; }
	cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | { grep --color=always 'UVW2' && echo "Swift/UVOT FILTER NAMES SHOULD BE LOWECASE uvw2 ?" && exit 1 || true; }
else
	# Nothing to do
	@echo "NO MENTION OF SWIFT UVOT"
	echo $(IS_SWIFT_UVOT_MENTIONED)
endif

check_consistent_unbreakable_space_size_UT:
	{ cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet '~UT' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet '\\\,UT' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --color=always -e '~UT' -e '\\\,UT' && echo "SHOULD BE USING CONSISTENTLY '~UT' or '\\,UT" && exit 1 || true; }

check_consistent_Halpha_Hbeta:
	#cat *.tex | cut -f1 -d"%" | grep --quiet -e 'H\$$_\\beta\$$' && exit 1
	{ cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet -e 'H\$$_\\beta\$$' -e 'H\$$_\\alpha\$$' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet -e 'H\$$\\beta\$$' -e 'H\$$\\alpha\$$' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --color=always  -e 'H\$$_\\beta\$$' -e 'H\$$_\\alpha\$$'  -e 'H\$$\\beta\$$' -e 'H\$$\\alpha\$$' && echo "SHOULD BE USING CONSISTENTLY 'H$$\\beta\$$' or 'H\$$_\\beta\$$' (with the underscore)" && exit 1 || true; }

check_consistent_multiwavelength:
	{ cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet -e 'H\$$_\\beta\$$' -e 'H\$$_\\alpha\$$' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --quiet 'multi-wavelength' && cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d"%" | grep --color=always  'multiwavelength' && echo "SHOULD BE USING CONSISTENTLY 'multi-wavelength' or 'multiwavelength'" && exit 1 || true; }


check_filenames_good_for_arXiv:
	# Check if all filenames in the current directory contain only characters that are good for arXiv
	# as listed at https://info.arxiv.org/help/submit/index.html#files
	{ for FILENAME in * ;do if [[ "$$FILENAME" =~ ^[0-9A-Za-z_\\.\\,\-\\=\\+]+$$ ]]; then echo "The filename '$$FILENAME' looks good"; else echo "The filename '$$FILENAME' has characters not good for arXiv"; fi ;done | grep --color=always 'characters not good for arXiv' && exit 1 || true; }



$(TEXFILE_BASENAME).pdf: $(TEXFILE_BASENAME).tex
ifeq ($(PDFTEX),yes)
	# pdflatex
	@echo "YES PDF"
	echo $(PDFTEX)
ifeq ($(BIBTEX),yes)
	@echo "YES BibTeX"
	echo $(BIBTEX)
	# This works with .pdf/.png figures
	pdflatex $(TEXFILE_BASENAME).tex && pdflatex $(TEXFILE_BASENAME).tex && bibtex $(TEXFILE_BASENAME) && pdflatex $(TEXFILE_BASENAME).tex && pdflatex $(TEXFILE_BASENAME).tex 
ifeq ($(COUNT_NUMBER_OF_CHARACTERS_WITH_TEXCOUNT),yes)
	texcount -v3 -merge -incbib -dir -sub=none -utf8 -sum $(TEXFILE_BASENAME).tex || echo "Looks like texcount is not installed - Makefile can't count words in the LaTeX file"
endif
else
	@echo "NO BibTeX"
	echo $(BIBTEX)
	# No BibTeX, .pdf/.png figures
	pdflatex $(TEXFILE_BASENAME).tex && pdflatex $(TEXFILE_BASENAME).tex 
ifeq ($(COUNT_NUMBER_OF_CHARACTERS_WITH_TEXCOUNT),yes)
	texcount -v3 -merge -incbib -dir -sub=none -utf8 -sum $(TEXFILE_BASENAME).tex || echo "Looks like texcount is not installed - Makefile can't count words in the LaTeX file"
endif
endif

else
	# latex
	@echo "NO PDF  "
	echo $(PDFTEX)
ifeq ($(BIBTEX),yes)
	@echo "YES BibTeX"
	echo $(BIBTEX)
	# BibTeX and .eps figures (the right way)
	latex $(TEXFILE_BASENAME).tex && latex $(TEXFILE_BASENAME).tex && bibtex $(TEXFILE_BASENAME) && latex $(TEXFILE_BASENAME).tex && { latex $(TEXFILE_BASENAME).tex 2>&1 | grep --color=always 'undefined on input line' && exit 1 || true; } && dvips -o $(TEXFILE_BASENAME).ps $(TEXFILE_BASENAME).dvi && ps2pdf $(TEXFILE_BASENAME).ps 
ifeq ($(COUNT_NUMBER_OF_CHARACTERS_WITH_TEXCOUNT),yes)
	texcount -v3 -merge -incbib -dir -sub=none -utf8 -sum $(TEXFILE_BASENAME).tex || echo "Looks like texcount is not installed - Makefile can't count words in the LaTeX file"
endif
else
	@echo "NO BibTeX"
	echo $(BIBTEX)	
	# This works with .eps figures or when \usepackage[demo]{graphicx} is activated
	latex $(TEXFILE_BASENAME).tex && latex $(TEXFILE_BASENAME).tex && dvips -o $(TEXFILE_BASENAME).ps $(TEXFILE_BASENAME).dvi && ps2pdf $(TEXFILE_BASENAME).ps 
ifeq ($(COUNT_NUMBER_OF_CHARACTERS_WITH_TEXCOUNT),yes)
	texcount -v3 -merge -incbib -dir -sub=none -utf8 -sum $(TEXFILE_BASENAME).tex || echo "Looks like texcount is not installed - Makefile can't count words in the LaTeX file"
endif
endif

endif


check_for_bonus_figures: $(TEXFILE_BASENAME).tex
	{ for i in *eps *png *jpg ;do if [ ! -f $$i ];then continue ;fi ; cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d'%' | grep --quiet "$$i" && continue ; echo "WARNING: a bonus figure not included in the TeX source: $$i" ;done ; echo " " ; }  && { cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d'%' | grep 'label{fig:' | awk -F'label{' '{print $$2}' | awk -F'}' '{print $$1}' | while read LABELLED_FIGURE ; do cat $(ALL_TEXFILES_FOR_GRAMMAR_CHECK) | cut -f1 -d'%' | grep --quiet "ref{$$LABELLED_FIGURE}" && continue ; echo "WARNING: a figure not referenced in the main text: $$LABELLED_FIGURE" ;done ; echo " " ; }


produce_balck_and_white_copy_of_the_pdf: $(TEXFILE_BASENAME).pdf
ifeq ($(PRODUCE_BLACK_AND_WHITE_COPY_OF_THE_PDF_TO_CHECK_HOW_IT_LOOKS),yes)
	@echo "Producing a black and white (grayscale) copy of "$(TEXFILE_BASENAME).pdf
	# -dCompressPages=false is used to speed up compilation by a second
	gs -sOutputFile=$(TEXFILE_BASENAME)_grayscale.pdf -sDEVICE=pdfwrite -sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray -dCompressPages=false -dNOPAUSE -dBATCH $(TEXFILE_BASENAME).pdf
	@echo "The grayscale copy of the document is written to "$(TEXFILE_BASENAME)_grayscale.pdf
endif



display_compiled_pdf: $(TEXFILE_BASENAME).pdf
	@echo "The document is successfully compiled: "$(TEXFILE_BASENAME).pdf
ifeq ($(LAUNCH_PDF_VIEWER_TO_DISPLAY_COMPILED_PAPER),yes)
	@echo "Trying to find a PDF viewer to display "$(TEXFILE_BASENAME).pdf
	okular $(TEXFILE_BASENAME).pdf || evince $(TEXFILE_BASENAME).pdf || xpdf $(TEXFILE_BASENAME).pdf || mupdf $(TEXFILE_BASENAME).pdf || open -a Preview $(TEXFILE_BASENAME).pdf || open -a "Adobe Acrobat Reader" $(TEXFILE_BASENAME).pdf || open -a Skim $(TEXFILE_BASENAME).pdf || firefox $(TEXFILE_BASENAME).pdf || /Applications/Firefox.app/Contents/MacOS/firefox $(TEXFILE_BASENAME).pdf || google-chrome $(TEXFILE_BASENAME).pdf || google-chrome-stable $(TEXFILE_BASENAME).pdf || chromium $(TEXFILE_BASENAME).pdf || echo "Sorry, the Makefile can't find a PDF viewer to automatically display the compiled "$(TEXFILE_BASENAME).pdf
endif
