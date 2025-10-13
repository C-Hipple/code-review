;;; code-reivew-delta.el --- Use Delta when displaying diffs in Code Review -*- lexical-binding: t; -*-

;; Author: Chris Hipple / (copied mostly from Dan Davison <dandavison7@gmail.com>)
;; URL: https://github.com/C-Hipple/code-review-delta
;; Version: 0.0.12
;; Package-Requires: ((emacs "25.1") (magit "20200426") (xterm-color "2.0"))

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; The original work in this file is all from the above repository.
;; It has been copied and very minorly modified very slightly for usage ONLY in code-reivew

;;; Code:
(require 'xterm-color)
(require 'dash)

(defgroup code-review-delta nil
  "Magit delta customizations."
  :group 'magit-diff
  :group 'magit-modes)

(defcustom code-review-delta-delta-executable "delta"
  "The delta executable on your system to be used by Magit."
  :type 'string
  :group 'code-review-delta)

(defcustom code-review-delta-default-light-theme "GitHub"
  "The default color theme when Emacs has a light background."
  :type 'string
  :group 'code-review-delta)

(defcustom code-review-delta-default-dark-theme "Monokai Extended"
  "The default color theme when Emacs has a dark background."
  :type 'string
  :group 'code-review-delta)

(defcustom code-review-delta-delta-args
  `("--max-line-distance" "0.6"
    "--true-color" ,(if xterm-color--support-truecolor "always" "never")
    "--color-only")
  "Delta command line arguments as a list of strings.

If the color theme is not specified using --theme, then it will
be chosen automatically according to whether the current Emacs
frame has a light or dark background. See `code-review-delta-default-light-theme' and
`code-review-delta-default-dark-theme'.

--color-only is required in order to use delta with magit; it
will be added if not present."
  :type '(repeat string)
  :group 'code-review-delta)

(defcustom code-review-delta-hide-plus-minus-markers 't
  "Whether to hide the +/- markers at the beginning of diff lines."
  :type '(choice (const :tag "Hide" t)
                 (const :tag "Show" nil))
  :group 'code-review-delta)

(defun code-review-delta--make-delta-args ()
  "Make final list of delta command-line arguments."
  (let ((args code-review-delta-delta-args))
    (unless (-intersection '("--syntax-theme" "--light" "--dark") args)
      (setq args (nconc
                  (list "--syntax-theme"
                        (if (eq (frame-parameter nil 'background-mode) 'dark)
                            code-review-delta-default-dark-theme
                          code-review-delta-default-light-theme))
                  args)))
    (unless (member "--color-only" args)
      (setq args (cons "--color-only" args)))
    args))

;;;###autoload
(defun code-review-delta-call-delta ()
  (interactive)
  "Call delta on buffer contents and convert ANSI escape sequences to overlays.
The input buffer contents are expected to be raw git output."
  (apply #'call-process-region
         (point-min) (point-max)
         code-review-delta-delta-executable t t nil (code-review-delta--make-delta-args))
  (let ((buffer-read-only nil))
    (xterm-color-colorize-buffer 'use-overlays)
    (if code-review-delta-hide-plus-minus-markers
        (code-review-delta-hide-plus-minus-markers))))

(defun code-review-delta-hide-plus-minus-markers ()
  "Apply text properties to hide the +/- markers at the beginning of lines."
  (save-excursion
    (goto-char (point-min))
    ;; Within hunks, hide - or + at the start of a line.
    (let ((in-hunk nil))
      (while (re-search-forward "^\\(diff\\|@@\\|+\\|-\\)" nil t)
        (cond
         ((string-equal (match-string 0) "diff")
          (setq in-hunk nil))
         ((string-equal (match-string 0) "@@")
          (setq in-hunk t))
         (in-hunk
          (add-text-properties (match-beginning 0) (match-end 0)
                               '(display " "))))))))

(provide 'code-review-delta)
