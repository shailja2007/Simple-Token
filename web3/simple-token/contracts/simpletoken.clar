;; GenomicData Marketplace Contract
;; A secure genetic data sharing platform with privacy protection and researcher access
;; Enables controlled sharing of genomic data while maintaining privacy and compensation

;; Define the platform token for payments
(define-fungible-token genomic-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-funds (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-data-not-found (err u104))
(define-constant err-already-purchased (err u105))

;; Data structures
(define-map genetic-datasets
  { dataset-id: uint }
  {
    owner: principal,
    price: uint,
    data-hash: (buff 32),
    privacy-level: uint,
    research-category: (string-ascii 50),
    is-available: bool
  }
)

(define-map researcher-access
  { researcher: principal, dataset-id: uint }
  {
    access-granted: bool,
    purchase-date: uint,
    usage-terms: (string-ascii 100)
  }
)

;; State variables
(define-data-var next-dataset-id uint u1)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee

;; Function 1: Submit Genetic Dataset
;; Allows data owners to securely list their genetic data for research access
(define-public (submit-genetic-dataset 
    (price uint) 
    (data-hash (buff 32)) 
    (privacy-level uint) 
    (research-category (string-ascii 50)))
  (let 
    (
      (dataset-id (var-get next-dataset-id))
    )
    (begin
      ;; Validate inputs
      (asserts! (> price u0) err-invalid-amount)
      (asserts! (<= privacy-level u3) err-invalid-amount) ;; Privacy levels: 1-3
      
      ;; Store dataset information
      (map-set genetic-datasets
        { dataset-id: dataset-id }
        {
          owner: tx-sender,
          price: price,
          data-hash: data-hash,
          privacy-level: privacy-level,
          research-category: research-category,
          is-available: true
        }
      )
      
      ;; Increment dataset ID counter
      (var-set next-dataset-id (+ dataset-id u1))
      
      ;; Print event for indexing
      (print {
        event: "dataset-submitted",
        dataset-id: dataset-id,
        owner: tx-sender,
        price: price,
        category: research-category
      })
      
      (ok dataset-id)
    )
  )
)

;; Function 2: Purchase Research Access
;; Enables researchers to securely purchase access to genetic datasets
(define-public (purchase-research-access 
    (dataset-id uint) 
    (usage-terms (string-ascii 100)))
  (let
    (
      (dataset-info (unwrap! (map-get? genetic-datasets { dataset-id: dataset-id }) err-data-not-found))
      (dataset-price (get price dataset-info))
      (dataset-owner (get owner dataset-info))
      (platform-fee (/ (* dataset-price (var-get platform-fee-percentage)) u100))
      (owner-payment (- dataset-price platform-fee))
    )
    (begin
      ;; Validate dataset availability
      (asserts! (get is-available dataset-info) err-data-not-found)
      
      ;; Check if researcher already has access
      (asserts! 
        (is-none (map-get? researcher-access { researcher: tx-sender, dataset-id: dataset-id }))
        err-already-purchased
      )
      
      ;; Transfer payment to dataset owner
      (try! (stx-transfer? owner-payment tx-sender dataset-owner))
      
      ;; Transfer platform fee to contract owner
      (try! (stx-transfer? platform-fee tx-sender contract-owner))
      
      ;; Grant access to researcher
      (map-set researcher-access
        { researcher: tx-sender, dataset-id: dataset-id }
        {
          access-granted: true,
          purchase-date: stacks-block-height,
          usage-terms: usage-terms
        }
      )
      
      ;; Print event for indexing
      (print {
        event: "research-access-purchased",
        researcher: tx-sender,
        dataset-id: dataset-id,
        price: dataset-price,
        purchase-date: stacks-block-height,
             })
      
      (ok true)
    )
  )
)

;; Read-only functions for data retrieval
(define-read-only (get-dataset-info (dataset-id uint))
  (map-get? genetic-datasets { dataset-id: dataset-id }))

(define-read-only (get-researcher-access (researcher principal) (dataset-id uint))
  (map-get? researcher-access { researcher: researcher, dataset-id: dataset-id }))

(define-read-only (get-next-dataset-id)
  (ok (var-get next-dataset-id)))

(define-read-only (get-platform-fee-percentage)
  (ok (var-get platform-fee-percentage))) 