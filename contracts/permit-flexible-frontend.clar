;; permit-flexible-frontend
;; 
;; A flexible permit management smart contract for enabling dynamic frontend interactions
;; with secure, configurable access control and permission management.

;; Error Constants
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-INVALID-PERMIT (err u1002))
(define-constant ERR-PERMIT-EXPIRED (err u1003))
(define-constant ERR-INVALID-CONFIGURATION (err u1004))
(define-constant ERR-PERMIT-NOT-FOUND (err u1005))
(define-constant ERR-DUPLICATE-PERMIT (err u1006))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u1007))

;; Permit Data Map
(define-map flexible-permits
  { permit-id: uint, issuer: principal }
  {
    grantee: principal,
    permissions: (list 10 (string-utf8 50)),
    valid-from: uint,
    valid-until: uint,
    is-revocable: bool
  }
)

;; Permit Tracking Map
(define-map permit-tracker
  { grantee: principal }
  {
    active-permits: (list 10 uint),
    total-permits-issued: uint
  }
)

;; Private Functions

;; Validate permit configuration
(define-private (validate-permit-config 
  (permissions (list 10 (string-utf8 50)))
  (valid-from uint)
  (valid-until uint)
)
  (begin
    (asserts! (> (len permissions) u0) (err ERR-INVALID-CONFIGURATION))
    (asserts! (<= valid-from valid-until) (err ERR-INVALID-CONFIGURATION))
    (ok true)
  )
)

;; Check if a permit is currently valid
(define-private (is-permit-valid 
  (permit-info { permit-id: uint, issuer: principal })
)
  (let (
    (current-time (unwrap-panic (get-block-info? time u0)))
    (permit (map-get? flexible-permits { permit-id: (get permit-id permit-info), issuer: (get issuer permit-info) }))
  )
    (match permit
      permit-data 
        (and 
          (>= current-time (get valid-from permit-data))
          (<= current-time (get valid-until permit-data))
        )
      false
    )
  )
)

;; Public Functions

;; Create a new flexible permit
(define-public (create-flexible-permit
  (grantee principal)
  (permissions (list 10 (string-utf8 50)))
  (valid-from uint)
  (valid-until uint)
  (is-revocable bool)
)
  (let (
    (permit-id (+ (default-to u0 (get total-permits-issued (map-get? permit-tracker { grantee: grantee }))) u1))
    (issuer tx-sender)
  )
    (try! (validate-permit-config permissions valid-from valid-until))
    
    (map-set flexible-permits 
      { permit-id: permit-id, issuer: issuer }
      {
        grantee: grantee,
        permissions: permissions,
        valid-from: valid-from,
        valid-until: valid-until,
        is-revocable: is-revocable
      }
    )
    
    (map-set permit-tracker 
      { grantee: grantee }
      {
        active-permits: (unwrap-panic (as-max-len? 
          (append 
            (default-to (list) (get active-permits (map-get? permit-tracker { grantee: grantee }))) 
            permit-id
          ) 
          (list 10 uint)
        )),
        total-permits-issued: permit-id
      }
    )
    
    (ok permit-id)
  )
)

;; Revoke a specific permit
(define-public (revoke-permit
  (permit-id uint)
)
  (let (
    (permit (map-get? flexible-permits { permit-id: permit-id, issuer: tx-sender }))
  )
    (match permit
      permit-data
        (if (get is-revocable permit-data)
          (begin
            (map-delete flexible-permits { permit-id: permit-id, issuer: tx-sender })
            (ok true)
          )
          (err ERR-INSUFFICIENT-PERMISSIONS)
        )
      (err ERR-PERMIT-NOT-FOUND)
    )
  )
)

;; Check if a specific permission is granted
(define-public (has-permission 
  (grantee principal)
  (required-permission (string-utf8 50))
)
  (let (
    (permits (map-get? permit-tracker { grantee: grantee }))
  )
    (match permits
      tracker-data
        (let (
          (active-permit-ids (get active-permits tracker-data))
          (permit-status (fold 
            check-permission-in-list 
            (map (lambda (pid) { permit-id: pid, issuer: tx-sender }) active-permit-ids)
            (none)
          ))
        )
          (ok (is-some permit-status))
        )
      (ok false)
    )
  )
)

;; Helper function to check permissions within a list
(define-private (check-permission-in-list 
  (permit-info { permit-id: uint, issuer: principal })
  (result (optional bool))
)
  (if (is-some result)
    result
    (if (is-permit-valid permit-info)
      (let (
        (permit (map-get? flexible-permits { 
          permit-id: (get permit-id permit-info), 
          issuer: (get issuer permit-info) 
        }))
      )
        (match permit
          permit-data
            (if (is-some (index-of (get permissions permit-data) required-permission))
              (some true)
              result
            )
          result
        )
      )
      result
    )
  )
)