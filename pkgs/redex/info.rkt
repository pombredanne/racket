#lang setup/infotab

(define single-collection "redex")

(define name "PLT Redex")
(define scribblings (list (list "redex.scrbl" (list 'multi-page) (list 'tool))))
(define release-notes (list (list "Redex" "HISTORY.txt")))

(define compile-omit-paths '("tests"))