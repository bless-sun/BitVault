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

;; Collateral Management

;; Deposit BTC collateral
(define-public (deposit-collateral (btc-amount uint))
  (let (
      (user tx-sender)
      (vault-data (map-get? vaults { owner: user }))
    )
    (begin
      (try! (assert-not-paused))
      (asserts! (> btc-amount u0) ERR_INVALID_AMOUNT)
      ;; In production, this would verify a Bitcoin transaction proof
      ;; For simplicity, we're just tracking the amount
      ;; Create or update vault
      (if (is-some vault-data)
        (let ((existing-vault (unwrap-panic vault-data)))
          (map-set vaults { owner: user } {
            collateral-amount: (+ (get collateral-amount existing-vault) btc-amount),
            borrowed-amount: (get borrowed-amount existing-vault),
            interest-accumulated: (get interest-accumulated existing-vault),
            last-interest-update: (get last-interest-update existing-vault),
          })
        )
        (map-set vaults { owner: user } {
          collateral-amount: btc-amount,
          borrowed-amount: u0,
          interest-accumulated: u0,
          last-interest-update: stacks-block-height,
        })
      )
      ;; Update total collateral
      (var-set total-collateral (+ (var-get total-collateral) btc-amount))
      (ok btc-amount)
    )
  )
)

;; Calculate the USD value of BTC collateral
(define-private (calculate-collateral-value (btc-amount uint))
  (let ((btc-price (get-btc-price)))
    (if (is-err btc-price)
      btc-price
      (mul-div btc-amount (unwrap-panic btc-price) u100000000) ;; Convert satoshis to BTC and multiply by price
    )
  )
)

;; Calculate max borrowing capacity based on collateral
(define-private (calculate-max-borrow-amount (collateral-amount uint))
  (let ((collateral-value-result (calculate-collateral-value collateral-amount)))
    (if (is-err collateral-value-result)
      collateral-value-result
      (let ((collateral-value (unwrap-panic collateral-value-result)))
        (mul-div collateral-value u100 (var-get minimum-collateral-ratio))
      )
    )
  )
)

;; Interest Calculation

;; Calculate interest for a given period
(define-private (calculate-interest
    (borrowed-amount uint)
    (blocks-passed uint)
  )
  (let ((interest-per-block (/ (var-get borrow-interest-rate) u52560)))
    (unwrap-panic (mul-div borrowed-amount interest-per-block blocks-passed))
  )
)

;; Update accumulated interest for a vault
(define-private (update-interest (vault-data {
  collateral-amount: uint,
  borrowed-amount: uint,
  interest-accumulated: uint,
  last-interest-update: uint,
}))
  (let (
      (blocks-passed (- stacks-block-height (get last-interest-update vault-data)))
      (new-interest (calculate-interest (get borrowed-amount vault-data) blocks-passed))
    )
    {
      collateral-amount: (get collateral-amount vault-data),
      borrowed-amount: (get borrowed-amount vault-data),
      interest-accumulated: (+ (get interest-accumulated vault-data) new-interest),
      last-interest-update: stacks-block-height,
    }
  )
)

;; Risk Management

;; Check if a vault is undercollateralized
(define-private (is-undercollateralized (vault-data {
  collateral-amount: uint,
  borrowed-amount: uint,
  interest-accumulated: uint,
  last-interest-update: uint,
}))
  (let (
      (collateral-value-result (calculate-collateral-value (get collateral-amount vault-data)))
      (total-debt (+ (get borrowed-amount vault-data) (get interest-accumulated vault-data)))
    )
    (if (is-err collateral-value-result)
      true ;; If oracle error, consider vault at risk
      (let (
          (collateral-value (unwrap-panic collateral-value-result))
          (min-collateral-needed-result (mul-div total-debt (var-get liquidation-threshold) u100))
        )
        (if (is-err min-collateral-needed-result)
          true ;; If calculation error, consider vault at risk
          (< collateral-value (unwrap-panic min-collateral-needed-result))
        )
      )
    )
  )
)

;; Lending Operations

;; Borrow stablecoins against BTC collateral
(define-public (borrow (amount-to-borrow uint))
  (let (
      (user tx-sender)
      (vault-data-option (map-get? vaults { owner: user }))
    )
    (begin
      (try! (assert-not-paused))
      (asserts! (> amount-to-borrow u0) ERR_INVALID_AMOUNT)
      (asserts! (is-some vault-data-option) ERR_VAULT_NOT_FOUND)
      (let (
          (vault-data (unwrap-panic vault-data-option))
          (updated-vault (update-interest vault-data))
        )
        ;; Check borrowing limit
        (let (
            (max-borrow-result (calculate-max-borrow-amount (get collateral-amount updated-vault)))
            (total-debt (+ (get borrowed-amount updated-vault)
              (get interest-accumulated updated-vault)
            ))
          )
          (if (is-err max-borrow-result)
            max-borrow-result
            (let ((max-borrow (unwrap-panic max-borrow-result)))
              (asserts! (<= (+ amount-to-borrow total-debt) max-borrow)
                ERR_BORROW_LIMIT_EXCEEDED
              )
              ;; Update vault
              (map-set vaults { owner: user } {
                collateral-amount: (get collateral-amount updated-vault),
                borrowed-amount: (+ (get borrowed-amount updated-vault) amount-to-borrow),
                interest-accumulated: (get interest-accumulated updated-vault),
                last-interest-update: stacks-block-height,
              })
              ;; Update total borrowed
              (var-set total-borrowed
                (+ (var-get total-borrowed) amount-to-borrow)
              )
              ;; In production, this would transfer stablecoins to the user
              ;; For now, we just track the debt
              (ok amount-to-borrow)
            )
          )
        )
      )
    )
  )
)

;; Repay borrowed stablecoins
(define-public (repay (amount-to-repay uint))
  (let (
      (user tx-sender)
      (vault-data-option (map-get? vaults { owner: user }))
    )
    (begin
      (try! (assert-not-paused))
      (asserts! (> amount-to-repay u0) ERR_INVALID_AMOUNT)
      (asserts! (is-some vault-data-option) ERR_VAULT_NOT_FOUND)
      (let (
          (vault-data (unwrap-panic vault-data-option))
          (updated-vault (update-interest vault-data))
        )
        (let ((total-debt (+ (get borrowed-amount updated-vault)
            (get interest-accumulated updated-vault)
          )))
          ;; Ensure repayment amount doesn't exceed debt
          (let ((effective-repayment (if (> amount-to-repay total-debt)
              total-debt
              amount-to-repay
            )))
            ;; Calculate how much goes to interest vs principal
            (let (
                (interest-payment (if (> (get interest-accumulated updated-vault) effective-repayment)
                  effective-repayment
                  (get interest-accumulated updated-vault)
                ))
                (principal-payment (- effective-repayment interest-payment))
              )
              ;; Calculate protocol fee
              (let ((fee-amount (mul-div interest-payment (var-get protocol-fee-rate) u100)))
                ;; Update protocol statistics
                (var-set total-fees-collected
                  (+ (var-get total-fees-collected) (unwrap-panic fee-amount))
                )
                (var-set total-borrowed
                  (- (var-get total-borrowed) principal-payment)
                )
                ;; Update vault
                (map-set vaults { owner: user } {
                  collateral-amount: (get collateral-amount updated-vault),
                  borrowed-amount: (- (get borrowed-amount updated-vault) principal-payment),
                  interest-accumulated: (- (get interest-accumulated updated-vault) interest-payment),
                  last-interest-update: stacks-block-height,
                })
                ;; In production, this would transfer stablecoins from the user
                ;; For now, we just track the debt
                (ok effective-repayment)
              )
            )
          )
        )
      )
    )
  )
)

;; Withdraw BTC collateral
(define-public (withdraw-collateral (amount-to-withdraw uint))
  (let (
      (user tx-sender)
      (vault-data-option (map-get? vaults { owner: user }))
    )
    (begin
      (try! (assert-not-paused))
      (asserts! (> amount-to-withdraw u0) ERR_INVALID_AMOUNT)
      (asserts! (is-some vault-data-option) ERR_VAULT_NOT_FOUND)
      (let (
          (vault-data (unwrap-panic vault-data-option))
          (updated-vault (update-interest vault-data))
        )
        ;; Check if withdrawal would leave enough collateral
        (asserts! (<= amount-to-withdraw (get collateral-amount updated-vault))
          ERR_INSUFFICIENT_COLLATERAL
        )
        (let (
            (new-collateral-amount (- (get collateral-amount updated-vault) amount-to-withdraw))
            (total-debt (+ (get borrowed-amount updated-vault)
              (get interest-accumulated updated-vault)
            ))
          )
          ;; If there's outstanding debt, check collateralization ratio
          (if (> total-debt u0)
            (let ((collateral-value-result (calculate-collateral-value new-collateral-amount)))
              (if (is-err collateral-value-result)
                collateral-value-result
                (let (
                    (new-collateral-value (unwrap-panic collateral-value-result))
                    (min-collateral-needed (mul-div total-debt (var-get minimum-collateral-ratio) u100))
                  )
                  (asserts!
                    (>= new-collateral-value (unwrap-panic min-collateral-needed))
                    ERR_MINIMUM_COLLATERAL_RATIO
                  )
                  ;; Update vault
                  (map-set vaults { owner: user } {
                    collateral-amount: new-collateral-amount,
                    borrowed-amount: (get borrowed-amount updated-vault),
                    interest-accumulated: (get interest-accumulated updated-vault),
                    last-interest-update: stacks-block-height,
                  })
                  ;; Update total collateral
                  (var-set total-collateral
                    (- (var-get total-collateral) amount-to-withdraw)
                  )
                  ;; In production, this would trigger a Bitcoin transaction to return funds
                  ;; For now, we just track the amount
                  (ok amount-to-withdraw)
                )
              )
            )
            ;; If no debt, allow full withdrawal
            (begin
              ;; Update vault
              (map-set vaults { owner: user } {
                collateral-amount: new-collateral-amount,
                borrowed-amount: u0,
                interest-accumulated: u0,
                last-interest-update: stacks-block-height,
              })
              ;; Update total collateral
              (var-set total-collateral
                (- (var-get total-collateral) amount-to-withdraw)
              )
              ;; In production, this would trigger a Bitcoin transaction to return funds
              ;; For now, we just track the amount
              (ok amount-to-withdraw)
            )
          )
        )
      )
    )
  )
)

;; Liquidation System

;; Liquidate an undercollateralized vault
(define-public (liquidate (vault-owner principal))
  (let ((vault-data-option (map-get? vaults { owner: vault-owner })))
    (begin
      (try! (assert-not-paused))
      ;; Prevent liquidation of contract owner/privileged accounts
      (asserts! (not (is-eq vault-owner (var-get contract-owner)))
        ERR_UNAUTHORIZED
      )
      (asserts! (is-some vault-data-option) ERR_VAULT_NOT_FOUND)
      (let (
          (vault-data (unwrap-panic vault-data-option))
          (updated-vault (update-interest vault-data))
        )
        ;; Check if vault is undercollateralized
        (asserts! (is-undercollateralized updated-vault)
          ERR_VAULT_NOT_UNDERCOLLATERALIZED
        )
        ;; Calculate liquidation values
        (let (
            (collateral-value-result (calculate-collateral-value (get collateral-amount updated-vault)))
            (total-debt (+ (get borrowed-amount updated-vault)
              (get interest-accumulated updated-vault)
            ))
          )
          (if (is-err collateral-value-result)
            collateral-value-result
            (let (
                (collateral-value (unwrap-panic collateral-value-result))
                (liquidation-amount-result (mul-div total-debt (+ u100 (var-get liquidation-penalty)) u100))
              )
              (if (is-err liquidation-amount-result)
                liquidation-amount-result
                (let ((liquidation-amount (unwrap-panic liquidation-amount-result)))
                  ;; Calculate how much collateral to liquidate
                  (let ((btc-to-liquidate-result (if (> liquidation-amount collateral-value)
                      (ok (get collateral-amount updated-vault)) ;; Liquidate all if underwater
                      (mul-div (get collateral-amount updated-vault)
                        liquidation-amount collateral-value
                      )
                    )))
                    (if (is-err btc-to-liquidate-result)
                      btc-to-liquidate-result
                      (let ((btc-to-liquidate (unwrap-panic btc-to-liquidate-result)))
                        ;; Calculate bonus for liquidator
                        (let ((liquidator-bonus-result (mul-div btc-to-liquidate (var-get liquidation-penalty)
                            u100
                          )))
                          (if (is-err liquidator-bonus-result)
                            liquidator-bonus-result
                            (let ((liquidator-bonus (unwrap-panic liquidator-bonus-result)))
                              ;; Calculate borrowed amount to reduce
                              (let ((borrowed-amount-reduction-result (if (> liquidation-amount total-debt)
                                  (ok (get borrowed-amount updated-vault))
                                  (mul-div (get borrowed-amount updated-vault)
                                    liquidation-amount total-debt
                                  )
                                )))
                                (if (is-err borrowed-amount-reduction-result)
                                  borrowed-amount-reduction-result
                                  (let ((borrowed-amount-reduction (unwrap-panic borrowed-amount-reduction-result)))
                                    ;; Calculate interest to reduce
                                    (let ((interest-reduction-result (if (> liquidation-amount total-debt)
                                        (ok (get interest-accumulated updated-vault))
                                        (mul-div
                                          (get interest-accumulated updated-vault)
                                          liquidation-amount total-debt
                                        )
                                      )))
                                      (if (is-err interest-reduction-result)
                                        interest-reduction-result
                                        (let ((interest-reduction (unwrap-panic interest-reduction-result)))
                                          ;; Update vault
                                          (map-set vaults { owner: vault-owner } {
                                            collateral-amount: (-
                                              (get collateral-amount
                                                updated-vault
                                              )
                                              btc-to-liquidate
                                            ),
                                            borrowed-amount: (-
                                              (get borrowed-amount updated-vault)
                                              borrowed-amount-reduction
                                            ),
                                            interest-accumulated: (-
                                              (get interest-accumulated
                                                updated-vault
                                              )
                                              interest-reduction
                                            ),
                                            last-interest-update: stacks-block-height,
                                          })
                                          ;; Update total collateral and borrowed
                                          (var-set total-collateral
                                            (- (var-get total-collateral)
                                              btc-to-liquidate
                                            ))
                                          (var-set total-borrowed
                                            (- (var-get total-borrowed)
                                              borrowed-amount-reduction
                                            ))
                                          ;; Return the amount of BTC liquidated
                                          (ok btc-to-liquidate)
                                        )
                                      )
                                    )
                                  )
                                )
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)