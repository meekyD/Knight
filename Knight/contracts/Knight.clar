;; Medieval Kingdom Defense Contract
;; Deploy knights to defend the realm and earn glory tokens
(define-fungible-token glory-coin)
(define-constant KING tx-sender)

;; Error Codes
(define-constant ERR-NOT-KING (err u101))
(define-constant ERR-INVALID-KNIGHTS (err u102))
(define-constant ERR-NO-KNIGHTS-DEPLOYED (err u103))
(define-constant ERR-FORTRESS-NOT-FOUND (err u104))
(define-constant ERR-FORTRESS-INACTIVE (err u105))
(define-constant ERR-INVALID-DANGER-LEVEL (err u106))
(define-constant ERR-INVALID-GLORY-MULTIPLIER (err u107))
(define-constant ERR-FORTRESS-ID-TOO-HIGH (err u108))
(define-constant ERR-EMPTY-NAME (err u109))

;; Constants for validation
(define-constant MAX-DANGER-LEVEL u10)
(define-constant MIN-GLORY-MULTIPLIER u50)
(define-constant MAX-GLORY-MULTIPLIER u500)
(define-constant MAX-FORTRESS-ID u1000)

;; Kingdom Variables
(define-data-var siege-mode bool false)
(define-data-var retreat-penalty uint u15) ;; 15% penalty for cowardly retreat
(define-data-var glory-per-battle uint u8)
(define-data-var total-defenders uint u0)
(define-data-var fortress-count uint u0)

;; Data Maps
(define-map fortresses
  { fortress-id: uint }
  { name: (string-ascii 20), danger-level: uint, glory-multiplier: uint, defenders: uint, active: bool }
)

(define-map knight-deployments
  { knight: principal, fortress-id: uint }
  { knights-deployed: uint, last-battle-block: uint }
)

;; Initialize the kingdom
(define-public (establish-kingdom)
  (begin
    (try! (ft-mint? glory-coin u500000 KING))
    (try! (build-fortress "Archer Tower" u2 u90))
    (try! (build-fortress "Knight Barracks" u5 u130))
    (try! (build-fortress "Dragon Lair" u8 u180))
    (ok true)
  )
)

;; Build a new fortress with input validation
(define-public (build-fortress (name (string-ascii 20)) (danger uint) (glory-mult uint))
  (begin
    (asserts! (is-eq tx-sender KING) ERR-NOT-KING)
    ;; Validate fortress name is not empty
    (asserts! (> (len name) u0) ERR-EMPTY-NAME)
    ;; Validate danger level is reasonable
    (asserts! (<= danger MAX-DANGER-LEVEL) ERR-INVALID-DANGER-LEVEL)
    ;; Validate glory multiplier is within bounds
    (asserts! (and (>= glory-mult MIN-GLORY-MULTIPLIER) 
                   (<= glory-mult MAX-GLORY-MULTIPLIER)) ERR-INVALID-GLORY-MULTIPLIER)
    
    (let ((new-id (var-get fortress-count)))
      (map-set fortresses { fortress-id: new-id }
        { name: name, danger-level: danger, glory-multiplier: glory-mult, defenders: u0, active: true })
      (var-set fortress-count (+ new-id u1))
      (ok new-id)
    )
  )
)

;; Deploy knights to defend fortress with input validation
(define-public (deploy-knights (fortress-id uint) (knight-count uint))
  (begin
    (asserts! (> knight-count u0) ERR-INVALID-KNIGHTS)
    ;; Validate fortress-id is within reasonable bounds
    (asserts! (< fortress-id MAX-FORTRESS-ID) ERR-FORTRESS-ID-TOO-HIGH)
    ;; Validate fortress exists before proceeding
    (let ((fortress (unwrap! (map-get? fortresses { fortress-id: fortress-id }) ERR-FORTRESS-NOT-FOUND)))
      (asserts! (get active fortress) ERR-FORTRESS-INACTIVE)
      (try! (ft-transfer? glory-coin knight-count tx-sender (as-contract tx-sender)))
      (let ((existing (default-to { knights-deployed: u0, last-battle-block: stacks-block-height }
              (map-get? knight-deployments { knight: tx-sender, fortress-id: fortress-id }))))
        (if (> (get knights-deployed existing) u0)
          (try! (award-glory tx-sender (calculate-glory-earned tx-sender fortress-id)))
          true)
        (map-set knight-deployments { knight: tx-sender, fortress-id: fortress-id }
          { knights-deployed: (+ (get knights-deployed existing) knight-count), 
            last-battle-block: stacks-block-height })
        (map-set fortresses { fortress-id: fortress-id } 
          (merge fortress { defenders: (+ (get defenders fortress) knight-count) }))
        (var-set total-defenders (+ (var-get total-defenders) knight-count))
        (ok true)
      )
    )
  )
)

;; Withdraw knights from fortress with input validation
(define-public (withdraw-knights (fortress-id uint) (knight-count uint))
  (begin
    ;; Validate fortress-id is within reasonable bounds
    (asserts! (< fortress-id MAX-FORTRESS-ID) ERR-FORTRESS-ID-TOO-HIGH)
    (let ((deployment (unwrap! (map-get? knight-deployments { knight: tx-sender, fortress-id: fortress-id }) ERR-NO-KNIGHTS-DEPLOYED))
          (fortress (unwrap! (map-get? fortresses { fortress-id: fortress-id }) ERR-FORTRESS-NOT-FOUND)))
      (asserts! (<= knight-count (get knights-deployed deployment)) ERR-INVALID-KNIGHTS)
      (try! (award-glory tx-sender (calculate-glory-earned tx-sender fortress-id)))
      (try! (as-contract (ft-transfer? glory-coin knight-count tx-sender tx-sender)))
      (map-set knight-deployments { knight: tx-sender, fortress-id: fortress-id }
        { knights-deployed: (- (get knights-deployed deployment) knight-count), 
          last-battle-block: stacks-block-height })
      (ok true)
    )
  )
)

;; Emergency retreat during siege with input validation
(define-public (emergency-retreat (fortress-id uint))
  (begin
    (asserts! (var-get siege-mode) ERR-NOT-KING)
    ;; Validate fortress-id is within reasonable bounds
    (asserts! (< fortress-id MAX-FORTRESS-ID) ERR-FORTRESS-ID-TOO-HIGH)
    (let ((deployment (unwrap! (map-get? knight-deployments { knight: tx-sender, fortress-id: fortress-id }) ERR-NO-KNIGHTS-DEPLOYED))
          (knights (get knights-deployed deployment))
          (penalty (/ (* knights (var-get retreat-penalty)) u100)))
      (try! (as-contract (ft-transfer? glory-coin (- knights penalty) tx-sender tx-sender)))
      (map-delete knight-deployments { knight: tx-sender, fortress-id: fortress-id })
      (ok (- knights penalty))
    )
  )
)

;; Calculate glory earned from battles with safer input handling
(define-private (calculate-glory-earned (knight principal) (fortress-id uint))
  (let ((deployment-opt (map-get? knight-deployments { knight: knight, fortress-id: fortress-id }))
        (fortress-opt (map-get? fortresses { fortress-id: fortress-id })))
    (match deployment-opt
      deployment (match fortress-opt
                   fortress (let ((battles-fought (- stacks-block-height (get last-battle-block deployment)))
                                 (deployed-knights (get knights-deployed deployment))
                                 (total-fortress-defenders (get defenders fortress))
                                 (glory-mult (get glory-multiplier fortress)))
                             ;; Prevent division by zero
                             (if (is-eq total-fortress-defenders u0)
                               u0
                               (/ (* deployed-knights battles-fought (var-get glory-per-battle) glory-mult)
                                  (* total-fortress-defenders u100))))
                   u0)
      u0)
  )
)

(define-private (award-glory (knight principal) (glory-amount uint))
  (ft-mint? glory-coin glory-amount knight)
)

;; Admin functions
(define-public (declare-siege (active bool))
  (begin
    (asserts! (is-eq tx-sender KING) ERR-NOT-KING)
    (var-set siege-mode active)
    (ok active)
  )
)

;; Read-only functions with input validation
(define-read-only (get-knight-deployment (knight principal) (fortress-id uint))
  (begin
    ;; Validate fortress-id for read operations too
    (asserts! (< fortress-id MAX-FORTRESS-ID) ERR-FORTRESS-ID-TOO-HIGH)
    (ok (default-to { knights-deployed: u0, last-battle-block: u0 }
          (map-get? knight-deployments { knight: knight, fortress-id: fortress-id })))
  )
)

(define-read-only (get-fortress-info (fortress-id uint))
  (begin
    ;; Validate fortress-id for read operations
    (asserts! (< fortress-id MAX-FORTRESS-ID) ERR-FORTRESS-ID-TOO-HIGH)
    (ok (map-get? fortresses { fortress-id: fortress-id }))
  )
)

(define-read-only (get-kingdom-stats)
  (ok { total-defenders: (var-get total-defenders), 
        siege-mode: (var-get siege-mode),
        fortress-count: (var-get fortress-count) })
)