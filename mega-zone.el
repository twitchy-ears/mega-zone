;;; mega-zone.el --- A zone wrapper that hits all open frames and windows a GUImacs -*- lexical-binding: t -*-

;; Copyright 2023 - Twitchy Ears

;; Author: Twitchy Ears https://github.com/twitchy-ears/
;; URL: https://github.com/twitchy-ears/mega-zone
;; Version: 0.1
;; Package-Requires ((emacs "24.1"))
;; Keywords: games

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; History
;;
;; 2023-11-06 - initial version

;;; Commentary:

;; (require 'mega-zone)
;; (mega-zone-setup t)
;;
;; Then call M-x zone as normal
;;
;; You can customise the behaviour by setting
;; mega-zone-dispatch-action to one of show-mz-buffer, invisible, or
;; zone-all.

(require 'zone)

(defvar mega-zone-dispatch-action 'show-mz-buffer
"Controls how non-main windows and frames are treated.  The
 options are invisible (uses make-frame-invisible to hide all
 other frames and should ignore console windows), show-mz-buffer (shows
 a *mega-zone* buffer with some text in in existing windows), or
 zone-all (attempts to switch all other windows to showing the
 *zone* buffer so they all have the same contents).

 Functionally this causes the (mega-zone) function to attempt to
 run a function with this variables symbol prefixed by
 mega-zone-- so if you want to define your own behaviours you can,
 the current frameset will be saved and restored around your
 function but you have to call (zone) yourself.")

(defvar mega-zone-buffer-text "I AM MEGA ZONING" "This provides the text for when mega-zone is run in show-mz-buffer mode")

(defvar mega-zone-buffer-name "*mega-zone*" "The name of the buffer for show-mz-buffer mode")

(defvar mega-zone--active nil
  "Set to t if mega-zone is currently active, if t will run the
 original zone command, otherwise will run mega-zone-dispatcher")

(defun mega-zone-setup (&rest args)
  (interactive)
  ;; Called interactively?  Just act like a toggle
  (if (called-interactively-p 'interactive)

      ;; Just toggle
      (if (advice-member-p 'mega-zone #'zone)
          (progn
            (message "mega-zone: deactivating advice")
            (advice-remove 'zone #'mega-zone))
        (progn
          (message "mega-zone: activating advice")
          (advice-add 'zone :around #'mega-zone)))

    ;; Otherwise bother to check arguments if the first isn't nil then
    ;; switch on
    (let ((activate (car args)))
      (if activate
          
          (if (not (advice-member-p 'mega-zone #'zone))
              (progn
                (advice-add 'zone :around #'mega-zone)
                (message "mega-zone: activating advice"))
            (message "mega-zone: already active"))
        
        ;; Attempt to switch off
        (if (advice-member-p 'mega-zone #'zone)
            (progn
              (advice-remove 'zone #'mega-zone)
              (message "mega-zone: deactivating advice"))
          (message "mega-zone: already deactivated"))))))    

(defun mega-zone (&rest args)
  "A function that advises (zone), attempts to call (mega-zone-dispatcher)
 the first time its run, subsequent calls to (zone) while that's
 running will call the original zone function.

 mega-zone-dispatcher does all the work and pays attention to the
 mega-zone-dispatch-action variable to decide what action to
 perform on other frames and windows so check the documentation
 for them both."
  (interactive)

  ;; If we're advising :around zone then the first argument will be
  ;; the original zone function.
  ;;
  ;; So if that exists, is a function, and we're already running
  ;; mega-zone-dispatcher then we should launch the original zone
  ;; function
  ;;
  ;; Otherwise we should run mega-zone-dispatcher and kick the process
  ;; off.  Check for mega-zone--active first because thats a cheap check.
  (if mega-zone--active
      
      (let ((zone-func (car args))
            (orig-args (cdr args)))
        (if (and zone-func
                 (functionp zone-func))
            (apply zone-func orig-args)))
      
      (mega-zone-dispatcher)))

(defun mega-zone-dispatcher ()
  "Checks the contents of the mega-zone-dispatch-action variable
 and if there is a function prefixed with mega-zone-- that
 matches this it will attempt to run it, wrapping that call in a
 frameset-save and frameset-restore to keep the current window
 config."
  ;; Switch subsequent calls to zone to the original
  (setq mega-zone--active t)

  (unwind-protect
      (let ((current-frameset (frameset-save nil))
            (mz-func
             (intern-soft (format "mega-zone--%s" mega-zone-dispatch-action))))
        
        ;; If we have a function of the correct name then dispatch it from
        ;; inside an unwind protect so even if zone has issues we restore
        ;; our original frame setup.
        (if (and current-frameset
                 (functionp mz-func))
            
            (unwind-protect (funcall mz-func)
              (frameset-restore current-frameset
                                :reuse-frames 'match
                                :cleanup-frames t))
          
          (error "mega-zone-dispatcher: no function called '%s'" mz-func)))

    ;; Declare we're done
    (setq mega-zone--active nil)))

(defun mega-zone--show-mz-buffer ()
  "Switches every window except the primary one to looking at a
  temporary buffer named after the mega-zone-buffer-name variable
  and populated by the contents of the mega-zone-buffer-text
  variable, then runs zone in the current window"
  (let ((my-frame-list (visible-frame-list))
        (curr-window (selected-window))
        (mega-zone-buffer (get-buffer-create mega-zone-buffer-name)))

    ;; Populate the buffer
    (with-current-buffer mega-zone-buffer
      (insert mega-zone-buffer-text))

    ;; Loop through every frame (except the current) then every window
    ;; of each frame and switch all their buffers to looking at the
    ;; one we just created
    (dolist (frame-name my-frame-list)
      (let ((windows (window-list frame-name nil)))
        (dolist (win windows nil)
          (select-window win)
          (if (not (eq win curr-window))
              (switch-to-buffer mega-zone-buffer nil 'force-same-window)))))

    ;; Back to the original window, kick off the zoning, then kill the
    ;; temp buffer before we exit
    (select-window curr-window)
    (unwind-protect
        (zone)
      (kill-buffer mega-zone-buffer))))

(defun mega-zone--invisible ()
  "Makes every frame not the currently selected one invisible and
  runs zone in the currently selected one"
  (let ((my-frame-list (visible-frame-list))
        (curr-frame (window-frame))
        (curr-window (selected-window)))
    (dolist (frame-name my-frame-list)
      (if (not (eq frame-name curr-frame))
          (make-frame-invisible frame-name)))
    (select-window curr-window)
    (zone)))

(defun mega-zone--zone-all ()
  "Attempts to switch every window to looking at *zone* before it
  runs zone, note that zone will only effect the contents of the
  selected buffer so you'll get that mirrored across all your
  windows"
  (let ((my-frame-list (visible-frame-list))
        (curr-window (selected-window)))
    
    ;; For every frame go through every window and attempt to switch
    ;; them all to looking at the *zone* buffer except the current
    ;; window, jump back to that then zone it.
    (dolist (frame-name my-frame-list)
      (let ((windows (window-list frame-name nil)))
        (dolist (win windows nil)
          (select-window win)
          (if (not (eq win curr-window))
              (switch-to-buffer "*zone*" nil 'force-same-window)))))
    
    (select-window curr-window)
    (zone)))

(provide 'mega-zone)
;;; mega-zone.el ends here
