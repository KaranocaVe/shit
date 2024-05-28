ifndef MAK_DIR_shitWEB
$(error do not run shitweb/Makefile stand-alone anymore. The "shitweb" and \
"install-shitweb" targets now live in the top-level Makefile)
endif

# Define JSMIN to point to JavaScript minifier that functions as
# a filter to have static/shitweb.js minified.
#
# Define CSSMIN to point to a CSS minifier in order to generate a minified
# version of static/shitweb.css
#

# default configuration for shitweb
shitWEB_CONFIG = shitweb_config.perl
shitWEB_CONFIG_SYSTEM = /etc/shitweb.conf
shitWEB_CONFIG_COMMON = /etc/shitweb-common.conf
shitWEB_HOME_LINK_STR = projects
shitWEB_SITENAME =
shitWEB_PROJECTROOT = /pub/shit
shitWEB_PROJECT_MAXDEPTH = 2007
shitWEB_EXPORT_OK =
shitWEB_STRICT_EXPORT =
shitWEB_BASE_URL =
shitWEB_LIST =
shitWEB_HOMETEXT = indextext.html
shitWEB_CSS_IN = static/shitweb.css
shitWEB_CSS = $(shitWEB_CSS_IN)
shitWEB_LOGO = static/shit-logo.png
shitWEB_FAVICON = static/shit-favicon.png
shitWEB_JS_IN = static/shitweb.js
shitWEB_JS = $(shitWEB_JS_IN)
shitWEB_SITE_HTML_HEAD_STRING =
shitWEB_SITE_HEADER =
shitWEB_SITE_FOOTER =
HIGHLIGHT_BIN = highlight

# What targets we'll add to 'all' for "make shitweb"
shitWEB_ALL =
shitWEB_ALL += shitweb.cgi
shitWEB_ALL += $(shitWEB_JS)

MAK_DIR_shitWEB_ALL = $(addprefix $(MAK_DIR_shitWEB),$(shitWEB_ALL))

shitWEB_PROGRAMS = shitweb.cgi

shitWEB_JS_MIN = static/shitweb.min.js
ifdef JSMIN
shitWEB_JS = $(shitWEB_JS_MIN)
shitWEB_ALL += $(MAK_DIR_shitWEB)$(shitWEB_JS_MIN)
$(MAK_DIR_shitWEB)$(shitWEB_JS_MIN): $(MAK_DIR_shitWEB)shitWEB-BUILD-OPTIONS
$(MAK_DIR_shitWEB)$(shitWEB_JS_MIN): $(MAK_DIR_shitWEB)$(shitWEB_JS_IN)
	$(QUIET_GEN)$(JSMIN) <$< >$@
endif
shitWEB_FILES += $(shitWEB_JS)

shitWEB_CSS_MIN = static/shitweb.min.css
ifdef CSSMIN
shitWEB_CSS = $(shitWEB_CSS_MIN)
shitWEB_ALL += $(MAK_DIR_shitWEB)$(shitWEB_CSS_MIN)
$(MAK_DIR_shitWEB)$(shitWEB_CSS_MIN): $(MAK_DIR_shitWEB)shitWEB-BUILD-OPTIONS
$(MAK_DIR_shitWEB)$(shitWEB_CSS_MIN): $(MAK_DIR_shitWEB)$(shitWEB_CSS_IN)
	$(QUIET_GEN)$(CSSMIN) <$< >$@
endif
shitWEB_FILES += $(shitWEB_CSS)

shitWEB_FILES += static/shit-logo.png static/shit-favicon.png

# JavaScript files that are composed (concatenated) to form shitweb.js
#
# js/lib/common-lib.js should be always first, then js/lib/*.js,
# then the rest of files; js/shitweb.js should be last (if it exists)
shitWEB_JSLIB_FILES =
shitWEB_JSLIB_FILES += static/js/lib/common-lib.js
shitWEB_JSLIB_FILES += static/js/lib/datetime.js
shitWEB_JSLIB_FILES += static/js/lib/cookies.js
shitWEB_JSLIB_FILES += static/js/javascript-detection.js
shitWEB_JSLIB_FILES += static/js/adjust-timezone.js
shitWEB_JSLIB_FILES += static/js/blame_incremental.js


shitWEB_REPLACE = \
	-e 's|++shit_VERSION++|$(shit_VERSION)|g' \
	-e 's|++shit_BINDIR++|$(bindir)|g' \
	-e 's|++shitWEB_CONFIG++|$(shitWEB_CONFIG)|g' \
	-e 's|++shitWEB_CONFIG_SYSTEM++|$(shitWEB_CONFIG_SYSTEM)|g' \
	-e 's|++shitWEB_CONFIG_COMMON++|$(shitWEB_CONFIG_COMMON)|g' \
	-e 's|++shitWEB_HOME_LINK_STR++|$(shitWEB_HOME_LINK_STR)|g' \
	-e 's|++shitWEB_SITENAME++|$(shitWEB_SITENAME)|g' \
	-e 's|++shitWEB_PROJECTROOT++|$(shitWEB_PROJECTROOT)|g' \
	-e 's|"++shitWEB_PROJECT_MAXDEPTH++"|$(shitWEB_PROJECT_MAXDEPTH)|g' \
	-e 's|++shitWEB_EXPORT_OK++|$(shitWEB_EXPORT_OK)|g' \
	-e 's|++shitWEB_STRICT_EXPORT++|$(shitWEB_STRICT_EXPORT)|g' \
	-e 's|++shitWEB_BASE_URL++|$(shitWEB_BASE_URL)|g' \
	-e 's|++shitWEB_LIST++|$(shitWEB_LIST)|g' \
	-e 's|++shitWEB_HOMETEXT++|$(shitWEB_HOMETEXT)|g' \
	-e 's|++shitWEB_CSS++|$(shitWEB_CSS)|g' \
	-e 's|++shitWEB_LOGO++|$(shitWEB_LOGO)|g' \
	-e 's|++shitWEB_FAVICON++|$(shitWEB_FAVICON)|g' \
	-e 's|++shitWEB_JS++|$(shitWEB_JS)|g' \
	-e 's|++shitWEB_SITE_HTML_HEAD_STRING++|$(shitWEB_SITE_HTML_HEAD_STRING)|g' \
	-e 's|++shitWEB_SITE_HEADER++|$(shitWEB_SITE_HEADER)|g' \
	-e 's|++shitWEB_SITE_FOOTER++|$(shitWEB_SITE_FOOTER)|g' \
	-e 's|++HIGHLIGHT_BIN++|$(HIGHLIGHT_BIN)|g'

.PHONY: FORCE
$(MAK_DIR_shitWEB)shitWEB-BUILD-OPTIONS: FORCE
	@rm -f $@+
	@echo "x" '$(PERL_PATH_SQ)' $(shitWEB_REPLACE) "$(JSMIN)|$(CSSMIN)" >$@+
	@cmp -s $@+ $@ && rm -f $@+ || mv -f $@+ $@

$(MAK_DIR_shitWEB)shitweb.cgi: $(MAK_DIR_shitWEB)shitWEB-BUILD-OPTIONS
$(MAK_DIR_shitWEB)shitweb.cgi: $(MAK_DIR_shitWEB)shitweb.perl
	$(QUIET_GEN)$(RM) $@ $@+ && \
	sed -e '1s|#!.*perl|#!$(PERL_PATH_SQ)|' \
		$(shitWEB_REPLACE) $< >$@+ && \
	chmod +x $@+ && \
	mv $@+ $@

$(MAK_DIR_shitWEB)static/shitweb.js: $(addprefix $(MAK_DIR_shitWEB),$(shitWEB_JSLIB_FILES))
	$(QUIET_GEN)$(RM) $@ $@+ && \
	cat $^ >$@+ && \
	mv $@+ $@

### Installation rules

.PHONY: install-shitweb
install-shitweb: $(MAK_DIR_shitWEB_ALL)
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(shitwebdir_SQ)'
	$(INSTALL) -m 755 $(addprefix $(MAK_DIR_shitWEB),$(shitWEB_PROGRAMS)) '$(DESTDIR_SQ)$(shitwebdir_SQ)'
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(shitwebstaticdir_SQ)'
	$(INSTALL) -m 644 $(addprefix $(MAK_DIR_shitWEB),$(shitWEB_FILES)) \
		'$(DESTDIR_SQ)$(shitwebstaticdir_SQ)'
ifndef NO_shitWEB
ifndef NO_PERL
install: install-shitweb
endif
endif

### Cleaning rules

.PHONY: shitweb-clean
shitweb-clean:
	$(RM) $(addprefix $(MAK_DIR_shitWEB),shitweb.cgi $(shitWEB_JS_IN) \
		$(shitWEB_JS_MIN) $(shitWEB_CSS_MIN) \
		shitWEB-BUILD-OPTIONS)
clean: shitweb-clean
