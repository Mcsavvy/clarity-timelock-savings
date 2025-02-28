;; Time-Locked Savings Account Contract with Tiered Interest

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-lock-in-effect (err u103))
(define-constant err-invalid-tier (err u104))

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

(define-map balance-tiers
  uint  ;; tier threshold
  uint  ;; tier multiplier (basis points, 10000 = 1x)
)

;; Original contract functions remain unchanged...

;; New functions for tiered interest system

;; Set balance tier multiplier
(define-public (set-balance-tier (threshold uint) (multiplier uint))
  (if (is-eq tx-sender contract-owner)
    (begin
      (map-set balance-tiers threshold multiplier)
      (ok true)
    )
    err-owner-only
  )
)

;; Get tier multiplier for a balance
(define-read-only (get-tier-multiplier (balance uint))
  (let ((highest-tier (fold get-highest-applicable-tier (map-keys balance-tiers) u0)))
    (default-to u10000 (map-get? balance-tiers highest-tier))
  )
)

;; Helper to find highest applicable tier
(define-private (get-highest-applicable-tier (threshold uint) (current-highest uint))
  (if (and (>= threshold current-highest) (<= threshold balance))
    threshold
    current-highest
  )
)

;; Modified interest calculation including tiers
(define-public (pay-interest (user principal))
  (let (
    (account (unwrap! (get-account user) err-not-found))
    (balance (get balance account))
    (base-rate (get interest-rate account))
    (tier-mult (get-tier-multiplier balance))
    (lock-end (get lock-end account))
  )
    (if (<= lock-end block-height)
      (let (
        (interest (/ (* (* balance base-rate) tier-mult) u100000000))
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
