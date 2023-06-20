
(define (repl)
 (f0 2))

(define (f0 count)
  (f1 1 0 count))

(define (f1 a b count)
  (if (= count 0)
       b
      (f1 (+ a b) a (- count 1))))
