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