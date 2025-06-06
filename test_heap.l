
(define (repl)
  (+ 1 2))

(define (f0 a)
  (* a a))

(define (f1 count)
   (f2 1 0 count))

(define (f2 a b count)
  (if (= count 0)
       b
      (f2 (+ a b) a (- count 1))))

(car (cdr (cons 1 (cons 2))))

(car (cdr '(1 2)))

(apply
  (quote + a 1)
  2)

(define (f a)
   (if a
      (progn (beep (car a) 5)
             (f (cdr a)))))
      

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
