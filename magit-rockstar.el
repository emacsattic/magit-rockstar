;;; magit-rockstar.el --- commit like a rockstar

;; Copyright (C) 2015  Jonas Bernoulli

;; Author: Jonas Bernoulli <jonas@bernoul.li>
;; Package-Requires: ((dash "2.10.0") (magit "2.0.50"))
;; Homepage: http://github.com/tarsius/magit-rockstar
;; Keywords: convenience

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides two commands which manipulate author
;; and committer dates.  You could use it to make yourself look
;; like a rockstar programmer who hammers out commits at one
;; commit per minute.  But the real purpose is to recover from
;; heavy re-arrangements of commits, that have causes the
;; existing author and committer dates to become meaningless.

;; I add these commands to the appropriate popups like this:
;;
;;    (magit-define-popup-action 'magit-rebase-popup
;;      ?R "Rockstar" 'magit-rockstar)
;;    (magit-define-popup-action 'magit-commit-popup
;;      ?R "Reshelve" 'magit-reshelve)

;; Also included is a command for debugging Magit sections.

;; Basically I am adding all Magit-related things here that I
;; find useful but don't want to add to Magit itself and also
;; don't belong into another package.

;;; Code:

(require 'dash)
(require 'magit)

(defun magit-rockstar (from &optional offset)
  "Attempt to make you look like a rockstar programmer.
Want to hammer out commits at one commit per minute?
With this function you can!"
  (interactive (list (magit-read-other-branch "Rocking since" nil
                                              (magit-get-tracked-branch))
                     (read-number "Offset: " 0)))
  (let* ((branch (magit-get-current-branch))
         (range (concat from ".." branch))
         (time (+ (truncate (float-time)) (* (or offset 0) 60)))
         (tz (car (process-lines "date" "+%z")))
         (format (format "%%s) \
export GIT_AUTHOR_DATE=\"%%s %s\"; \
export GIT_COMMITTER_DATE=\"%%s %s\";;" tz tz)))
    (setq time (- time (% time 60)))
    (magit-call-git "filter-branch" "-f" "--env-filter"
                    (format "case $GIT_COMMIT in %s\nesac"
                            (mapconcat
                             (lambda (commit)
                               (format format commit (cl-decf time 60) time))
                             (magit-git-lines "rev-list" range) " "))
                    range "--")
    (magit-run-git "update-ref" "-d"
                   (concat "refs/original/refs/heads/" branch))))

(defun magit-reshelve (date)
  "Change the author and committer dates of `HEAD' to DATE." 
  (interactive (list (read-string "Date or offset: "
                                  (car (process-lines "date" "+%FT%T%z")))))
  (let ((process-environment process-environment))
    (when (string-match "^[0-9]+$" date)
      (setq date (format "%s%s" (- (truncate (float-time)) (* date 60))
                         (car (process-lines "date" "+%z")))))
    (setenv "GIT_COMMITTER_DATE" date)
    (magit-run-git "commit" "--amend" "--no-edit" (concat "--date=" date))))

(defun magit-debug-sections ()
  "Print information about the current Magit buffer's sections."
  (interactive)
  (magit-debug-sections-1 magit-root-section 0)
  (save-excursion
    (goto-char (point-min))
    (while (< (point) (point-max))
      (let ((next (or (next-single-property-change
                       (point) 'invisible)
                      (point-max))))
        (message "%4s-%4s %s" (point) next
                 (get-text-property (point) 'invisible))
        (goto-char next)))))

(defun magit-debug-sections-1 (section level)
  (message "%-4s %-10s [%4s %3s]-[%4s %3s]  (%4s %3s)"
           (make-string (1+ level) ?*)
           (magit-section-type section)
           (marker-position       (magit-section-start section))
           (marker-insertion-type (magit-section-start section))
           (marker-position       (magit-section-end section))
           (marker-insertion-type (magit-section-end section))
           (ignore-errors (marker-position       (magit-section-content section)))
           (ignore-errors (marker-insertion-type (magit-section-content section))))
  (--each (magit-section-children section)
    (magit-debug-sections-1 it (1+ level))))

;;; magit-rockstar.el ends soon
(provide 'magit-rockstar)
;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; magit-rockstar.el ends here
