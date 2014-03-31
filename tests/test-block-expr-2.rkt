#lang magnolisp

(typedef int (#:annos foreign))

(function (equal x y)
  (#:annos (type (fn int int predicate)) foreign)
  (begin-racket (equal? x y)))

(function (default e f d) #an(export)
  (do
    (if (equal e f)
        (return d)
        (return e))))

(function (f x)
  (#:annos export)
  (do
    (var y (default x 2 7))
    (return (default x 1 7))))

(f 1)
(f 2)