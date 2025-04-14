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