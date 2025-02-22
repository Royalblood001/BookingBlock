;; Talent Agency Smart Contract for Artist Bookings

;; Constants for validation
(define-constant MIN-BOOKING-BLOCKS u144)  ;; Minimum 1 day
(define-constant MAX-BOOKING-BLOCKS u14400)  ;; Maximum 100 days
(define-constant MIN-PERFORMANCE-FEE u1000)  ;; Minimum booking fee
(define-constant MAX-PERFORMANCE-FEE u100000000000)  ;; Maximum booking fee

;; Core Constants
(define-constant contract-owner tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-ALREADY-INITIALIZED (err u102))
(define-constant ERR-NOT-INITIALIZED (err u103))
(define-constant ERR-ALREADY-BOOKED (err u104))
(define-constant ERR-NOT-BOOKED (err u105))
(define-constant ERR-ALREADY-PERFORMED (err u106))
(define-constant ERR-INVALID-FEE (err u107))
(define-constant ERR-COMMISSION-TOO-HIGH (err u108))
(define-constant ERR-NOT-DISPUTED (err u109))
(define-constant ERR-BOOKING-NOT-EXPIRED (err u110))
(define-constant ERR-INVALID-STATUS-FOR-REVIEW (err u111))
(define-constant ERR-INVALID-REVIEW (err u112))
(define-constant ERR-BOOKINGS-FULL (err u113))
(define-constant ERR-INVALID-DURATION (err u114))
(define-constant ERR-INVALID-PARTIES (err u115))
(define-constant ERR-FEE-OUT-OF-RANGE (err u116))
(define-constant ERR-INVALID-ID (err u117))

;; Data Variables
(define-data-var commission-rate uint u100) ;; 10% commission
(define-data-var next-booking-id uint u0)
(define-data-var booking-duration uint u1440) ;; Default duration

;; Data Maps
(define-map bookings
  { id: uint }
  {
    artist: principal,
    venue: principal,
    agent: principal,
    performance-fee: uint,
    commission: uint,
    status: (string-ascii 20),
    booking-date: uint,
    review-score: (optional uint)
  }
)

(define-map user-bookings
  principal
  (list 100 uint)
)

;; Validation Functions
(define-private (is-valid-duration (blocks uint))
  (and (>= blocks MIN-BOOKING-BLOCKS)
       (<= blocks MAX-BOOKING-BLOCKS))
)

(define-private (is-valid-fee (fee uint))
  (and (>= fee MIN-PERFORMANCE-FEE)
       (<= fee MAX-PERFORMANCE-FEE))
)

(define-private (are-valid-parties (artist principal) (venue principal) (agent principal))
  (and
    (not (is-eq artist venue))
    (not (is-eq artist agent))
    (not (is-eq venue agent))
  )
)

(define-private (is-valid-booking-id (id uint))
  (< id (var-get next-booking-id))
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

(define-private (add-booking-to-user (user principal) (id uint))
  (let
    (
      (user-booking-list (default-to (list) (map-get? user-bookings user)))
    )
    (if (< (len user-booking-list) u100)
      (ok (map-set user-bookings 
                   user 
                   (unwrap! (as-max-len? (concat user-booking-list (list id)) u100) ERR-BOOKINGS-FULL)))
      ERR-BOOKINGS-FULL
    )
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

(define-read-only (get-user-bookings (user principal))
  (default-to (list) (map-get? user-bookings user))
)

(define-read-only (get-duration)
  (ok (var-get booking-duration))
)

;; Public Functions
(define-public (set-commission-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
    (asserts! (< new-rate u1000) ERR-COMMISSION-TOO-HIGH)
    (ok (var-set commission-rate new-rate))
  )
)

(define-public (set-duration (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-OWNER-ONLY)
    (asserts! (is-valid-duration new-duration) ERR-INVALID-DURATION)
    (ok (var-set booking-duration new-duration))
  )
)

(define-public (create-booking (artist principal) (venue principal) (agent principal) (fee uint))
  (begin
    (asserts! (are-valid-parties artist venue agent) ERR-INVALID-PARTIES)
    (asserts! (is-valid-fee fee) ERR-FEE-OUT-OF-RANGE)
    (let
      (
        (id (var-get next-booking-id))
        (commission (calculate-commission fee))
        (total-fee (+ fee commission))
      )
      (asserts! (> fee u0) ERR-INVALID-FEE)
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
          status: "booked",
          booking-date: block-height,
          review-score: none
        }
      )
      (var-set next-booking-id (+ id u1))
      (try! (add-booking-to-user artist id))
      (try! (add-booking-to-user venue id))
      (try! (add-booking-to-user agent id))
      (ok id)
    )
  )
)

(define-public (pay-artist (id uint))
  (begin
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
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
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
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

(define-public (raise-dispute (id uint))
  (begin
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
      )
      (asserts! (or (is-eq tx-sender (get venue booking)) (is-eq tx-sender (get artist booking))) ERR-UNAUTHORIZED)
      (asserts! (is-eq status "booked") ERR-NOT-BOOKED)
      (map-set bookings
        { id: id }
        (merge booking { status: "disputed" })
      )
      (ok true)
    )
  )
)

(define-public (resolve-dispute (id uint) (pay-to-artist bool))
  (begin
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
      )
      (asserts! (is-eq tx-sender (get agent booking)) ERR-UNAUTHORIZED)
      (asserts! (is-eq status "disputed") ERR-NOT-DISPUTED)
      (if pay-to-artist
        (begin
          (try! (as-contract (transfer-tokens (get artist booking) (get performance-fee booking))))
          (try! (as-contract (transfer-tokens contract-owner (get commission booking))))
        )
        (try! (as-contract (transfer-tokens (get venue booking) (+ (get performance-fee booking) (get commission booking)))))
      )
      (map-set bookings
        { id: id }
        (merge booking { status: "resolved" })
      )
      (ok true)
    )
  )
)

(define-public (cancel-booking (id uint))
  (begin
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
        (booking-date (get booking-date booking))
      )
      (asserts! (is-eq tx-sender (get venue booking)) ERR-UNAUTHORIZED)
      (asserts! (is-eq status "booked") ERR-NOT-BOOKED)
      (asserts! (> block-height (+ booking-date (var-get booking-duration))) ERR-BOOKING-NOT-EXPIRED)
      (try! (as-contract (transfer-tokens (get venue booking) (+ (get performance-fee booking) (get commission booking)))))
      (map-set bookings
        { id: id }
        (merge booking { status: "cancelled" })
      )
      (ok true)
    )
  )
)

(define-public (extend-booking (id uint) (extension uint))
  (begin
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
      )
      (asserts! (or (is-eq tx-sender (get venue booking)) (is-eq tx-sender (get artist booking))) ERR-UNAUTHORIZED)
      (asserts! (is-eq status "booked") ERR-NOT-BOOKED)
      (map-set bookings
        { id: id }
        (merge booking { booking-date: (+ block-height extension) })
      )
      (ok true)
    )
  )
)

(define-public (leave-review (id uint) (score uint))
  (begin
    (asserts! (is-valid-booking-id id) ERR-INVALID-ID)
    (let
      (
        (booking (unwrap! (map-get? bookings { id: id }) ERR-NOT-INITIALIZED))
        (status (get status booking))
      )
      (asserts! (or (is-eq tx-sender (get venue booking)) (is-eq tx-sender (get artist booking))) ERR-UNAUTHORIZED)
      (asserts! (or (is-eq status "performed") (is-eq status "cancelled") (is-eq status "resolved")) ERR-INVALID-STATUS-FOR-REVIEW)
      (asserts! (<= score u5) ERR-INVALID-REVIEW)
      (map-set bookings
        { id: id }
        (merge booking { review-score: (some score) })
      )
      (ok true)
    )
  )
)