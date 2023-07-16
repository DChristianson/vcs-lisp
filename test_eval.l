; expressions for testing function evaluations

(define (f0)
 (+ 1 2))
 
(define (f0)
  (+ 
    (+ 
      (+ 
        (+ 2 1 2 1) 
        (+ 1 2 1) 
        (+ 2 1) 
        (+ 1)
      )
      1
    )
  )
)

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

; ulisp takeuchi function
(defun tak (x y z)
  (if (not (< y x))
    z
    (tak
     (tak (1- x) y z)
     (tak (1- y) z x)
     (tak (1- z) x y))))

; ulisp hofstaeder q sequence
(defun q (n)
  (if (<= n 2) 1
    (+
     (q (- n (q (- n 1))))
     (q (- n (q (- n 2)))))))

; ulisp least prime factor
(defun factor (n)
  (let ((d 2) (i 1))
    (loop
     (when (> (* d d) n) (return n))
     (when (zerop (mod n d)) (return d))
     (incf d i) (setq i 2))))

; ulisp factors
(defun factorize (n)
  (let ((f (factor n)))
    (if (= n f) (list n) (cons f (factorize (/ n f))))))

; ulisp bullcow
(defun bullcow (digits guess code)
  (let ((score 0))
    (dotimes (i 16) (setf (nth i *spectrum*) 0))
    (dotimes (d digits)
      (let ((da (mod guess 16))
            (db (mod code 16)))
        (cond
         ((= da db) (incf score 16))
         (t 
          (when (<= (incf (nth da *spectrum*)) 0) (incf score))
          (when (>= (decf (nth db *spectrum*)) 0) (incf score))))
        (setq guess (truncate guess 16))
        (setq code (truncate code 16))))
    score))