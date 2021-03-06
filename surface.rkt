#lang racket/base

#|

This module implements the (default) syntactic forms of the Magnolisp
language.

|#

(require "core.rkt" "util.rkt"
         racket/stxparam
         (for-syntax "app-util.rkt" "util.rkt"
                     racket/base racket/syntax 
                     syntax/parse))

(begin-for-syntax
  (define (set-loc from stx)
    (datum->syntax stx (syntax-e stx) from stx stx))
  (define-syntax-rule
    (syntax-parse/loc stx . rest)
    (set-loc stx (syntax-parse stx . rest))))
    
;; Aliases.
(provide (rename-out [exists ∃] [for-all ∀]))

;; Function type expression.
(define-syntax-rule* (-> at ... rt)
  (CORE 'fn at ... rt))

;; ∃t,... u type expression, where `t` are type parameter names, and
;; `u` is a type expression.
(define-syntax-rule* (exists t ... u)
  (CORE 'exists (let ((t #f) ...) u)))

;; ∀t,... u type expression, where `t` are type parameter names, and
;; `u` is a type expression.
(define-syntax-rule* (for-all t ... u)
  (CORE 'for-all (let ((t #f) ...) u)))

;; `t` is a type name, and each `u` is a parameter type expression.
(define-syntax-rule* (<> t u ...)
  (CORE 'parameterized t u ...))

;; Inferred type.
(define-syntax-rule* (auto)
  (CORE 'auto))

;; Type annotation.
(define-syntax-rule* (type t)
  (CORE 'anno 'type t))

(define-syntax* (export stx)
  (syntax-parse/loc stx
    [_:id
     #'(CORE 'anno 'export #t)]
    [(_ name:id)
     #'(CORE 'anno 'export #'name)]))

(define-syntax* (foreign stx)
  (syntax-parse/loc stx
    [_:id
     #'(CORE 'anno 'foreign #t)]
    [(_ name:id)
     #'(CORE 'anno 'foreign #'name)]))

(define-syntax* (literal stx)
  (syntax-case stx ()
    [(_ ...)
     (quasisyntax/loc stx
       (CORE 'anno 'literal (quote-syntax #,stx)))]))

(define-syntax* (build stx)
  (syntax-case stx ()
    [(_ ...)
     (quasisyntax/loc stx
       (CORE 'anno 'build (quote-syntax #,stx)))]))

(define-syntax* (expected stx)
  (syntax-case stx ()
    [(_ x ...)
     (syntax/loc stx
       (CORE 'anno 'expected (quote-syntax (x ...))))]))

;; A form that annotates not an identifier, but any expression.
(define-syntax* (annotate stx)
  (syntax-case stx ()
    [(_ () e)
     #'e]
    [(_ (a ...) e)
     (syntax-property 
      (syntax/loc stx
        (let-values ([() (begin a (values))] ...) e))
      'annotate #t)]))

;; DEPRECATED
(provide (rename-out [annotate let-annotate]))

(define-syntax-rule*
  (cast t d)
  (annotate ([type t]) d))

(begin-for-syntax
  (define-splicing-syntax-class maybe-annos
    #:description "annotations for a definition"
    #:attributes (bs)
    (pattern
     (~optional
      (~seq #:: (~and (a:expr ...) as)))
     #:attr bs (if (attribute as) #'as #'()))))

(define-syntax-rule* (foreign-type)
  (CORE 'foreign-type))

(provide (rename-out [my-define define]))

(define-syntax (my-define stx)
  (syntax-parse/loc stx
    [(_ n:id as:maybe-annos v:expr)
     #'(define n
         (annotate as.bs 
             v))]
    [(_ (f:id p:id ...) as:maybe-annos)
     #'(define f
         (annotate as.bs
             (#%plain-lambda (p ...) (void))))]
    [(_ (f:id p:id ...) as:maybe-annos b:expr ...+)
     #'(define f
         (annotate as.bs 
             (#%plain-lambda (p ...) b ...)))]
    [(_ #:type t:id as:maybe-annos)
     #'(define t 
         (annotate as.bs 
             (foreign-type)))]
    [(_ (f:id p:id ...) as:maybe-annos #:function f-e:expr)
     (with-syntax ([f-arity-t
                    #`(-> #,@(map 
                              (lambda _ #'(auto)) 
                              (syntax->list #'(p ...)))
                          (auto))])
       #'(define f
           (annotate ([type f-arity-t])
             (annotate as.bs ;; any `type` here overrides above
                 (begin-racket f-e)))))]))

;; DEPRECATED
(define-syntax* (function stx)
  (syntax-parse/loc stx
    [(_ (f:id p:id ...) as:maybe-annos)
     #'(define f
         (annotate as.bs
             (#%plain-lambda (p ...) (void))))]
    [(_ (f:id p:id ...) as:maybe-annos b:expr ...+)
     #'(define f
         (annotate as.bs 
             (#%plain-lambda (p ...) b ...)))]))

;; DEPRECATED
(define-syntax* (var stx)
  (syntax-parse/loc stx
    [(_ n:id as:maybe-annos v:expr)
     #'(define n
         (annotate as.bs 
             v))]))

(define-syntax* (typedef stx)
  (syntax-parse/loc stx
    [(_ t:id as:maybe-annos)
     #'(define t 
         (annotate as.bs 
             (foreign-type)))]
    [(_ t:id texpr:expr)
     #'(define-syntax (t x)
         (syntax-parse x
           [_:id #'texpr]))]))

(define-syntax* (declare stx)
  (syntax-parse/loc stx
    [(_ n:id e:expr)
     #'(define-values ()
         (begin
           (CORE 'declare n e)
           (values)))]
    [(_ (f:id p:id ...) as:maybe-annos)
     #'(declare f
         (annotate as.bs
             (#%plain-lambda (p ...) (void))))]
    [(_ #:type t:id as:maybe-annos)
     #'(declare t 
         (annotate as.bs 
             (foreign-type)))]))

(define-syntax* (if-target stx)
  (syntax-parse stx
    [(_ name:id t:expr e:expr)
     (syntax-property 
      (syntax/loc stx (if #f t e))
      'if-target (syntax-e #'name))]))

(define-syntax-rule* (if-cxx t e)
  (if-target cxx t e))

(define-syntax (flag-as-for-racket stx)
  (syntax-parse stx
    [(_ form)
     (syntax-property #'form 'for-target 'racket)]))

(define-syntax-rule* (begin-racket form ...)
  (flag-as-for-racket (begin form ...)))

(define-syntax-rule* (let-racket e ...)
  (flag-as-for-racket (let () e ...)))

(define-syntax* (let-racket/require stx)
  (define-syntax-class sym-spec
    #:description "import spec for `let-racket/require`"
    #:attributes (spec)
    (pattern
     (sym:id ...)
     #:attr spec (with-syntax ((rb (datum->syntax stx 'racket/base)))
                   #'(only-in rb sym ...)))
    (pattern
     (sym:id ... #:from mp:expr)
     #:attr spec #'(only-in mp sym ...)))
  
  (syntax-parse/loc stx
    ((_ (req:sym-spec ...) e:expr ...+)
     #'(let-racket
        (local-require req.spec ...)
        e ...))))

(define-syntax* primitives
  (syntax-rules (::)
    [(_) (begin)]
    [(_ [#:type t] . more)
     (begin 
       (typedef t #:: (foreign))
       (primitives . more))]
    [(_ [#:function form :: t] . more)
     (begin 
       (my-define form #:: ([type t] foreign))
       (primitives . more))]))
