#lang racket

#|
|#

(require "module.rkt")

(define-syntax* if-let
  (syntax-rules ()
    ((_ n c t e)
     (let ((n c))
       (if n t e)))))

(define-syntax* if-not-let
  (syntax-rules ()
    ((_ n c t e)
     (let ((n c))
       (if (not n) t e)))))

(define-syntax* when-let
  (syntax-rules ()
    ((_ n c e ...)
     (let ((n c))
       (when n
         e ...)))))

(define-syntax* let-and
  (syntax-rules ()
    ((_ e) e)
    ((_ n v more ...)
     (let ((n v))
       (and n (let-and more ...))))))

#|

Copyright 2006 Helsinki Institute for Information Technology (HIIT)
and the authors. All rights reserved.

Authors: Tero Hasu <tero.hasu@hut.fi>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

|#