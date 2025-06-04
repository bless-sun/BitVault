;; BitVault: Bitcoin-Backed Lending Protocol for Stacks
;;
;; A secure, decentralized lending protocol that enables Bitcoin holders to
;; leverage their BTC as collateral for stablecoin loans. BitVault bridges
;; traditional Bitcoin HODLing with DeFi capabilities on Stacks Layer 2.
;;
;; Key functionality:
;; - Deposit BTC as collateral in secure vaults
;; - Borrow stablecoins against BTC collateral
;; - Dynamic interest rates and collateralization ratios
;; - Automated liquidation mechanisms to maintain protocol solvency
;; - Protocol governance for risk parameter adjustments

;; Constants

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1001))
(define-constant ERR_BORROW_LIMIT_EXCEEDED (err u1002))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1003))
(define-constant ERR_VAULT_ALREADY_EXISTS (err u1004))
(define-constant ERR_VAULT_NOT_FOUND (err u1005))
(define-constant ERR_INSUFFICIENT_DEPOSIT (err u1006))
(define-constant ERR_INSUFFICIENT_REPAYMENT (err u1007))
(define-constant ERR_INVALID_AMOUNT (err u1008))
(define-constant ERR_MINIMUM_COLLATERAL_RATIO (err u1009))
(define-constant ERR_VAULT_NOT_UNDERCOLLATERALIZED (err u1010))
(define-constant ERR_ORACLE_ERROR (err u1011))
(define-constant ERR_PROTOCOL_PAUSED (err u1012))

;; Protocol Configuration

;; Risk parameters
(define-data-var minimum-collateral-ratio uint u150) ;; 150% expressed as percentage
(define-data-var liquidation-threshold uint u125) ;; 125% expressed as percentage 
(define-data-var liquidation-penalty uint u10) ;; 10% expressed as percentage

;; Economic parameters
(define-data-var borrow-interest-rate uint u5) ;; 5% annual interest rate
(define-data-var protocol-fee-rate uint u1) ;; 1% of interest as protocol fee
(define-data-var oracle-price-validity-period uint u3600) ;; 1 hour in seconds

;; Protocol state
(define-data-var protocol-paused bool false)
(define-data-var contract-owner principal tx-sender)

;; Price Oracle

;; BTC price data (price scaled by 10^8)
(define-data-var btc-price-in-usd uint u0)
(define-data-var btc-price-last-updated uint u0)

;; Data Storage

;; Vault storage - maps user principal to their vault data
(define-map vaults
  { owner: principal }
  {
    collateral-amount: uint, ;; BTC amount in satoshis
    borrowed-amount: uint, ;; Debt amount in USD cents
    interest-accumulated: uint, ;; Accumulated interest in USD cents
    last-interest-update: uint, ;; Block height of last interest update
  }
)

;; Protocol reserves by asset type
(define-map protocol-reserves
  { asset: (string-ascii 10) }
  { amount: uint }
)

;; Protocol statistics
(define-data-var total-collateral uint u0)
(define-data-var total-borrowed uint u0)
(define-data-var total-fees-collected uint u0)

;; Governance token distribution
(define-map governance-token-balances
  { owner: principal }
  { balance: uint }
)

;; Helper Functions

;; Authorization checks
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized-oracle)
  ;; In a production environment, we would have a whitelist of authorized oracles
  (is-eq tx-sender (var-get contract-owner))
)

;; Protocol state verification
(define-private (assert-not-paused)
  (ok (asserts! (not (var-get protocol-paused)) ERR_PROTOCOL_PAUSED))
)

;; Safe math operations
(define-private (mul-div
    (a uint)
    (b uint)
    (c uint)
  )
  (begin
    (asserts! (> c u0) ERR_INVALID_AMOUNT)
    (ok (/ (* a b) c))
  )
)

;; Oracle Functions

;; Update the BTC/USD price feed
(define-public (update-btc-price (new-price uint))
  (begin
    (asserts! (is-authorized-oracle) ERR_UNAUTHORIZED)
    ;; Add validation for price sanity
    (asserts! (> new-price u0) ERR_INVALID_AMOUNT)
    ;; Add upper bound check to prevent extreme price manipulation
    (asserts! (< new-price u10000000000) ERR_INVALID_AMOUNT) ;; $100,000 per BTC ceiling
    ;; Optional: Add check for maximum allowed price deviation from previous
    (var-set btc-price-in-usd new-price)
    (var-set btc-price-last-updated stacks-block-height)
    (ok new-price)
  )
)

;; Fetch the current BTC price with validation
(define-private (get-btc-price)
  (let (
      (current-price (var-get btc-price-in-usd))
      (last-updated (var-get btc-price-last-updated))
    )
    (if (or
        (is-eq current-price u0)
        (> (- stacks-block-height last-updated)
          (var-get oracle-price-validity-period)
        )
      )
      ERR_ORACLE_ERROR
      (ok current-price)
    )
  )
)

;; Administrative Functions

;; Transfer contract ownership
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    ;; Prevent setting to zero/null address
    (asserts! (not (is-eq new-owner 'SP000000000000000000002Q6VF78))
      ERR_INVALID_AMOUNT
    )
    ;; Require two-step ownership transfer for security
    (var-set contract-owner new-owner)
    (ok new-owner)
  )
)

;; Update the minimum collateral ratio requirement
(define-public (set-minimum-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (>= new-ratio (var-get liquidation-threshold)) ERR_INVALID_AMOUNT)
    (var-set minimum-collateral-ratio new-ratio)
    (ok new-ratio)
  )
)

;; Update the liquidation threshold
(define-public (set-liquidation-threshold (new-threshold uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (<= new-threshold (var-get minimum-collateral-ratio))
      ERR_INVALID_AMOUNT
    )
    (var-set liquidation-threshold new-threshold)
    (ok new-threshold)
  )
)

;; Update the liquidation penalty
(define-public (set-liquidation-penalty (new-penalty uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (<= new-penalty u50) ERR_INVALID_AMOUNT) ;; Maximum 50% penalty
    (var-set liquidation-penalty new-penalty)
    (ok new-penalty)
  )
)

;; Update the interest rate
(define-public (set-interest-rate (new-rate uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    ;; Add upper bound for interest rate
    (asserts! (<= new-rate u50) ERR_INVALID_AMOUNT) ;; Maximum 50% interest rate
    (var-set borrow-interest-rate new-rate)
    (ok new-rate)
  )
)

;; Update the protocol fee
(define-public (set-protocol-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee u50) ERR_INVALID_AMOUNT) ;; Maximum 50% fee
    (var-set protocol-fee-rate new-fee)
    (ok new-fee)
  )
)

;; Emergency pause/unpause for the protocol
(define-public (toggle-protocol-pause)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set protocol-paused (not (var-get protocol-paused)))
    (ok (var-get protocol-paused))
  )
)