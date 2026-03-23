(in-package #:example)

;;; * Initial

(defclass example ()
  ((attr
    :initarg :x
    :accessor attr
    :initform 10)))

;;; * Function

(defun getter ()
  (setf x (make-instance 'example :x 3))
  (attr x))


;;; * End

;; Local Variables:
;; outline-regexp: ";;; \\*+ "
;; outline-heading-alist: ((";;; \\* " . 1) (";;; \\*\\* " . 2) (";;; \\*\\*\\* " . 3) (";;; \\*\\*\\*\\* " . 4))
;; outline-level: #'my/outline-level
;; End:
