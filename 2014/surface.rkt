#lang racket/base

#|

|#

(require (relative-in 
          magnolisp
          "core.rkt" "util.rkt"
          racket/stxparam
          (for-syntax "app-util.rkt" "util.rkt"
                      racket/base racket/syntax syntax/parse)))

;; Function type expression.
(define-syntax-rule* (fn at ... rt)
  (CORE 'fn at ... rt))

;; Type annotation.
(define-syntax-rule* (type t)
  (CORE 'anno 'type t))

(define-syntax* (export stx)
  (syntax-parse stx
    [_:id
     #'(CORE 'anno 'export #t)]
    [(_ name:id)
     #'(CORE 'anno 'export #'name)]))

(define-syntax* (foreign stx)
  (syntax-parse stx
    [_:id
     #'(CORE 'anno 'foreign #t)]
    [(_ name:id)
     #'(CORE 'anno 'foreign #'name)]))

(define-syntax* (build stx)
  (syntax-case stx ()
    [(_ x ...)
     #`(CORE 'anno 'build (quote-syntax #,stx))]))

(define-syntax* (expected stx)
  (syntax-case stx ()
    [(_ x ...)
     #'(CORE 'anno 'expected (quote-syntax (x ...)))]))

(define-syntax* (let-annotate stx)
  (syntax-case stx ()
    [(_ (a ...) e)
     (syntax-property 
      (syntax/loc stx
        (let-values ([() (begin a (values))] ...) e))
      'annotate #t)]))

;; A form that annotates not an identifier, but any expression. The
;; annotations are stored as expressions in a `let` wrapper.
(define-syntax-rule*
  (anno a ... e)
  (let-annotate (a ...) e))

(define-for-syntax (decl-for-id id)
  (with-syntax ([impl-id (format-id id "~a-impl" (syntax-e id))]
                [id id])
    #'(define-syntax* id
        (syntax-rules ()
          [(_ n (#:annos a (... ...)) b (... ...))
           (impl-id n (a (... ...)) b (... ...))]
          [(_ n b (... ...))
           (impl-id n () b (... ...))]))))

;; For each passed ID, defines syntax with an optional #:annos
;; specifier. Each ID must have an -impl binding, which expects a
;; compulsory annotation listing at the same position.
(define-syntax* (define-annos-wrapper* stx)
  (syntax-case stx ()
    [(_ ids ...)
     (let ()
       (define id-lst (syntax->list #'(ids ...)))
       #`(begin #,@(map decl-for-id id-lst)))]))

(define-syntax function-impl
  (syntax-rules ()
    [(_ (f p ...) (a ...))
     (function-impl (f p ...) (a ...) (void))]
    [(_ (f p ...) (a ...) b ...)
     (define f 
       (let-annotate (a ...)
         (#%plain-lambda (p ...) b ...)))]))
    
(define-annos-wrapper* function)

(define-syntax var-impl
  (syntax-rules ()
    [(_ n (a ...) v)
     (define n
       (let-annotate (a ...)
         v))]))

(define-annos-wrapper* var)

(define-syntax-rule
  (let-var-impl n (a ...) v b ...)
  (let ([n (let-annotate (a ...) v)])
    b ...))

(define-annos-wrapper* let-var)

(define-syntax-rule*
  (cast t d)
  (let-annotate ([type t]) d))

(define-syntax-rule (typedef-impl t (a ...))
  (define t 
    (let-annotate (a ...)
      (CORE 'foreign-type))))

(define-annos-wrapper* typedef)

(define-syntax* (begin-racket stx)
  (syntax-case stx ()
    [(_ e ...)
     (syntax-property
      (syntax/loc stx (let () e ...))
      'for-target 'racket)]))

(define-syntax* (begin-for-racket stx)
  (syntax-case stx ()
    [(_ e ...)
     (syntax-property
      (syntax/loc stx (begin e ...))
      'for-target 'racket)]))

(define-syntax-rule*
  (define-for-racket rest ...)
  (begin-for-racket (define rest ...)))
