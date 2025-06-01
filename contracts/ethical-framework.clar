;; Ethical Framework Contract
;; Ensures conscious robotics ethics and compliance

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_ETHICAL_VIOLATION (err u402))
(define-constant ERR_INVALID_PRINCIPLE (err u403))

;; Ethical principles
(define-constant PRINCIPLE_HUMAN_DIGNITY u1)
(define-constant PRINCIPLE_AUTONOMY u2)
(define-constant PRINCIPLE_BENEFICENCE u3)
(define-constant PRINCIPLE_NON_MALEFICENCE u4)
(define-constant PRINCIPLE_JUSTICE u5)
(define-constant PRINCIPLE_TRANSPARENCY u6)

;; Violation severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

;; Data structures
(define-map robot-ethics
  { robot-id: (string-ascii 64) }
  {
    compliance-score: uint,
    total-evaluations: uint,
    violations-count: uint,
    last-evaluation: uint,
    is-compliant: bool
  }
)

(define-map ethical-violations
  { robot-id: (string-ascii 64), violation-id: uint }
  {
    principle-violated: uint,
    severity: uint,
    description: (string-ascii 256),
    timestamp: uint,
    resolved: bool
  }
)

(define-map ethical-evaluations
  { robot-id: (string-ascii 64), evaluation-id: uint }
  {
    evaluator: principal,
    principles-scores: (list 6 uint),
    overall-score: uint,
    timestamp: uint,
    notes: (string-ascii 256)
  }
)

(define-data-var violation-counter uint u0)
(define-data-var evaluation-counter uint u0)

;; Public functions
(define-public (initialize-ethical-framework (robot-id (string-ascii 64)))
  (begin
    (map-set robot-ethics
      {robot-id: robot-id}
      {
        compliance-score: u100,
        total-evaluations: u0,
        violations-count: u0,
        last-evaluation: block-height,
        is-compliant: true
      }
    )
    (ok true)
  )
)

(define-public (conduct-ethical-evaluation (robot-id (string-ascii 64))
                                          (principles-scores (list 6 uint))
                                          (notes (string-ascii 256)))
  (let ((ethics-data (map-get? robot-ethics {robot-id: robot-id})))
    (asserts! (is-some ethics-data) ERR_NOT_FOUND)

    (let ((evaluation-id (var-get evaluation-counter))
          (overall-score (calculate-overall-score principles-scores))
          (current-ethics (unwrap-panic ethics-data)))

      ;; Record evaluation
      (map-set ethical-evaluations
        {robot-id: robot-id, evaluation-id: evaluation-id}
        {
          evaluator: tx-sender,
          principles-scores: principles-scores,
          overall-score: overall-score,
          timestamp: block-height,
          notes: notes
        }
      )

      ;; Update ethics record
      (let ((new-compliance-score (calculate-weighted-compliance
                                   (get compliance-score current-ethics)
                                   overall-score)))
        (map-set robot-ethics
          {robot-id: robot-id}
          (merge current-ethics {
            compliance-score: new-compliance-score,
            total-evaluations: (+ (get total-evaluations current-ethics) u1),
            last-evaluation: block-height,
            is-compliant: (>= new-compliance-score u70)
          })
        )
      )

      (var-set evaluation-counter (+ evaluation-id u1))
      (ok true)
    )
  )
)

(define-public (report-ethical-violation (robot-id (string-ascii 64))
                                        (principle-violated uint)
                                        (severity uint)
                                        (description (string-ascii 256)))
  (let ((ethics-data (map-get? robot-ethics {robot-id: robot-id})))
    (asserts! (is-some ethics-data) ERR_NOT_FOUND)
    (asserts! (>= principle-violated u1) ERR_INVALID_PRINCIPLE)
    (asserts! (<= principle-violated u6) ERR_INVALID_PRINCIPLE)
    (asserts! (>= severity u1) ERR_INVALID_PRINCIPLE)
    (asserts! (<= severity u4) ERR_INVALID_PRINCIPLE)

    (let ((violation-id (var-get violation-counter))
          (current-ethics (unwrap-panic ethics-data)))

      ;; Record violation
      (map-set ethical-violations
        {robot-id: robot-id, violation-id: violation-id}
        {
          principle-violated: principle-violated,
          severity: severity,
          description: description,
          timestamp: block-height,
          resolved: false
        }
      )

      ;; Update ethics record
      (let ((penalty (calculate-violation-penalty severity))
            (new-score (if (>= (get compliance-score current-ethics) penalty)
                         (- (get compliance-score current-ethics) penalty)
                         u0)))
        (map-set robot-ethics
          {robot-id: robot-id}
          (merge current-ethics {
            compliance-score: new-score,
            violations-count: (+ (get violations-count current-ethics) u1),
            is-compliant: (>= new-score u70)
          })
        )
      )

      (var-set violation-counter (+ violation-id u1))
      (ok true)
    )
  )
)

(define-public (resolve-violation (robot-id (string-ascii 64)) (violation-id uint))
  (begin
    (asserts! (is-some (map-get? ethical-violations {robot-id: robot-id, violation-id: violation-id})) ERR_NOT_FOUND)

    (map-set ethical-violations
      {robot-id: robot-id, violation-id: violation-id}
      (merge (unwrap-panic (map-get? ethical-violations {robot-id: robot-id, violation-id: violation-id}))
             {resolved: true})
    )
    (ok true)
  )
)

;; Private functions
(define-private (calculate-overall-score (scores (list 6 uint)))
  (/ (fold + scores u0) u6)
)

(define-private (calculate-weighted-compliance (current-score uint) (new-score uint))
  (/ (+ (* current-score u4) new-score) u5)
)

(define-private (calculate-violation-penalty (severity uint))
  (if (is-eq severity SEVERITY_LOW) u5
    (if (is-eq severity SEVERITY_MEDIUM) u15
      (if (is-eq severity SEVERITY_HIGH) u30
        u50))))

;; Read-only functions
(define-read-only (get-ethical-status (robot-id (string-ascii 64)))
  (map-get? robot-ethics {robot-id: robot-id})
)

(define-read-only (get-violation (robot-id (string-ascii 64)) (violation-id uint))
  (map-get? ethical-violations {robot-id: robot-id, violation-id: violation-id})
)

(define-read-only (get-evaluation (robot-id (string-ascii 64)) (evaluation-id uint))
  (map-get? ethical-evaluations {robot-id: robot-id, evaluation-id: evaluation-id})
)

(define-read-only (is-ethically-compliant (robot-id (string-ascii 64)))
  (match (map-get? robot-ethics {robot-id: robot-id})
    ethics-data (get is-compliant ethics-data)
    false
  )
)
