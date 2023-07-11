
(define (repl)
  (+ 1 2))

(define (f0 a)
  (* a a))

(define (f1 a b c)
  (if (= c 0)
      b 
      a))

;(define (f0 count)
;  (f1 1 0 count))
;
;(define (f1 a b count)
;  (if (= count 0)
;       b
;      (f1 (+ a b) a (- count 1))))
;
;(define (f0 a b count)
;  (if (= count 0)
;      b
;      (f0 (+ a b) b (- count 1))))
