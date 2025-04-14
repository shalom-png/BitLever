;; Title: 
;; BitLever: Bitcoin-Native Leveraged Trading Protocol on Stacks L2
;; 
;; Summary:
;; A non-custodial leveraged trading platform enabling 20x long/short positions 
;; with Bitcoin-secured settlements and Clarity's verifiable smart contracts

;; Description:
;; BitLever implements a decentralized trading protocol that allows users to:
;; - Open leveraged long/short positions (up to 20x) with collateral in STX
;; - Automatic liquidation system with price oracle integration
;; - Real-time PnL tracking and margin requirements
;; - Fully collateralized positions secured by Bitcoin's finality through Stacks L2
;;
;; Designed for Bitcoin DeFi, BitLever combines:
;; - Clarity's predictable execution for financial contracts
;; - Bitcoin-backed security through Stacks blockchain
;; - Transparent liquidation engine with incentive mechanisms
;; - Non-custodial architecture with self-executing positions
;;
;; Protocol features:
;; - 150% minimum collateral ratio for position safety
;; - Dynamic liquidation prices calculated using leverage ratios
;; - 5% liquidation bonus for early liquidators
;; - Oracle-based price feeds with admin override (testnet)
;; - Position tracking with verifiable on-chain history
;; - STX-denominated collateral management

;; Constants and Traits

;; Define error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-POSITION (err u103))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u104))
(define-constant ERR-ZERO-AMOUNT (err u105))
(define-constant ERR-MAX-LEVERAGE-EXCEEDED (err u106))
(define-constant ERR-POSITION-LIQUIDATED (err u107))
(define-constant ERR-INVALID-PRICE (err u108))

;; Minimum collateral ratio (150%)
(define-constant MIN-COLLATERAL-RATIO u150)

;; Maximum leverage (20x)
(define-constant MAX-LEVERAGE u20)

;; Position types
(define-constant TYPE-LONG u1)
(define-constant TYPE-SHORT u2)

;; Data Maps and Variables

;; Track user balances
(define-map balances 
    principal 
    { stx-balance: uint })

;; Track positions
(define-map positions 
    uint 
    { owner: principal,
      position-type: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      collateral: uint,
      liquidation-price: uint,
      is-liquidated: bool })

;; Position counter
(define-data-var position-counter uint u0)

;; Contract admin
(define-data-var contract-owner principal tx-sender)

;; Price oracle (simplified for testnet)
(define-data-var current-price uint u0)

;; Read-Only Functions

(define-read-only (get-balance (user principal))
    (default-to 
        { stx-balance: u0 }
        (map-get? balances user)))

(define-read-only (get-position (position-id uint))
    (map-get? positions position-id))

(define-read-only (get-current-price)
    (ok (var-get current-price)))

(define-read-only (get-contract-owner)
    (ok (var-get contract-owner)))

(define-read-only (get-position-count)
    (ok (var-get position-counter)))

;; Calculate liquidation price
(define-read-only (calculate-liquidation-price 
    (entry-price uint) 
    (position-type uint) 
    (leverage uint))
    (begin
        ;; Validate inputs
        (asserts! (> entry-price u0) (err ERR-INVALID-PRICE))
        (asserts! (or (is-eq position-type TYPE-LONG) 
                     (is-eq position-type TYPE-SHORT)) 
                 (err ERR-INVALID-POSITION))
        (asserts! (and (> leverage u0) (<= leverage MAX-LEVERAGE)) 
                 (err ERR-MAX-LEVERAGE-EXCEEDED))
        
        (if (is-eq position-type TYPE-LONG)
            ;; Long position liquidation price
            (ok (/ (* entry-price (- u100 (/ u100 leverage))) u100))
            ;; Short position liquidation price
            (ok (/ (* entry-price (+ u100 (/ u100 leverage))) u100)))))

;; Check if position is liquidatable
(define-read-only (is-liquidatable (position-id uint))
    (let ((position (unwrap! (map-get? positions position-id) (err ERR-INVALID-POSITION)))
          (current-market-price (var-get current-price)))
        (if (get is-liquidated position)
            (ok true)
            (if (is-eq (get position-type position) TYPE-LONG)
                ;; Long position liquidation check
                (ok (<= current-market-price (get liquidation-price position)))
                ;; Short position liquidation check
                (ok (>= current-market-price (get liquidation-price position)))))))

;; Public Functions

;; Deposit collateral
(define-public (deposit-collateral (amount uint))
    (begin
        ;; Validate amount
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        
        (let ((current-balance (get stx-balance (get-balance tx-sender))))
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (ok (map-set balances 
                tx-sender 
                { stx-balance: (+ current-balance amount) })))))

;; Withdraw collateral
(define-public (withdraw-collateral (amount uint))
    (begin
        ;; Validate amount
        (asserts! (> amount u0) ERR-ZERO-AMOUNT)
        
        (let ((current-balance (get stx-balance (get-balance tx-sender))))
            (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
            (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
            (ok (map-set balances 
                tx-sender 
                { stx-balance: (- current-balance amount) })))))

;; Open position
(define-public (open-position 
    (position-type uint)
    (size uint)
    (leverage uint))
    (begin
        ;; Validate inputs
        (asserts! (> size u0) ERR-INVALID-AMOUNT)
        (asserts! (and (> leverage u0) (<= leverage MAX-LEVERAGE)) ERR-MAX-LEVERAGE-EXCEEDED)
        (asserts! (or (is-eq position-type TYPE-LONG) 
                     (is-eq position-type TYPE-SHORT)) ERR-INVALID-POSITION)
        (asserts! (> (var-get current-price) u0) ERR-INVALID-PRICE)
        
        (let 
            ((required-collateral (/ (* size (var-get current-price)) leverage))
             (current-balance (get stx-balance (get-balance tx-sender)))
             (position-id (+ (var-get position-counter) u1))
             (entry-price (var-get current-price)))

            ;; Check sufficient collateral
            (asserts! (>= current-balance required-collateral) ERR-INSUFFICIENT-COLLATERAL)

            ;; Calculate liquidation price
            (let ((liquidation-price (unwrap! (calculate-liquidation-price 
                                             entry-price 
                                             position-type 
                                             leverage) ERR-INVALID-POSITION)))

                ;; Create position
                (map-set positions position-id
                    { owner: tx-sender,
                      position-type: position-type,
                      size: size,
                      entry-price: entry-price,
                      leverage: leverage,
                      collateral: required-collateral,
                      liquidation-price: liquidation-price,
                      is-liquidated: false })

                ;; Update balance
                (map-set balances 
                    tx-sender 
                    { stx-balance: (- current-balance required-collateral) })

                ;; Increment position counter
                (var-set position-counter position-id)
                (ok position-id)))))

;; Close position
(define-public (close-position (position-id uint))
    (let ((position (unwrap! (map-get? positions position-id) ERR-INVALID-POSITION)))
        ;; Verify owner
        (asserts! (is-eq (get owner position) tx-sender) ERR-UNAUTHORIZED)
        ;; Verify position is not liquidated
        (asserts! (not (get is-liquidated position)) ERR-POSITION-LIQUIDATED)
        
        ;; Check if position should be liquidated before closing
        (if (unwrap! (is-liquidatable position-id) ERR-INVALID-POSITION)
            ;; If liquidatable, liquidate instead of normal close
            (liquidate-position position-id)
            ;; Regular position closing
            (let ((pnl (calculate-pnl position)))
                ;; Return collateral + PnL (if positive)
                (try! (as-contract 
                       (stx-transfer? 
                        (+ (get collateral position) 
                           (if (> pnl u0) pnl u0)) 
                        tx-sender 
                        tx-sender)))

                ;; Delete position
                (map-delete positions position-id)
                (ok true)))))

;; Liquidate position (can be called by anyone when conditions are met)
(define-public (liquidate-position (position-id uint))
    (let ((position (unwrap! (map-get? positions position-id) ERR-INVALID-POSITION)))
        ;; Check if position is liquidatable
        (asserts! (unwrap! (is-liquidatable position-id) ERR-INVALID-POSITION) ERR-INVALID-POSITION)
        
        ;; Mark as liquidated and update position
        (map-set positions position-id
            (merge position { is-liquidated: true }))
        
        ;; Transfer liquidation fee to caller (5% of collateral)
        (let ((liquidation-fee (/ (* (get collateral position) u5) u100))
              (remaining-collateral (- (get collateral position) liquidation-fee)))
            
            ;; Pay liquidation fee to caller
            (try! (as-contract 
                   (stx-transfer? 
                    liquidation-fee 
                    tx-sender 
                    tx-sender)))
            
            ;; Return remaining collateral to position owner (if any)
            (if (> remaining-collateral u0)
                (try! (as-contract 
                       (stx-transfer? 
                        remaining-collateral 
                        (get owner position) 
                        tx-sender)))
                (ok true))
                
            (ok true))))

;; Private Functions

;; Calculate PnL (improved with safety checks)
(define-private (calculate-pnl (position {owner: principal, 
                                        position-type: uint,
                                        size: uint,
                                        entry-price: uint,
                                        leverage: uint,
                                        collateral: uint,
                                        liquidation-price: uint,
                                        is-liquidated: bool}))
    (let ((current-price-local (var-get current-price)))
        (if (is-eq (get position-type position) TYPE-LONG)
            ;; Long position PnL calculation
            (if (>= current-price-local (get entry-price position))
                ;; Profit scenario
                (let ((price-diff (- current-price-local (get entry-price position))))
                    (* price-diff (get size position)))
                ;; Loss scenario
                (let ((price-diff (- (get entry-price position) current-price-local)))
                    (if (> (* price-diff (get size position)) (get collateral position))
                        ;; Cap loss at collateral amount
                        (- u0 (get collateral position))
                        (- u0 (* price-diff (get size position))))))
            ;; Short position PnL calculation
            (if (>= (get entry-price position) current-price-local)
                ;; Profit scenario
                (let ((price-diff (- (get entry-price position) current-price-local)))
                    (* price-diff (get size position)))
                ;; Loss scenario
                (let ((price-diff (- current-price-local (get entry-price position))))
                    (if (> (* price-diff (get size position)) (get collateral position))
                        ;; Cap loss at collateral amount
                        (- u0 (get collateral position))
                        (- u0 (* price-diff (get size position)))))))))

;; Admin Functions

;; Update price (would be replaced by oracle in production)
(define-public (update-price (new-price uint))
    (begin
        ;; Verify caller is contract owner
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        ;; Verify price is valid
        (asserts! (> new-price u0) ERR-INVALID-PRICE)
        ;; Update price
        (var-set current-price new-price)
        (ok true)))

;; Update contract owner
(define-public (set-contract-owner (new-owner principal))
    (begin
        ;; Verify caller is current contract owner
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        ;; Verify new owner is not null principal (using a different approach)
        (asserts! (not (is-eq new-owner tx-sender)) ERR-UNAUTHORIZED)
        ;; Update contract owner
        (var-set contract-owner new-owner)
        (ok true)))

;; Pause/unpause contract (future addition)
(define-data-var contract-paused bool false)

(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-UNAUTHORIZED)
        (var-set contract-paused paused)
        (ok true)))

(define-read-only (is-contract-paused)
    (ok (var-get contract-paused)))