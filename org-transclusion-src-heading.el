;;; org-transclusion-src-heading.el --- org-transclusion extension -*- lexical-binding: t -*-

;; Author: Aatmun Baxi <baxiaatmun@gmail.com>
;; Version: 0.1
;; Package-Requires: ((emacs "27.1") (org "9.4") (org-transclusion))
;; Keywords: org-transclusion
;; Created: 2026-03-20
;; Last Modified: 2026-03-20

;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package enables transclusion of outline-mode
;; headings from src files, rather than being limited
;; to using lines. This relies on a file-local `outline-regexp'
;; being set to find such headings

;;; Code:

(require 'org-transclusion)
(require 'org)

;;; * Variables:
(defcustom org-transclusion-src-heading-name-capture-group
  0
  "Number of which capture group in `outline-regexp' to match for heading
names. 0 matches all of `outline-regexp'.

For example, with this variable set to 2 in `emacs-lisp-mode' and
`outline-regexp' set to \";;; \\(\\*+\\) \\(.*\\)\", the package will match
\"foo\" in the heading \";;; ** foo\" when looking for heading names."
  :type 'natnum)

(defcustom org-transclusion-src-heading-level-capture-group
  0
  "Number of which capture group in `outline-regexp' to match for heading
level. 0 matches all of `outline-regexp'.

For example, with this variable set to 1 in `emacs-lisp-mode' and
`outline-regexp' set to \";;; \\(\\*+\\) \\(.*\\)\", the package will determine
level 2 in the heading \";;; ** foo\" when looking for heading names."
  :type 'natnum)

;;; Functions
;;; * Minor mode and adding functions

;;;###autoload
(define-minor-mode org-transclusion-src-heading-mode ()
  :lighter nil
  :global t
  :group 'org-transclusion
  (if org-transclusion-src-heading-mode
      (org-transclusion-extension-functions-add-or-remove
       org-transclusion-src-heading-extension-functions)
    (org-transclusion-extension-functions-add-or-remove
     org-transclusion-src-lines-extension-functions :remove)))

(defvar org-transclusion-src-heading-extension-functions
  (list
   ;; Add a new transclusion type
   (cons 'org-transclusion-add-functions #'org-transclusion-add-src-heading)
    ;; Keyword values
   (cons 'org-transclusion-keyword-value-functions
         '(org-transclusion-keyword-value-src-heading))
   ;; plist back to string
   (cons 'org-transclusion-keyword-plist-to-string-functions
         #'org-transclusion-keyword-plist-to-string-src-heading)
   ;; Transclusion content formatting
   (cons 'org-transclusion-content-format-functions
         #'org-transclusion-content-format-src-lines)
   ;; Open source buffer
   (cons 'org-transclusion-open-source-marker-functions
         #'org-transclusion-open-source-marker-src-lines)
   ;; Live-sync
   (cons 'org-transclusion-live-sync-buffers-functions
         #'org-transclusion-live-sync-buffers-src-lines))
  "Alist of functions to activate `org-transclusion-src-heading'.
CAR of each cons cell is a symbol name of an abnormal hook
\(*-functions\). CDR is either a symbol or list of symbols, which
are names of functions to be called in the corresponding abnormal
hook.")

(defun org-transclusion-keyword-plist-to-string-src-heading (plist)
  "Convert a keyword PLIST to a string.
This function is meant to be used as an extension for function
`org-transclusion-keyword-plist-to-string'.  Add it to the
abnormal hook
`org-transclusion-keyword-plist-to-string-functions'."
  (let ((lines (plist-get plist :lines))
        (src (plist-get plist :src))
        (heading (plist-get plist :heading))
        (rest (plist-get plist :rest))
        (end (plist-get plist :end))
        (noweb-chunk (plist-get plist :noweb-chunk))
        (thing-at-point (plist-get plist :thing-at-point)))
    (concat
     (when src (format " :src %s" src))
     (when heading (format " :heading \"%s\"" heading)))))


;;; * Top-level logic

(defun org-transclusion-add-src-heading (link plist)
  "Return a list for non-Org text and source file.
Determine add function based on LINK and PLIST.

Return nil if PLIST does not contain \":heading\" or \":src\" properties."

  (cond
   ((and (plist-get plist :heading)
         (plist-get plist :src))
    (progn (append '(:tc-type "src-heading")
                   (org-transclusion-src-heading link plist))))
   ((plist-get plist :src)
    (append '(:tc-type "src")
            (org-transclusion-content-src-lines link plist)))
   ;; :lines needs to be the last condition to check because :src INCLUDE :lines
   ((or (plist-get plist :lines)
        (plist-get plist :end)
        (and (org-element-property :search-option link)
             (not (org-transclusion-org-file-p (org-element-property :path link)))))
    (append (if (string-equal "id" (org-element-property :type link))
                '(:tc-type "org-lines")
              '(:tc-type "lines"))
            (org-transclusion-content-range-of-lines link plist)))))

;;; * Determine if at correct heading 
(defun org-transclusion-src-heading-at-heading (pos name BOUNDS)
  "Determine if the point is the at the correct heading"
  (let ((lino (line-number-at-pos))
        (found nil)
        (counter 0))
    (save-excursion
      (goto-char pos)
      (when-let* ((_ (looking-at outline-regexp))
                  (name-start (match-beginning
                                       org-transclusion-src-heading-name-capture-group))
                  (name-end (match-end
                                       org-transclusion-src-heading-name-capture-group))
                  (heading-name
                   (buffer-substring-no-properties name-start name-end)))
        (when (equal name heading-name)
          (setq found t))))
    found))

;;; * Determine text to transclude
(defun org-transclusion-src-heading-range (link plist)
  "Return a list of payload for a range of lines from LINK and PLIST.

You can specify a range of lines to transclude by adding the :line
property to a transclusion keyword like this:

    #+transclude: [[file:path/to/file.ext]] :lines 1-10

This is taken from Org Export (function
`org-export--inclusion-absolute-lines' in ox.el) with one
exception.  Instead of :lines 1-10 to exclude line 10, it has
been adjusted to include line 10.  This should be more intuitive
when it comes to including lines of code.

In order to transclude a single line, have the the same number in
both places (e.g. 10-10, meaning line 10 only).

One of the numbers can be omitted.  When the first number is
omitted (e.g. -10), it means from the beginning of the file to
line 10. Likewise, when the second number is omitted (e.g. 10-),
it means from line 10 to the end of file."
  (let* ((noweb-chunk (org-transclusion--update-noweb-chunk-search-option link plist))
         (src-mkr (org-transclusion-add-source-marker link))
         (buf (and src-mkr (marker-buffer src-mkr)))
         (name (plist-get plist :heading)))
    (when buf
      (with-current-buffer buf
        (org-with-wide-buffer
         (let* (;; This means beginning part of the range
                ;; can be mixed with search-option
                ;;; only positive number works
                (beg
                 (progn (goto-char (point-min))
                        (save-excursion
                          (while 
                              ;; TODO this bounds is hard coded...
                              (not (org-transclusion-src-heading-at-heading (point) name 100))
                            (outline-next-heading))
                          (point))))
                ;;; This `cond' means :end prop has priority over the end
                ;;; position of the range. They don't mix.
                (end (progn
                       (goto-char beg)
                       (outline-get-next-sibling)
                       (point)))
                (content (buffer-substring-no-properties beg end)))
           (message "beg: %s, end: %s" beg end)
           (list :src-content content
                 :src-buf (current-buffer)
                 :src-beg beg
                 :src-end end)))))))

(defun org-transclusion-src-heading-p (type)
  "Return non-nil when TYPE is \"src-heading\".
Return nil if neither."
  (string= type "src-heading"))

;;; * Modify payload content since src
(defun org-transclusion-src-heading (link plist)
  "Return a list of payload from LINK and PLIST in a src-block.
This function is also able to transclude only a certain range of
lines with using :lines n-m property.  Refer to
`org-transclusion-content-range-of-lines' for how the notation
for the range works."
  (let* ((payload (org-transclusion-src-heading-range link plist))
         (src-lang (plist-get plist :src))
         (rest (plist-get plist :rest)))
    ;; Modify :src-content if applicable
    (when src-lang
      (setq payload
            (plist-put payload :src-content
                       (let ((src-content (plist-get payload :src-content)))
                         (concat
                          (format "#+begin_src %s" src-lang)
                          (when rest (format " %s" rest))
                          "\n"
                          (org-transclusion-ensure-newline src-content)
                          "#+end_src\n")))))
    ;; Return the payload either modified or unmodified
    payload))


;;; * Match new :heading keyword

(defun org-transclusion-keyword-value-src-heading (string)
  "It is a utility function used converting a keyword STRING to plist.
It is meant to be used by `org-transclusion-get-string-to-plist'.
It needs to be set in
`org-transclusion-keyword-value-functions'."
  (and-let* ((_ (string-match ":heading \"\\(.*?\\)\"" string))
             (match (match-string 1 string))
             (val (if (string-empty-p match) "auto"  match)))
    (list :heading val)))



(provide 'org-transclusion-src-heading)

;;; org-transclusion-src-heading.el ends here

;; Local Variables:
;; outline-regexp: ";;; \\(\\*+\\) \\(.*\\) "
;; outline-heading-alist: ((";;; \\*\\*\\*\\* " . 1) (";;; \\*\\*\\* " . 2) (";;; \\*\\* " . 3) (";;; \\* " . 4))
;; End:
