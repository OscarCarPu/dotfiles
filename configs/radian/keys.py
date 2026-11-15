from prompt_toolkit.filters import emacs_insert_mode, vi_insert_mode
from prompt_toolkit.key_binding.bindings.named_commands import get_by_name
from radian import get_app
from radian.settings import radian_settings

insert = emacs_insert_mode | vi_insert_mode

for mode in ("r", "browse"):
    kb = get_app().session.modes[mode].prompt_key_bindings
    # kitty sends Shift+Enter as \e[24;2~, which prompt_toolkit reads as F24
    kb.add("f24", filter=insert)(get_by_name("menu-complete"))

    @kb.add("c-i", filter=insert)
    def _(event):
        event.current_buffer.insert_text(" " * radian_settings.tab_size)
