#!/usr/bin/guile \
--no-auto-compile -s
!#

(add-to-load-path (dirname (current-filename)))


(use-modules (conf-base)
             (ice-9 popen)
             (ice-9 rdelim)
             ((mutt) #:prefix mutt:)
             ((mbsync) #:prefix mbsync:)
             ((util) #:select (pass escape pass/escape)))



(define static-passwords
  (getenv "STATIC_PASSWORD"))

(define $HOME (getenv "HOME"))

(define BINDIR (string-append (dirname (current-filename))
                              file-name-separator-string "bin"))

(define mailfolder
  (case (string->symbol (gethostname))
    ((gandalf) (path-append "/var/mail" (getlogin)))
    (else (path-append $HOME "/.local/var/mail"))))

(define mbsync-version
  (let ((p (open-input-pipe "mbsync --version")))
    (cadr (string-split (read-line p) #\space))))


(account default ()
         (name "Samuel Junesjö")
         (path-base ,mailfolder)
         (fancy-acc-name ,(string-titlecase (? acc-name)))

         ;; (pass ,(string-append "pass " (? pass-path)))

         (IMAPAccount
          (SSLType "IMAPS")
          (CertificateFile "/etc/ssl/certs/ca-certificates.crt")
          (User ,(? address))
          ,@(if static-passwords
                ((Pass ,(pass/escape (? pass-path))))
                ((PassCmd ,(format #f "+\"pass ~a\"" (? pass-path))))))

         (MaildirStore
          (AltMap yes)
          (Path ,(path-append (? path-base) (? fancy-acc-name) "/"))
          (Inbox ,(path-append (? MaildirStore Path)
                                 "INBOX"))
          (SubFolders Verbatim))

         (IMAPStore
          (Account ,(? acc-name)))

         (Channel
          (Create Both)
          (Sync All)
          (Patterns "*")
          (SyncState "*")
          ,@(if (version<= "1.4" mbsync-version)
              ((Far    ,(format #f ":~a:" (mbsync:category-transformer 'IMAPStore (? acc-name))))
               (Near   ,(format #f ":~a:" (mbsync:category-transformer 'MaildirStore (? acc-name)))))
              ((Master ,(format #f ":~a:" (mbsync:category-transformer 'IMAPStore (? acc-name))))
               (Slave  ,(format #f ":~a:" (mbsync:category-transformer 'MaildirStore (? acc-name))))))
          )


         (signature ,(? name))

         (mutt
          (set
           (from ,(format #f "~a <~a>" (? name) (? address)))
           (realname ,(? name))
           (record ,(format #f "=~a/INBOX" (? fancy-acc-name)))
           (sidebar_divider_char "│")
           (edit_headers yes)
           ;; keep tree above message
           ;; (pager_index_lines 10)
           (muttlisp_inline_eval yes)

           (mime_forward yes)
           (autoedit yes) ;; skips `To:' and `Subject:' prompts when composing mail
           (include yes)  ;; skips `include-copy' prompt

           ;; (forward_format "[%a: %s]")
           (forward_format "FWD: %s")
           )

          (file
           (dir ,(path-append $HOME "/.mutt/"))
           (account-dir ,(path-append (? mutt file dir) "accounts"))
           (signature-dir ,(path-append (? mutt file dir) "signatures"))
           (account-config ,(path-append (? mutt file account-dir) (? address)))
           (account-signature ,(path-append (? mutt file signature-dir) (? address))))

          ;; (imap-pass ,(? pass))
          (imap-addr ,(format #f "imaps://~a@~a"
                              (? IMAPAccount User)
                              (? IMAPAccount Host)))
          (account-hook
           (imap-password ,(list (? mutt imap-addr)
                                 (if static-passwords
                                     (format #f "set imap_pass='~a'" (escape (char-set #\" #\' #\`)
                                                                             (pass (? pass-path))))
                                     (format #f "set imap_pass='`pass ~a`'" (? pass-path))))))

          (folder-hook
           (hk1 ,(list (format #f "(~a|~a)"
                               (? mutt imap-addr)
                               (? MaildirStore Path))
                       (format #f "source ~a" (? mutt file account-config))
                       )))

          ;; signature moved outside mutt for easier usage of multiple
          ;; mail clients.
          (signature ,(? signature)))
         )

(account google (default)
         (IMAPAccount
          (Host "imap.gmail.com")
          (AuthMechs "LOGIN"))
         (Channel
          (Patterns "* ![Gmail]*")))



(account proton (default)
	(address "wnabee@protonmail.com")
	(pass-path "Protonmail")

	(IMAPAccount
	  (Host "imap.protonmail.com"))
)
(account gmail (google)
         (address "samuel.junesjo@gmail.com")
         (pass-path "google.com/hugo.hornquist/mutt")

         #;
         (mutt
          (set
           (from "Hugo Hörnquist <hugo@hornquist.se>"))))

(account lysator (default)
         (address "wnabee@lysator.liu.se")
         (pass-path "lysatormail")

         (IMAPAccount
           (Host "imap.lysator.liu.se"))

         (signature "//Samuel")

         ;; if domain == lysator.liu.se
         ;; set record "=Lysator"

         (mutt (set (hostname "lysator.liu.se")
                    (record ,(if (string=? domainname "lysator.liu.se")
                               "=Lysator"
                               "=Lysator/INBOX"))

                    )))

(account outlook (default)
         (IMAPAccount
          (Host "outlook.office365.com")
          (AuthMechs LOGIN)))

(account liu (outlook)
         (address "samju303@student.liu.se")
         (pass-path "Studentmail")

         (signature "MvH\nSamuel")
         (mutt (set (hostname "liu.se"))))

(account liu-work (outlook)
         (address "hugo.hornquist@liu.se")
         ;; (pass-path "liu/hugho26")

         (IMAPAccount (User "hugho26@liu.se")
                      ;; NOTE that xouath2 isn't always available.
                      ;; Install something like the aur package
                      ;; cyrus-sasl-xoauth2-git
                      (AuthMechs XOAUTH2)
                      (PassCmd ,(format #f "+\"~a/oauth-response liu-imap\"" BINDIR))
                      (! Pass))

         (mutt (set (hostname "liu.se"))
               (account-hook
                 (imap-password
                   ,(list (? mutt imap-addr)
                          (format #f "set imap_pass='`~a/oauth-response liu-imap`'"
                                  BINDIR))))))


(account vg-base (default)
         (address ,(format #f "~a@vastgota.nation.liu.se" (? acc-name)))
         (postnamn ,(string-titlecase (format #f "~agöte" (? acc-name))))
         (signature ,(format #f "~a, ~a" (? name) (? postnamn)))
         (pass-path ,(format #f "vastgota.nation.liu.se/~a" (?  acc-name)))

         (IMAPAccount
           (Host "vastgota.nation.liu.se")
           (AuthMechs "LOGIN")
           (User ,(? acc-name)))

         (mutt (set (hostname "vastgota.nation.liu.se")
                    (record ,(format #f "=Vastgota.~a/INBOX" (?  fancy-acc-name)))))

         (MaildirStore
           (Path ,(path-append (? path-base)
                               (string-append "Vastgota."
                                 (? fancy-acc-name))
                               "/"))))

(account guckel (vg-base))
(account valberedningen (vg-base)
         (postnamn "Valberedning"))
(account pq (vg-base)
         (postname "Proqurator")
         (signature "Hugo Hörnquist, Proqurator"))

(account formulastudent (google)
         (pass-path "formulastudent/google/hugo.hornquist")
         (address "hugo.hornquist@liuformulastudent.se")

         (mutt (set (hostname "liuformulastudent.se")))

         (signature
           ,(format #f "~a, Team leader IT & Driverless~%✆ ~a"
                    (? name) (getenv "PHONE"))))

(account admittansen (google)
         (pass-path "admittansen/hugo@admittansen.se")
         (address "hugo@admittansen.se")

         (signature "Hugo Hörnquist\nLedamot Admittansen")
         (mutt (set (hostname "admittansen.se"))))



(account mutt-global ()
         (set (sort threads)
              (sort_aux "last-date-received")
              (index_format "%[%y-%m-%d  %H:%M]  %-15.15L %Z %s")
              (status_format "%f (%s) (%?V?limited to '%V'&no limit pattern?) (%P)")
              (menu_scroll yes)
              (editor "vim")
              (send_charset "utf-8")
              (sig_on_top yes)
              (header_cache "~/.mutt/cache")
              (message_cachedir "~/.mutt/cache")
              (folder ,mailfolder)
              (record ,(path-append (? set folder) "sent"))
              (postponed ,(path-append (? set folder) "postponed"))
              (imap_check_subscribed yes)
              (imap_list_subscribed yes)
              (ssl_starttls yes)
              (smtp_url "smtp://wnabee@mail.lysator.liu.se:26")
              (smtp_pass ,(if static-passwords
                              (pass/escape "lysatormail"
                                           (char-set #\" #\' #\`))
                              "`pass lysatormail`"))
              (ssl_force_tls yes)
              (assumed_charset "utf-8:iso-8859-1")
              (mbox_type "Maildir")

              (realname "Samuel Junesjö")
              (from "Samuel Junesjö <wnabee@lysator.liu.se>")

              (markers no)

              (rfc2047_parameters yes)

              )



         (macro
           (index ,`("\\cb |urlview\n"
                     "\\Ck <tag-prefix><clear-flag>o<tag-prefix><save-message>=Lysator/Junk<return><return>"
                     ;; https://brianbuccola.com/how-to-mark-all-emails-as-read-in-mutt/
                     "A <tag-pattern>~N<enter><tag-prefix><clear-flag>N"  ;; mark al new as read
                     ;; TODO find better bindings
                     ,(format #f "<F8> \"<shell-escape>mu find --clearlinks --format=links --linksdir=~a/search \" \"mu find\""
                             mailfolder)
                     ;; TODO change this to took on =search
                     ,(format #f "<F9> \"<change-folder-readonly>~a/search\" \"mu find results\""
                             mailfolder)
                     ))
           (pager ,`("\\cb |urlview\n"
                     ,(format #f "i '<enter-command>set pager_index_lines = ~s<enter>'"
                              '(if (equal $pager_index_lines 0) 10 0))
                  ))
           )

         (source ,'("~/.mutt/vim" "~/.mutt/colors"))

         (other
          (auto_view ,(string-join '("text/html"
                                     "text/calendar"
                                     "application/ics")))
          (alternative_order ,(string-join '("text/plain" "text/enriched" "text/html")))
          (push "<last-entry>")
          (ignore "*")
          (unignore ,(string-join '("from:" "subject" "to" "cc" "date" "x-url" "user-agent" "x-spam-score:"
                                    "X-Original-To" "Delivered-To" "Message-ID"))))
         )

(account mutt-global-lysator (mutt-global)
         (set
           (from "Hugo Hörnquist <hugo@lysator.liu.se>")
           (hostname "lysator.liu.se")

           (mask "!(dovecot|cur|tmp|new)")
           (spoolfile "/mp/mail/hugo/Maildir")
           (mbox      "/mp/mail/hugo/Maildir")
           (folder "~/.local/var/mail/")

           (record "=Lysator")

           ))

(account mutt-global-gpg (mutt-global)
         (set
           ;;(spoolfile "/var/mail/")
           (crypt_use_gpgme yes)
           (pgp_default_key "85D45A3135EA4AB1A683401A6E0A5CFFB28BC62A")))




;; check required environment:
(define required-env '(#;"PHONE"))
(for-each (lambda (str)
            (unless (getenv str)
              (format (current-error-port)
                      "~%Please set the env var ~a to something~%~%"
                      str)
              (exit 1)))
          required-env)

(define domainname (read-line (open-input-pipe "hostname --domain")))

(define account-list
  (list
    lysator
    ;;gmail
    liu
    ;;liu-work

    ))

;; TODO this only applies to newly created files, meaning that we
;; leak details if the file exists world readable beforehand.
(umask #o077)

(chmod (path-append $HOME ".mbsyncrc") #o600)
(with-output-to-file (path-append $HOME ".mbsyncrc")
  (lambda ()
    (mbsync:render
      (if (string=? domainname "lysator.liu.se")
        (delete lysator account-list)
        account-list))))
(chmod (path-append $HOME ".mbsyncrc") #o400)

(mutt:render
 ;; (open-input-file (path-append (dirname (dirname (current-filename))) "mutt" "muttrc"))
 (cond ((string=? domainname "lysator.liu.se") mutt-global-lysator)
       (else mutt-global-gpg))
 account-list)

(display
  (if static-passwords
    "Embedding passwords in file"
    "Leaving passwords in manager"))
(newline)
#;
(with-output-to-file
  (format #f "~a/profile.d/private-mailconf.sh.~a"
          (or (getenv "XDG_CONFIG_HOME")
              (path-append (getenv "HOME") "/.config"))
          (gethostname))
  (lambda ()
    (display
      (if static-passwords
        "systemctl set-environment --user STATIC_MAILCONF=1\n"
        "systemctl unset-environment --user STATIC_MAILCONF\n"))))
