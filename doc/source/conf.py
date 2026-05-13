# -*- coding: utf-8 -*-
#
# dasImgui documentation build configuration file.
#
# Vendored from daslang/doc/source/conf.py — LaTeX/rinohtype/manpage/texinfo
# build paths trimmed (HTML-only deploy for v1). Diff and reconcile annually
# against daslang upstream when the daslang Sphinx domain evolves.

import sys
import os
import time

# Make the vendored `daslang` Sphinx domain importable.
sys.path.insert(0, os.path.abspath('.'))

extensions = ['daslang', 'sphinx.ext.intersphinx']

# Resolve cross-refs to daslang core (JsonValue, ImGuiCol, etc.) against the
# published daslang documentation. Sphinx fetches objects.inv at build time.
intersphinx_mapping = {
    'daslang': ('https://daslang.io/doc/', None),
}
intersphinx_disabled_reftypes = []

templates_path = ['_templates']

suppress_warnings = ['toctree.not_included']

source_suffix = '.rst'

master_doc = 'index'

project = u'dasImgui documentation'
copyright = '2026-%s, Gaijin Entertainment' % time.strftime('%Y')
author = u'Boris Batkin'

version = u'2.0'
release = u'2.0'

language = 'en'

# Intermediate files used by imgui2rst — not standalone documentation pages.
exclude_patterns = ['stdlib/generated/detail', 'stdlib/handmade']

pygments_style = 'sphinx'
highlight_language = 'none'

todo_include_todos = False

# -- Options for HTML output ----------------------------------------------

html_theme = 'sphinx_rtd_theme'
html_static_path = []

htmlhelp_basename = 'dasimgui_doc'
