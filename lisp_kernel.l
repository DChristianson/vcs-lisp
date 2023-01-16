(define (square x)
 (* x x))

(define (average x y)
  (/ (+ x y) 2))

(define (improve guess x)
        (average guess (/ x guess)))

(define (good-enough? guess x)
        (< (abs (- (square guess) x)) 0.001))
(define (fib-iter a b count)
  (if (= count 0)
       b
      (fib-iter (+ a b) a (- count 1))))

(define (fact-iter product counter max-count)
        (if (> counter max-count)
            product
            (fact-iter (* counter product)
                       (+ counter 1)
                        max-count)))

(define (sqrt x)
    (sqrt-iter 1.0 x))

(define (factorial n)
        (fact-iter 1 1 n))

(define (fact-iter product counter max-count)
        (if (> counter max-count)
            product
            (fact-iter (* counter product)
                       (+ counter 1)
                        max-count)))

