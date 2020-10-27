# Idris syntax highlighting and repl integration for kakoune (see www.idris-lang.org).
# 
# Based on https://github.com/idris-hackers/idris-vim/blob/master/ftplugin/idris.vim
# and https://github.com/mawww/kakoune/blob/master/rc/filetype/haskell.kak. The goal
# is to achieve functionality on par with idris.vim as described in 
# https://edwinb.wordpress.com/2013/10/28/interactive-idris-editing-with-vim/.


# Detection
# ---------

hook global BufCreate .*\.idr %{
    set-option buffer filetype idris
}

# we attempt to support both normal and literate idris in this module

hook global BufCreate .*\.lidr %{
    set-option buffer filetype literate-idris
}

hook global BufCreate .*\.l?idr %{
    set-option buffer indentwidth 2
    set-option buffer ignored_files .*\.ibc
}

# Initialization
# --------------

hook global WinSetOption filetype=(literate-)?idris %<
    require-module idris

    set-option buffer extra_word_chars '_' "'"
    hook window ModeChange pop:insert:.* -group idris-trim-indent idris-trim-indent
    hook window InsertChar \n            -group idris-indent idris-indent-on-new-line

    hook -once -always window WinSetOption filetype=.* %< remove-hooks window idris-.+ >
>

hook -group idris-highlight global WinSetOption filetype=(literate-)?idris %{
    require-module idris
    add-highlighter window/idris ref idris
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/idris }
}

provide-module idris %§

# Highlighter
# -----------

# TMP syntax reference
#  
#  add-highlighter <path>/<name> <type> <parameters> ...
#  add-highlighter <path>/<name> region <opening> <closing> <type>
#  add-highlighter <path>/<name> group
#
# value, type, variable, module, function, string, keyword, operator, attribute, comment, documentation, meta, builtin

add-highlighter shared/idris regions
add-highlighter shared/idris/code default-region group

add-highlighter shared/idris/string region '"' '"' fill string
add-highlighter shared/idris/multi-line-string region '"""' '"""' fill string

add-highlighter shared/idris/comment region -- '$' fill comment
add-highlighter shared/idris/mutli-line-comment region -recurse \{- \{- -\} fill comment

add-highlighter shared/idris/docstring region \|\|\| '$' fill documentation

add-highlighter shared/idris/code/ regex \b(0[xX][A-Fa-f0-9]+)\b 0:value
add-highlighter shared/idris/code/ regex \b(0[oO][0-7]+)\b 0:value
add-highlighter shared/idris/code/ regex \b\d+(\.\d+)?([eE][-+][0-9]+)? 0:value
add-highlighter shared/idris/code/ regex "'(.|\\u[0-9a-fA-F]{4})'" 0:value

add-highlighter shared/idris/code/ regex \b(module|namespace)\b 0:module
add-highlighter shared/idris/code/ regex \b(import|data|codata|record|dsl|interface|implementation|where|public|abstract|private|export|parameters|mutual|postulate|using|do|case|of|rewrite|with|proof|let|in|if|then|else|tactic|prefix|infix|infix[rl])\b 0:keyword
add-highlighter shared/idris/code/ regex ([-!#$%&\*\+./<=>\?@\\^|~:]|_)+ 0:operator
add-highlighter shared/idris/code/ regex \b([A-Z][A-Za-z0-9_']*)\b 0:type
add-highlighter shared/idris/code/ regex \b((pattern|term)\h+syntax)\b 0:keyword
add-highlighter shared/idris/code/ regex \b(import)\b[^\n]+\b(as)\b 2:keyword
add-highlighter shared/idris/code/ regex \b(total|partial|covering|implicit|refl|auto|impossible|static|constructor|)\b 0:attribute
add-highlighter shared/idris/code/ regex \b(lambda|variable|index_first|index_next)\b 0:attribute # TODO: Only highlight these inside DSL blocks
add-highlighter shared/idris/code/directive regex (%(access|assert_total|default|elim|error_reverse|hide|name|reflection|error_handlers|language|flag|dynamic|provide|inline|used|no_implicit|hint|extern|unqualified|error_handler)) 0:meta

# these are deprecated keywords, mark them as such
add-highlighter shared/idris/code/ regex \b(class|instance)\b 0:Error

# Commands
# --------

define-command -hidden idris-trim-indent %{
    # remove trailing white spaces
    try %{ execute-keys -draft -itersel <a-x> s \h+$ <ret> d }
}

define-command -hidden idris-indent-on-new-line %{
    evaluate-commands -draft -itersel %{
        # TODO
    }
}

# REPL Integration
# ----------------

# --- Options ----

declare-option -docstring "Command used to invoke idris in a shell" \
    str idris_cmd "idris"

# --- Commands ---

define-command -docstring "Writes and reloads the current file in buffer" \
    idris-reload \
%{
    write
    evaluate-commands %sh{
        out=$("$kak_opt_idris_cmd" --client ":load $kak_buffile")
        if [ -n "$out" ]; then
            echo "info -title 'idris error' %[$out]"
        else
            echo "info \"Successfully reloaded $(basename ""$kak_buffile"")\""
        fi
    }
}

define-command -docstring "Open an Idris REPL" idris-repl %{
    repl %opt{idris_cmd}
}

define-command idris-show-type %{
            idris-reload-quiet
    idris-wrap-selection %< idris-select-var >
    idris-info-output ":type"
}

define-command idris-show-doc %{
    idris-reload-quiet
    idris-wrap-selection %< idris-select-var >
    idris-info-output ":doc"
}

define-command idris-eval-prompt %{
    idris-reload-quiet
    prompt "Expression: " \
        %< echo %sh{ "$kak_opt_idris_cmd" --client "$kak_text" } >
}

define-command idris-add-clause %{
    idris-wrap-selection %< idris-select-def-name >
    idris-exec-completion ":addclause!"
}

define-command idris-make-lemma %{
    idris-wrap-selection %< idris-select-hole >
    idris-exec-completion ":makelemma!"
}

define-command idris-proof-search %{
    idris-wrap-selection %< idris-select-hole >
    idris-exec-completion ":proofsearch!"
}

define-command idris-proof-search-given-hints %{
    idris-wrap-selection %< idris-select-hole >
    prompt "Hints (functions): " %{
        idris-exec-completion ":proofsearch!" %val{text} 
    }
}

define-command idris-case-split %{
    idris-wrap-selection %< idris-select-var >
    idris-exec-completion ":casesplit!"
}

define-command idris-make-case %{
    idris-wrap-selection %< idris-select-hole >
    idris-exec-completion ":makecase!"
}

define-command idris-make-with %{
    idris-wrap-selection %< idris-select-var >
    idris-exec-completion ":makewith!"
}

define-command idris-add-missing %{
    idris-wrap-selection %< idris-select-var >
    idris-exec-completion ":addmissing!"
}

# --- Helpers ----

# Saves the selection after evaluatin %opt{@} to "i, then
# restores the main selection back to its initial state
define-command -hidden -params 1 idris-wrap-selection %{
    execute-keys '"uZ'
    set-register i ""
    evaluate-commands %arg{@}
    execute-keys '"iy'
    execute-keys '"uz'
    echo
}

define-command -hidden -params 1..2 idris-exec-completion %{
    idris-reload
    evaluate-commands %sh{
        cmd="$kak_opt_idris_cmd --client \"$1 $kak_cursor_line $kak_reg_i $2\""
        echo "idris-debug %[idris-exec-completion] %[$cmd]"
        out=$(eval $cmd)
        echo "idris-debug %[idris-exec-completion out] %[$out]"
    }
}

define-command -hidden idris-reload-quiet %{
    write ; nop %sh{ $kak_opt_idris_cmd --client ":l $kak_buffile" }
}

# this passes only the the command and the "i selection to idris
define-command -hidden -params 1 idris-info-output %{
    idris-reload-quiet
    evaluate-commands %sh{
        cmd="$kak_opt_idris_cmd --client \"$1 $kak_reg_i\""
        echo "idris-debug %[idris-info-output] %[$cmd]"
        out=$(eval $cmd)
        echo "idris-debug %[idris-info-output out] %[$out]"
        # TODO: idris-show-type may output - at the start of a line this
        # -markup {\} combination bypasses that, but it is just a hack...
        echo "info -markup %[{\}$out]"
    }
}

# - "Selectors" --

define-command -hidden idris-select-def-name %{
    try %{
        # the select ('s') can fail
        execute-keys "<a-x>s[a-z][\w']*\h+:(?!:)<ret><a-:><a-;>e"
    } catch %{
        fail "No definition on current line: %val{error}"
    }
}

define-command -hidden idris-select-hole %{
    try %{ # first try to reduce current selection to a hole
        execute-keys 's\?\w<ret><a-i><a-w><a-:>be'
    } catch %{ # if we reach here there's no hole in the
        try %{ # selection so we check the current line
            execute-keys '<a-x>s\?\w<ret><a-i><a-w><a-:>be'
        } catch %{
            fail "No hole on current line"
        }
    }
}

define-command -hidden idris-select-var %{
    try %{ # just keep the current selection for now...
        execute-keys "<a-a>w"
    }
}

# ---- Debug ----

declare-option -hidden bool idris_debug no

define-command -hidden -params 2 idris-debug %{
    evaluate-commands %sh{
        if [ "$kak_opt_idris_debug" = "true" ]; then
            echo "echo -debug %[$1: $2]"
        fi
    }
}

# Idris User Mode
# ---------------

declare-user-mode idris

map global user i ': enter-user-mode<space>idris<ret>' \
    -docstring "Enter Idris user-mode"
map global idris r ': idris-reload<ret>' \
    -docstring "Reloads and type-checks the file in the current buffer"
map global idris R ': idris-repl<ret>' \
    -docstring "Opens an Idris REPL"
map global idris t ': idris-show-type<ret>' \
    -docstring "Reloads and echoes type of the selection"
map global idris d ': idris-show-doc<ret>' \
    -docstring "Shows documentation for the selection"
map global idris c ': idris-case-split<ret>' \
    -docstring "Splits the variable into all well-typed patterns"
map global idris a ': idris-add-clause<ret>' \
    -docstring "Adds new clause for the type declaration"
map global idris l ': idris-make-lemma<ret>' \
    -docstring "Creates a new top-level definition for the hole"
map global idris s ': idris-proof-search<ret>' \
    -docstring "Searches for a solution to the hole"
map global idris <a-s> ': idris-proof-search-given-hints<ret>' \
    -docstring "Searches for a solution to the hole given hints"
map global idris m ': idris-add-missing<ret>' \
    -docstring "Adds the functions missing clauses to cover all inputs"
map global idris <a-m> ': idris-make-case<ret>' \
    -docstring "Makes a new case-expression for the hole"
map global idris w ': idris-make-with<ret>' \
    -docstring "Adds a with rule to the pattern clause"
map global idris e ': idris-eval-prompt<ret>' \
    -docstring "Prompts for and evaluates an expression in the REPL"

§
