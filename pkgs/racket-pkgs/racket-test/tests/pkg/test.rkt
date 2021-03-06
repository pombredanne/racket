#lang racket/base
(require (for-syntax racket/base
                     "util.rkt")
         "shelly.rkt"
         "util.rkt"
         racket/port
         (only-in pkg pkg-config-command))

;; By making these syntax-time includes, it made it so they would be
;; rebuilt and register as real dependencies.
(define-syntax (run-tests stx)
  (syntax-case stx ()
    [(_ f ...)
     (with-syntax
         ([(tests-f ...)
           (for/list ([f-stx (in-list (syntax->list #'(f ...)))])
             (define f (syntax->datum f-stx))
             `(file ,(format "tests-~a.rkt" f)))])
       (syntax/loc stx
         (run-tests*
          (list (let ()
                  (local-require (only-in tests-f run-pkg-tests))
                  (λ ()
                    (printf "starting ~a\n" 'tests-f)
                    (run-pkg-tests)))
                ...))))]))

(define (run-tests* l)
  (run-pkg-tests*
   (λ ()
     (shelly-case "All tests"
                  (for-each (λ (x) (x)) l)))))

(run-tests
 "name"
 "basic" "create" "install" "permissions"
 "conflicts" "checksums"
 "deps" "update"
 "remove"
 "promote"
 "locking"
 "overwrite"
 "config"

 "network"
 "planet"
 "main-server"

 "update-deps"
 "update-auto"
 "scope"
 "migrate"
 "versions"
 "platform"
 "raco"
 "binary"
 "catalogs"
 "failure")
