#lang racket

#|

The definitions in this module are mostly exported for-syntax, as the
information is only accessed at macro expansion time.

Note quite sure if we should specify any #:phase for the identifier
tables, but phase 0 would seem appropriate as all Magnolisp names are
such.

We use a bound id-table as whenever we are adding a metadata record it
is for a freshly bound definition - we never add a new metadata record
for the same identifier.

As we parse metadata, raise-syntax-error and raise-type-error may be
useful.

|#

(require "annos.rkt" "util.rkt")

(begin-for-syntax

 (require "metadata-defs.rkt" "util.rkt")
 (require racket/match syntax/id-table)

 ;; DEPRECATED
 (define* type-table (make-bound-id-table #:phase 0))
 
 ;; DEPRECATED
 (define* (record-type! id-stx t)
   (bound-id-table-set! type-table id-stx t))

 (define* definfo-table (make-bound-id-table #:phase 0))
 
 (define* (record-definfo! id-stx info)
   (bound-id-table-set! definfo-table id-stx info))

 (define (raise-anno-syntax-error def-n anno-n v-stx v [expect-s #f])
   (raise-syntax-error def-n
     (format "~a: expected ~a, got ~s" 
	     anno-n 
	     (or expect-s "legal syntax")
	     v) v-stx))

 (define (anno->datum def-n h n default pred? expect-s)
   (define v-stx (hash-ref h n #f))
   (define v default)
   (when v-stx
     (set! v (syntax->datum v-stx))
     (unless (pred? v)
       (raise-anno-syntax-error def-n n v-stx v expect-s)))
   v)

 (define-syntax-rule (matches? e pat)
   (match e (pat #t) (_ #f)))

 ;; Creates a DefInfo record by parsing any annotations in syntax
 ;; properties. Missing information is given the default value,
 ;; typically #f. Unrecognized annotations are ignored, although we
 ;; could consider storing them in the DefInfo as they are.
 (define* (parse-definfo id-stx def-stx)
   ;; Original, symbolic name. Possibly we will have to rename at some
   ;; point, but might be able to restore the original name in some
   ;; cases, or just use it for error reporting.
   (unless (identifier? id-stx)
     (raise-syntax-error #f "definition must be named by an identifier"
			 def-stx id-stx))
   (define name (syntax->datum id-stx))

   (define h (get-annos def-stx))

   (define external?
     (anno->datum name h 'external #f boolean? "boolean literal"))
   (define verbatim?
     (anno->datum name h 'verbatim #f boolean? "boolean literal"))
   (define defined-as
     (cond
      ((and external? verbatim?)
       (raise-syntax-error name "declared as both external and verbatim"))
      (external?
       'external)
      (verbatim?
       'verbatim)
      (else #f)))

   ;;xxx type - expect sexp conforming to a grammar
   (define type #f)

   ;; For the documentation, the user might want to install the
   ;; Scribble reader. But at this point the reading has already been
   ;; done. Scribble may not be very useful, however, unless we
   ;; evaluate the syntax as an expression. Most likely we want to do
   ;; that in the top-level module context, and naturally with
   ;; expansion time bindings. eval-syntax uses (current-namespace) by
   ;; default, and namespaces are always top-level, so the default
   ;; should be suitable.
   (define doc (hash-ref h 'doc #f))
   (when doc
     (define doc-stx doc)
     (set! doc (eval-syntax doc-stx))
     (unless (string? doc)
       (raise-anno-syntax-error name 'doc doc-stx doc
				"a string expression")))
   
   (define emacs-indent
     (anno->datum name h 'indent #f 
		  (lambda (x)
		    (or (integer? x) (symbol? x)))
		  "integer or symbol literal"))

   ;; #^highlight ;; just the name, as a keyword
   ;; #^(highlight (if then else)) ;; multiple keywords
   ;; #^(highlight ((if keyword) (then keyword) (else keyword)))
   (define emacs-highlight
     (if-not-let stx (hash-ref h 'highlight #f)
       '()
       (let ((v (syntax->datum stx)))
	 (cond
	  ((boolean? v)
	   (if (not v)
	       '()
	       `((,name keyword))))
	  ((list? v)
	   (map
	    (lambda (x)
	      (cond
	       ((symbol? x)
		(list x 'keyword))
	       ((matches? x (list (? symbol?) (? symbol?)))
		x)
	       (else
		(raise-anno-syntax-error 
		 name 'highlight stx v))))
	    v))
	  (else
	   (raise-anno-syntax-error name 'highlight stx v
				    "a literal boolean or list"))))))

   ;; #^dictionary ;; just the name
   ;; #^(dictionary (if then else))
   ;; #^(dictionary ((if "if <e> then <e> else <e>") then else)
   (define emacs-dictionary
     (if-not-let stx (hash-ref h 'dictionary #f)
       '()
       (let ((v (syntax->datum stx)))
	 (cond
	  ((boolean? v)
	   (if (not v)
	       '()
	       `((,name #f))))
	  ((list? v)
	   (map
	    (lambda (x)
	      (cond
	       ((symbol? x)
		(list x #f))
	       ((matches? x (list (? symbol?) (? string?)))
		x)
	       (else
		(raise-anno-syntax-error 
		 name 'dictionary stx v))))
	    v))
	  (else
	   (raise-anno-syntax-error name 'dictionary stx v
				    "a literal boolean or list"))))))

   (DefInfo name type defined-as doc 
     emacs-indent emacs-highlight emacs-dictionary))

 ) ; end begin-for-syntax

;; DEPRECATED
(define-syntax* (begin/save-type stx)
  (syntax-case stx ()
    [(_ n t)
     (record-type! #'n (TypeName (syntax->datum #'t)))
     #'(begin)]
    [(_ n)
     (record-type! #'n AnyT)
     #'(begin)]
    ))