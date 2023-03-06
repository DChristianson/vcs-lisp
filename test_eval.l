; expressions for testing function evaluations

(define (f0)
 (+ 1 2))
 
(define (f0)
  (+ (+ (+ (+ 1 2 1 2 1) (+ 2 1 2 1) (+ 1 2 1) (+ 2 1)))))

(define (f1)
 (+ 1 (+ 1 (+ (+ 2 2) (+ 2 1)))))

(define (f1)
 (/ (+ 1 2) 2))

(define (f2)
  (* 2 (+ 1 2)))

(define (f0 a0)
 (* a0 a0))

(define (f0)
 (f0 2))

(define (fib-iter a b count)
  (if (= count 0)
       b
      (fib-iter (+ a b) a (- count 1))))

(define (f0)
  (f0 1 0 (+ 1 2)))

(define (cube5 x)
 (* x x x x x))

(define (cube10 x)
 (* x x x x x x x x x x))

(define (cube31 x)
 (* x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x x))
