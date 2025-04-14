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