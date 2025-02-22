;; Talent Agency Smart Contract - Version 1.0
;; Basic booking functionality with core safety features

;; Constants for validation
(define-constant MIN-PERFORMANCE-FEE u1000)
(define-constant MAX-PERFORMANCE-FEE u100000000000)

;; Core Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-NOT-INITIALIZED (err u103))
(define-constant ERR-ALREADY-BOOKED (err u104))
(define-constant ERR-NOT-BOOKED (err u105))
(define-constant ERR-INVALID-FEE (err u107))
(define-constant ERR-INVALID-ID (err u117))

;; Data Variables
(define-data-var commission-rate uint u100) ;; 10% commission
(define-data-var next-booking-id uint u0)

;; Data Maps
(define-map bookings
  { id: uint }
  {
    artist: principal,
    venue: principal,
    agent: principal,
    performance-fee: uint,
    commission: uint,
    status: (string-ascii 20)
  }
)

;; Private Functions
(define-private (calculate-commission (fee uint))
  (/ (* fee (var-get commission-rate)) u1000)
)

(define-private (transfer-tokens (recipient principal) (amount uint))
  (if (> amount u0)
    (stx-transfer? amount tx-sender recipient)
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-booking (id uint))
  (match (map-get? bookings { id: id })
    entry (ok entry)
    (err u404)
  )
)

(define-read-only (get-booking-status (id uint))
  (match (map-get? bookings { id: id })
    entry (ok (get status entry))
    (err u404)
  )
)

;; Public Functions
(define-public (create-booking (artist principal) (venue principal) (agent principal) (fee uint))
  (begin
    (asserts! (> fee MIN-PERFORMANCE-FEE) ERR-INVALID-FEE)
    (asserts! (< fee MAX-PERFORMANCE-FEE) ERR-INVALID-FEE)
    (let
      (
        (id (var-get next-booking-id))
        (commission (calculate-commission fee))
        (total-fee (+ fee commission))
      )
      (asserts! (is-eq tx-sender venue) ERR-UNAUTHORIZED)
      (try! (stx-transfer? total-fee tx-sender (as-contract tx-sender)))
      (map-set bookings
        { id: id }
        {
          artist: artist,
          venue: venue,
          agent: agent,
          performance-fee: fee,
          commission: commission,
          status: "booked"
        }
      )
      (var-set next-booking-id (+ id u1))
      (ok id)
    )
  )
)

(define-public (pay-artist (id uint))
  (begin
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
      )
      (asserts! (or (is-eq tx-sender (get venue booking)) (is-eq tx-sender (get agent booking))) ERR-UNAUTHORIZED)
      (asserts! (is-eq status "booked") ERR-NOT-BOOKED)
      (try! (as-contract (transfer-tokens (get artist booking) (get performance-fee booking))))
      (try! (as-contract (transfer-tokens contract-owner (get commission booking))))
      (map-set bookings
        { id: id }
        (merge booking { status: "performed" })
      )
      (ok true)
    )
  )
)

(define-public (refund-venue (id uint))
  (begin
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
      )
      (asserts! (or (is-eq tx-sender (get artist booking)) (is-eq tx-sender (get agent booking))) ERR-UNAUTHORIZED)
      (asserts! (is-eq status "booked") ERR-NOT-BOOKED)
      (try! (as-contract (transfer-tokens (get venue booking) (+ (get performance-fee booking) (get commission booking)))))
      (map-set bookings
        { id: id }
        (merge booking { status: "cancelled" })
      )
      (ok true)
    )
  )
)