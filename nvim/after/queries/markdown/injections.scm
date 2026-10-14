;; extends

; pandoc raw Typst blocks: ```{=typst}
((fenced_code_block
  (info_string) @_info
  (code_fence_content) @injection.content)
  (#eq? @_info "{=typst}")
  (#set! injection.language "typst"))
