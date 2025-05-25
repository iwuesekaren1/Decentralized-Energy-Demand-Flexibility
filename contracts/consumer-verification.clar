;; Consumer Verification Contract
;; Validates energy users and manages their registration status

(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_NOT_REGISTERED (err u102))
(define-constant ERR_INVALID_DATA (err u103))

(define-data-var contract-owner principal tx-sender)

;; Consumer data structure
(define-map consumers
  { consumer-id: principal }
  {
    verified: bool,
    registration-date: uint,
    energy-capacity: uint,
    location: (string-ascii 50),
    consumer-type: (string-ascii 20)
  }
)

;; Verification status tracking
(define-map verification-requests
  { consumer-id: principal }
  {
    status: (string-ascii 20),
    requested-at: uint,
    verified-at: (optional uint)
  }
)

;; Register a new consumer
(define-public (register-consumer (capacity uint) (location (string-ascii 50)) (consumer-type (string-ascii 20)))
  (let ((consumer-id tx-sender))
    (asserts! (is-none (map-get? consumers { consumer-id: consumer-id })) ERR_ALREADY_REGISTERED)
    (asserts! (> capacity u0) ERR_INVALID_DATA)

    (map-set consumers
      { consumer-id: consumer-id }
      {
        verified: false,
        registration-date: block-height,
        energy-capacity: capacity,
        location: location,
        consumer-type: consumer-type
      }
    )

    (map-set verification-requests
      { consumer-id: consumer-id }
      {
        status: "pending",
        requested-at: block-height,
        verified-at: none
      }
    )

    (ok consumer-id)
  )
)

;; Verify a consumer (only contract owner)
(define-public (verify-consumer (consumer-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? consumers { consumer-id: consumer-id })) ERR_NOT_REGISTERED)

    (map-set consumers
      { consumer-id: consumer-id }
      (merge (unwrap-panic (map-get? consumers { consumer-id: consumer-id }))
             { verified: true })
    )

    (map-set verification-requests
      { consumer-id: consumer-id }
      (merge (unwrap-panic (map-get? verification-requests { consumer-id: consumer-id }))
             { status: "verified", verified-at: (some block-height) })
    )

    (ok true)
  )
)

;; Check if consumer is verified
(define-read-only (is-verified (consumer-id principal))
  (match (map-get? consumers { consumer-id: consumer-id })
    consumer-data (get verified consumer-data)
    false
  )
)

;; Get consumer details
(define-read-only (get-consumer (consumer-id principal))
  (map-get? consumers { consumer-id: consumer-id })
)

;; Get verification status
(define-read-only (get-verification-status (consumer-id principal))
  (map-get? verification-requests { consumer-id: consumer-id })
)
