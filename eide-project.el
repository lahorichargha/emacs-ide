;;; eide-project.el --- Emacs-IDE, project

;; Copyright (C) 2005-2009 Cédric Marie

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(provide 'eide-project)


;; Test if xcscope is available
(defvar eide-option-use-cscope-flag nil)
(if (locate-library "xcscope")
  (progn
    (require 'xcscope)
    (setq eide-option-use-cscope-flag t)))

(defvar eide-project-cscope-files-flag nil)

(defvar eide-project-name nil)

;; Shell command for creating tags
(defvar eide-create-tags-command "rm -f TAGS ; ctags -eR --links=no")

;; Shell command for creating cscope.files
;; -type f : excludes links
;; cscope.out will be generated on next search
(defvar eide-create-cscope-command "rm -f cscope.files cscope.out ; find . -type f \\( -name \"*.[ch]\"  -o -name \"*.cpp\" -o -name \"*.hh\" \\) > cscope.files")

;; eide-project-start-shell-alias is necessary for bash but not csh (.cshrc is run automatically)
(if (string-equal shell-file-name "/bin/bash")
  (setq eide-project-start-shell-alias ". ~/.bashrc") ; for bash
  (setq eide-project-start-shell-alias "")) ; for csh


;;;; ==========================================================================
;;;; INTERNAL FUNCTIONS
;;;; ==========================================================================

;; ----------------------------------------------------------------------------
;; Create tags.
;;
;; input  : eide-root-directory : project root directory.
;; ----------------------------------------------------------------------------
(defun eide-l-project-create-tags ()
  (shell-command (concat "cd " eide-root-directory " ; " eide-create-tags-command)))

;; ----------------------------------------------------------------------------
;; Create cscope list of files.
;;
;; input  : eide-root-directory : project root directory.
;; ----------------------------------------------------------------------------
(defun eide-l-project-create-cscope-list-of-files ()
  (shell-command (concat "cd " eide-root-directory " ; " eide-create-cscope-command)))
;; (cscope-index-files nil))

;; ----------------------------------------------------------------------------
;; Set cscope status (disabled if list of files is empty).
;;
;; input  : eide-root-directory : project root directory.
;; output : eide-project-cscope-files-flag : t = cscope.files is not empty.
;; ----------------------------------------------------------------------------
(defun eide-l-project-update-cscope-status ()
  (setq eide-project-cscope-files-flag nil)
  (if (not (equal (nth 7 (file-attributes (concat eide-root-directory "cscope.files"))) 0))
    (setq eide-project-cscope-files-flag t)))

;; ----------------------------------------------------------------------------
;; Compile project.
;;
;; input  : p-parameter : option parameter in project configuration for
;;              compile command.
;;          eide-root-directory : project root directory.
;; output : eide-windows-update-result-buffer-id : "c" for "compile".
;; ----------------------------------------------------------------------------
(defun eide-l-project-compile (p-parameter)
  (eide-windows-select-window-results)
  ;; sometimes does not compile when a grep buffer is displayed
  ;; "compilation finished" is displayed in grep buffer !
  (switch-to-buffer "*results*")
  ;; Change current directory (of unused buffer "*results*")
  (setq default-directory eide-root-directory)
  (let ((l-compile-command (eide-project-get-full-command p-parameter)))
    ;; Compile buffer name will be updated in eide-l-windows-display-buffer-function
    (setq eide-windows-update-result-buffer-id "c")
    (compile l-compile-command))
  (eide-windows-select-window-file t))

;; ----------------------------------------------------------------------------
;; Run project.
;;
;; input  : p-parameter : option parameter in project configuration for
;;              run command.
;;          eide-root-directory : project root directory.
;; output : eide-windows-update-result-buffer-id : "r" for "run".
;; ----------------------------------------------------------------------------
(defun eide-l-project-run (p-parameter)
  (eide-windows-select-window-results)
  ;; sometimes does not compile when a grep buffer is displayed
  ;; "compilation finished" is displayed in grep buffer !
  (switch-to-buffer "*results*")
  ;; Changing current directory has no effect with shell-command
  ;; Instead, we must change current directory in the command itself
  ;; Command ends with "&" otherwise emacs gets frozen until gdb is closed
  (let ((l-run-command (concat "cd " eide-root-directory " ; " (eide-project-get-full-command p-parameter) " &")))
    ;; Run buffer name will be updated in eide-l-windows-display-buffer-function
    (setq eide-windows-update-result-buffer-id "r")
    (shell-command l-run-command)))

;; ----------------------------------------------------------------------------
;; Debug project.
;;
;; input  : p-parameter : option parameter in project configuration for
;;              debug command.
;;          eide-root-directory : project root directory.
;; output : eide-windows-update-result-buffer-id : "d" for "debug".
;; ----------------------------------------------------------------------------
(defun eide-l-project-debug (p-parameter)
  (eide-windows-select-window-results)
  ;; sometimes does not compile when a grep buffer is displayed
  ;; "compilation finished" is displayed in grep buffer !
  (switch-to-buffer "*results*")
  ;; Change current directory (of unused buffer "*results*")
  (setq default-directory eide-root-directory)
  (let ((l-eide-debug-command (eide-config-get-project-value p-parameter)))
    ;; Debug buffer name will be updated in eide-l-windows-display-buffer-function
    (setq eide-windows-update-result-buffer-id "d")
    (gdb l-eide-debug-command)))


;;;; ==========================================================================
;;;; FUNCTIONS
;;;; ==========================================================================

;; ----------------------------------------------------------------------------
;; Create a project.
;;
;; input  : eide-root-directory : project root directory.
;; output : eide-project-name : project name.
;; ----------------------------------------------------------------------------
(defun eide-project-create ()
  (if (eide-popup-question-yes-or-no-p (concat "Create project in " eide-root-directory " ?"))
    (progn
      (eide-windows-select-window-file t)
      ;; Create empty project file
      (shell-command (concat "touch " eide-root-directory eide-project-file))
      (eide-project-start-with-project)
      ;; Update frame title and menu (project is active now)
      (eide-project-update-frame-title)
      (eide-menu-update t)
      ;; Update key bindings for project
      (eide-keys-configure-for-editor))))

;; ----------------------------------------------------------------------------
;; Delete current project.
;;
;; input  : eide-root-directory : project root directory.
;; output : eide-project-name : project name (nil).
;; ----------------------------------------------------------------------------
(defun eide-project-delete ()
  (if (eide-popup-question-yes-or-no-p (concat "Delete project in " eide-root-directory " ?"))
    (progn
      (setq eide-project-name nil)
      (kill-buffer eide-project-file)
      (if (get-buffer "TAGS")
        (kill-buffer "TAGS"))
      (shell-command (concat "cd " eide-root-directory " ; rm -f TAGS cscope.files cscope.out .emacs-ide.*"))
      (desktop-remove)
      ;; Update frame title and menu (project is inactive now)
      (eide-project-update-frame-title)
      (eide-menu-update t)
      ;; Update key bindings for project
      (eide-keys-configure-for-editor))))

;; ----------------------------------------------------------------------------
;; Start with current project.
;;
;; input  : eide-root-directory : project root directory.
;; ----------------------------------------------------------------------------
(defun eide-project-start-with-project ()
  ;; Get project name from directory
  ;; eide-root-directory                                                     : <...>/current_project/
  ;; directory-file-name removes last "/"                                    : <...>/current_project
  ;; file-name-nondirectory retrieves last directory name from complete path : current_project
  (setq eide-project-name (file-name-nondirectory (directory-file-name eide-root-directory)))

  ;; "Lock" project
  ;;(shell-command (concat "touch " eide-root-directory eide-project-lock-file))

  ;; Rebuild project file
  (eide-config-rebuild-project-file)

  (if eide-option-use-cscope-flag
    (progn
      ;; Create cscope database if necessary
      (if (not (file-exists-p (concat eide-root-directory "cscope.files")))
        (progn
          (message "Creating cscope list of files...")
          ;;(shell-command (concat "cd " eide-root-directory " ; cscope -bR"))
          (eide-l-project-create-cscope-list-of-files)
          (message "Creating cscope list of files... done")))
      (eide-l-project-update-cscope-status)))

  (if (or (not eide-option-use-cscope-flag) eide-option-use-cscope-and-tags-flag)
    (progn
      ;; Create tags if necessary
      (if (not (file-exists-p (concat eide-root-directory "TAGS")))
        (progn
          (message "Creating tags...")
          (eide-l-project-create-tags)
          (message "Creating tags... done")))
      ;; Load tags now, otherwise first tag search will take some time...
      ;;(find-file-noselect (concat eide-root-directory "TAGS"))
))

  (if (not (file-exists-p (concat eide-root-directory eide-project-notes-file)))
    ;; Create empty project notes file
    (shell-command (concat "touch " eide-root-directory eide-project-notes-file)))

  ;; TODO : sous flag
  ;; Tag file name with full path
  (setq tags-file-name (concat eide-root-directory "TAGS"))

  ;; Create session file if necessary
  (if (not (file-exists-p (concat eide-root-directory ".emacs.desktop")))
    (progn
      (message "Creating .emacs.desktop...")
      (desktop-save eide-root-directory)
      (message "Creating .emacs.desktop... done"))))

;; ----------------------------------------------------------------------------
;; Update tags.
;; ----------------------------------------------------------------------------
(defun eide-project-update-tags ()
  (message "Updating tags...")
  (eide-l-project-create-tags)
  (message "Updating tags... done"))

;; ----------------------------------------------------------------------------
;; Update cscope list of files.
;; ----------------------------------------------------------------------------
(defun eide-project-update-cscope-list-of-files ()
  (message "Updating cscope list of files...")
  ;;(shell-command (concat "cd " eide-root-directory " ; rm -f cscope.files cscope.out"))
  (eide-l-project-create-cscope-list-of-files)
  (eide-l-project-update-cscope-status)
  ;;(shell-command (concat "cd " eide-root-directory " ; cscope -bR"))
  (message "Updating cscope list of files... done"))

;; ----------------------------------------------------------------------------
;; Update frame title with project name (or root directory if no project)
;;
;; input  : eide-project-name : project name.
;; ----------------------------------------------------------------------------
(defun eide-project-update-frame-title ()
  (if eide-project-name
    (setq frame-title-format (concat eide-project-name " - Emacs"))
    (setq frame-title-format (concat eide-root-directory " - Emacs"))))

;; ----------------------------------------------------------------------------
;; Get full command (init command + compile/run command).
;;
;; input  : p-parameter : option parameter in project configuration.
;; return : full command.
;; ----------------------------------------------------------------------------
(defun eide-project-get-full-command (p-parameter)
  (let ((l-init-command (eide-config-get-project-value "init_command")))
    (if (string-equal l-init-command "")
      (eide-config-get-project-value p-parameter)
      (concat l-init-command " ; " (eide-config-get-project-value p-parameter)))))

;; ----------------------------------------------------------------------------
;; Get project relative path from absolute path (remove project absolute path
;; from directory).
;;
;; input  : p-directory : directory (absolute path).
;;          eide-root-directory : project root directory.
;; return : directory (project relative path).
;; ----------------------------------------------------------------------------
(defun eide-project-get-short-directory (p-directory)
  ;; Remove project base path if the file is part of it (otherwise display full path)
  (if (and (<= (length eide-root-directory) (length p-directory)) (string-equal eide-root-directory (substring p-directory 0 (length eide-root-directory))))
    (substring p-directory (length eide-root-directory))
    p-directory))

;; ----------------------------------------------------------------------------
;; Compile project (1st compile command).
;; ----------------------------------------------------------------------------
(defun eide-project-compile-1 ()
  (interactive)
  (eide-l-project-compile "compile_command_1"))

;; ----------------------------------------------------------------------------
;; Compile project (2nd compile command).
;; ----------------------------------------------------------------------------
(defun eide-project-compile-2 ()
  (interactive)
  (eide-l-project-compile "compile_command_2"))

;; ----------------------------------------------------------------------------
;; Run project (1st run command).
;; ----------------------------------------------------------------------------
(defun eide-project-run-1 ()
  (interactive)
  (eide-l-project-run "run_command_1"))

;; ----------------------------------------------------------------------------
;; Run project (2nd run command).
;; ----------------------------------------------------------------------------
(defun eide-project-run-2 ()
  (interactive)
  (eide-l-project-run "run_command_2"))

;; ----------------------------------------------------------------------------
;; Debug project (1st debug command).
;; ----------------------------------------------------------------------------
(defun eide-project-debug-1 ()
  (interactive)
  (eide-l-project-debug "debug_command_1"))

;; ----------------------------------------------------------------------------
;; Debug project (2nd debug command).
;; ----------------------------------------------------------------------------
(defun eide-project-debug-2 ()
  (interactive)
  (eide-l-project-debug "debug_command_2"))

;;; eide-project.el ends here
