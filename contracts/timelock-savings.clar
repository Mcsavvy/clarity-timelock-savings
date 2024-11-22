;; Time-Locked Savings Account Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-lock-in-effect (err u103))

;; Data variables
(define-map savings-accounts
  principal
  {
    balance: uint,
    lock-period: uint,
    lock-end: uint,
    interest-rate: uint
  }
)

(define-map interest-rates
  uint  ;; lock period in days
  uint  ;; interest rate (basis points)
)

;; Public functions

;; Create a new savings account
(define-public (create-account (lock-period uint))
  (let ((sender tx-sender))
    (if (default-to false (get-account-exists sender))
      err-already-exists
      (begin
        (map-set savings-accounts
          sender
          {
            balance: u0,
            lock-period: lock-period,
            lock-end: u0,
            interest-rate: (get-interest-rate lock-period)
          }
        )
        (ok true)
      )
    )
  )
)

;; Deposit tokens into the savings account
(define-public (deposit (amount uint))
  (let (
    (sender tx-sender)
    (account (unwrap! (get-account sender) err-not-found))
  )
    (if (> (get lock-end account) block-height)
      err-lock-in-effect
      (begin
        (map-set savings-accounts
          sender
          (merge account {
            balance: (+ (get balance account) amount),
            lock-end: (+ block-height (get lock-period account))
          })
        )
        (stx-transfer? amount sender (as-contract tx-sender))
      )
    )
  )
)

;; Withdraw tokens from the savings account
(define-public (withdraw (amount uint))
  (let (
    (sender tx-sender)
    (account (unwrap! (get-account sender) err-not-found))
    (balance (get balance account))
    (lock-end (get lock-end account))
  )
    (if (and (>= balance amount) (<= lock-end block-height))
      (begin
        (map-set savings-accounts
          sender
          (merge account { balance: (- balance amount) })
        )
        (as-contract (stx-transfer? amount tx-sender sender))
      )
      (if (>= balance amount)
        (let (
          (penalty (/ (* amount u10) u100))  ;; 10% early withdrawal penalty
          (withdraw-amount (- amount penalty))
        )
          (begin
            (map-set savings-accounts
              sender
              (merge account { balance: (- balance amount) })
            )
            (as-contract (stx-transfer? withdraw-amount tx-sender sender))
          )
        )
        err-lock-in-effect
      )
    )
  )
)

;; Calculate and pay interest
(define-public (pay-interest (user principal))
  (let (
    (account (unwrap! (get-account user) err-not-found))
    (balance (get balance account))
    (interest-rate (get interest-rate account))
    (lock-end (get lock-end account))
  )
    (if (<= lock-end block-height)
      (let (
        (interest (/ (* balance interest-rate) u10000))
      )
        (begin
          (map-set savings-accounts
            user
            (merge account {
              balance: (+ balance interest),
              lock-end: u0
            })
          )
          (ok interest)
        )
      )
      err-lock-in-effect
    )
  )
)

;; Admin function to set interest rates
(define-public (set-interest-rate (lock-period uint) (rate uint))
  (if (is-eq tx-sender contract-owner)
    (begin
      (map-set interest-rates lock-period rate)
      (ok true)
    )
    err-owner-only
  )
)

;; Read-only functions

(define-read-only (get-account (user principal))
  (map-get? savings-accounts user)
)

(define-read-only (get-account-exists (user principal))
  (is-some (map-get? savings-accounts user))
)

(define-read-only (get-interest-rate (lock-period uint))
  (default-to u0 (map-get? interest-rates lock-period))
)

