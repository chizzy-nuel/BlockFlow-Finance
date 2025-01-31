;; BlockFlow Finance - Decentralized P2P Lending Protocol
;; A decentralized lending platform on Stacks blockchain for STX lending

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-LOW-BALANCE (err u101))
(define-constant ERR-NO-CREDIT-LINE (err u102))
(define-constant ERR-CREDIT-LINE-EXISTS (err u103))
(define-constant ERR-LOW-COLLATERAL (err u104))
(define-constant ERR-NOT-MATURED (err u105))
(define-constant ERR-IN-DEFAULT (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))
(define-constant ERR-SMALL-PAYMENT (err u108))
(define-constant ERR-HEALTHY-POSITION (err u109))

;; Constants
(define-constant DAILY-BLOCKS u144) ;; Approximate number of blocks per day
(define-constant DEFAULT-FEE-RATE u10) ;; 10% fee rate for late payments
(define-constant MARGIN-CALL-RATIO u130) ;; 130% minimum collateral ratio before liquidation

;; Status constants
(define-constant STATE-OPEN "OPEN")
(define-constant STATE-FUNDED "FUNDED")
(define-constant STATE-COMPLETED "COMPLETED")
(define-constant STATE-SEIZED "SEIZED")
(define-constant STATE-FAILED "FAILED")

;; Data variables
(define-data-var safety-margin uint u150) ;; 150% collateralization ratio
(define-data-var protocol-admin principal tx-sender)

;; Credit line data structure
(define-map credit-lines
    {position-id: uint}
    {
        debtor: principal,
        creditor: (optional principal),
        credit-amount: uint,
        security-deposit: uint,
        rate: uint,
        term-length: uint,
        inception-block: uint,
        last-activity-block: uint,
        payment-frequency: uint,
        installment-size: uint,
        outstanding-balance: uint,
        state: (string-ascii 20)
    }
)

;; Repayment tracking
(define-map repayment-tracking
    {position-id: uint}
    {
        next-due-block: uint,
        skipped-payments: uint,
        total-fees: uint
    }
)

;; Protocol state variables
(define-data-var position-counter uint u1)
(define-data-var total-deposits uint u0)

;; Read-only functions
(define-read-only (get-position (position-id uint))
    (map-get? credit-lines {position-id: position-id})
)

(define-read-only (get-payment-info (position-id uint))
    (map-get? repayment-tracking {position-id: position-id})
)

(define-read-only (calculate-security-ratio (security uint) (debt uint))
    (let
        (
            (ratio (* (/ security debt) u100))
        )
        ratio
    )
)

(define-read-only (get-position-health (position-id uint))
    (let
        (
            (position (unwrap! (get-position position-id) u0))
            (ratio (calculate-security-ratio (get security-deposit position) (get outstanding-balance position)))
        )
        ratio
    )
)

(define-read-only (needs-liquidation (position-id uint))
    (let
        (
            (current-ratio (get-position-health position-id))
        )
        (< current-ratio MARGIN-CALL-RATIO)
    )
)

;; Private functions
(define-private (calculate-fee (payment uint))
    (/ (* payment DEFAULT-FEE-RATE) u100)
)

(define-private (init-payment-schedule (position-id uint) (start-block uint) (interval uint))
    (begin
        (map-set repayment-tracking
            {position-id: position-id}
            {
                next-due-block: (+ start-block interval),
                skipped-payments: u0,
                total-fees: u0
            }
        )
        true
    )
)

;; Public functions
(define-public (open-credit-line (amount uint) (security uint) (rate uint) (term uint) (frequency uint))
    (let
        (
            (position-id (var-get position-counter))
            (security-ratio (calculate-security-ratio security amount))
            (payment (/ (+ amount (* amount rate)) term))
        )
        (asserts! (>= security-ratio (var-get safety-margin)) ERR-LOW-COLLATERAL)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (try! (stx-transfer? security tx-sender (as-contract tx-sender)))
        
        (var-set total-deposits (+ (var-get total-deposits) security))
        
        (map-set credit-lines
            {position-id: position-id}
            {
                debtor: tx-sender,
                creditor: none,
                credit-amount: amount,
                security-deposit: security,
                rate: rate,
                term-length: term,
                inception-block: u0,
                last-activity-block: u0,
                payment-frequency: frequency,
                installment-size: payment,
                outstanding-balance: amount,
                state: STATE-OPEN
            }
        )
        (var-set position-counter (+ position-id u1))
        (ok position-id)
    )
)

(define-public (fund-position (position-id uint))
    (let
        (
            (position (unwrap! (get-position position-id) ERR-NO-CREDIT-LINE))
            (amount (get credit-amount position))
        )
        (asserts! (is-eq (get state position) STATE-OPEN) ERR-CREDIT-LINE-EXISTS)
        (try! (stx-transfer? amount tx-sender (get debtor position)))
        
        (map-set credit-lines
            {position-id: position-id}
            (merge position {
                creditor: (some tx-sender),
                inception-block: block-height,
                last-activity-block: block-height,
                state: STATE-FUNDED
            })
        )
        
        (asserts! (init-payment-schedule position-id block-height (get payment-frequency position)) ERR-NO-CREDIT-LINE)
        
        (ok true)
    )
)

(define-public (process-payment (position-id uint))
    (let
        (
            (position (unwrap! (get-position position-id) ERR-NO-CREDIT-LINE))
            (schedule (unwrap! (get-payment-info position-id) ERR-NO-CREDIT-LINE))
            (payment (get installment-size position))
            (creditor (unwrap! (get creditor position) ERR-NO-CREDIT-LINE))
            (fee (if (>= block-height (get next-due-block schedule))
                    (calculate-fee payment)
                    u0))
            (total-due (+ payment fee))
        )
        (asserts! (is-eq (get state position) STATE-FUNDED) ERR-NO-CREDIT-LINE)
        (asserts! (is-eq (get debtor position) tx-sender) ERR-UNAUTHORIZED)
        
        (try! (stx-transfer? total-due tx-sender creditor))
        
        (map-set credit-lines
            {position-id: position-id}
            (merge position {
                last-activity-block: block-height,
                outstanding-balance: (- (get outstanding-balance position) payment)
            })
        )
        
        (map-set repayment-tracking
            {position-id: position-id}
            (merge schedule {
                next-due-block: (+ block-height (get payment-frequency position)),
                total-fees: (+ (get total-fees schedule) fee)
            })
        )
        
        (ok true)
    )
)

(define-public (liquidate-position (position-id uint))
    (let
        (
            (position (unwrap! (get-position position-id) ERR-NO-CREDIT-LINE))
            (schedule (unwrap! (get-payment-info position-id) ERR-NO-CREDIT-LINE))
            (creditor (unwrap! (get creditor position) ERR-NO-CREDIT-LINE))
            (requires-liquidation (needs-liquidation position-id))
        )
        (asserts! requires-liquidation ERR-HEALTHY-POSITION)
        
        (as-contract
            (try! (stx-transfer? (get security-deposit position) creditor tx-sender))
        )
        
        (var-set total-deposits (- (var-get total-deposits) (get security-deposit position)))
        
        (map-set credit-lines
            {position-id: position-id}
            (merge position {
                state: STATE-SEIZED
            })
        )
        
        (ok true)
    )
)

;; Admin functions
(define-public (update-safety-margin (new-margin uint))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-UNAUTHORIZED)
        (var-set safety-margin new-margin)
        (ok true)
    )
)

(define-public (change-admin (new-admin principal))
    (begin
        (asserts! (is-eq tx-sender (var-get protocol-admin)) ERR-UNAUTHORIZED)
        (var-set protocol-admin new-admin)
        (ok true)
    )
)