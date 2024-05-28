PO_TEMPLATE = shit-gui-glossary.pot

ALL_POFILES = $(wildcard *.po)

$(PO_TEMPLATE): $(subst .pot,.txt,$(PO_TEMPLATE))
	./txt-to-pot.sh $< > $@

update-po:: shit-gui-glossary.pot
	$(foreach p, $(ALL_POFILES), echo Updating $p ; msgmerge -U $p $(PO_TEMPLATE) ; )
